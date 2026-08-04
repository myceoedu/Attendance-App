-- ============================================================
-- BUNDLE 9 — Workplace geofence (one site, clock-in only)
-- Run after 01–07 on new projects.
-- Same content as: supabase_migration_work_site_geofence.sql
-- ============================================================

-- Singleton work site (id must always be 1)
CREATE TABLE IF NOT EXISTS public.work_site (
  id              smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  name            text NOT NULL DEFAULT 'Workplace',
  latitude        double precision NOT NULL,
  longitude       double precision NOT NULL,
  radius_meters   integer NOT NULL DEFAULT 100
                    CHECK (radius_meters >= 20 AND radius_meters <= 5000),
  is_active       boolean NOT NULL DEFAULT false,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid REFERENCES public.users(id) ON DELETE SET NULL
);

ALTER TABLE public.work_site ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read work_site" ON public.work_site;
CREATE POLICY "Authenticated read work_site"
  ON public.work_site FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins insert work_site" ON public.work_site;
CREATE POLICY "Admins insert work_site"
  ON public.work_site FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS "Admins update work_site" ON public.work_site;
CREATE POLICY "Admins update work_site"
  ON public.work_site FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS "Admins delete work_site" ON public.work_site;
CREATE POLICY "Admins delete work_site"
  ON public.work_site FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

CREATE OR REPLACE FUNCTION public.distance_meters(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT CASE
    WHEN lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN NULL
    ELSE 6371000.0 * 2.0 * asin(
      sqrt(
        power(sin(radians(lat2 - lat1) / 2.0), 2) +
        cos(radians(lat1)) * cos(radians(lat2)) *
        power(sin(radians(lon2 - lon1) / 2.0), 2)
      )
    )
  END;
$$;

REVOKE ALL ON FUNCTION public.distance_meters(
  double precision, double precision, double precision, double precision
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.distance_meters(
  double precision, double precision, double precision, double precision
) TO authenticated;

CREATE OR REPLACE FUNCTION public.clock_in_if_allowed(
  p_user_id UUID,
  p_location TEXT DEFAULT NULL
)
RETURNS public.attendance
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_today DATE := timezone('Asia/Kuala_Lumpur', now())::date;
  v_record public.attendance%ROWTYPE;
  v_site public.work_site%ROWTYPE;
  v_lat double precision;
  v_lng double precision;
  v_parts text[];
  v_dist double precision;
BEGIN
  IF v_actor_id IS DISTINCT FROM p_user_id
     AND NOT EXISTS (
       SELECT 1 FROM public.users u
       WHERE u.id = v_actor_id AND u.role = 'admin'
     ) THEN
    RAISE EXCEPTION 'Not allowed to clock in for this user';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.leave_requests lr
    WHERE lr.user_id = p_user_id
      AND lr.status = 'approved'
      AND lr.start_date <= v_today
      AND lr.end_date >= v_today
  ) THEN
    RAISE EXCEPTION 'Approved leave already covers today';
  END IF;

  SELECT * INTO v_site
  FROM public.work_site
  WHERE id = 1 AND is_active = true;

  IF FOUND THEN
    IF p_location IS NULL OR length(trim(p_location)) = 0 THEN
      RAISE EXCEPTION 'Location required for workplace clock-in';
    END IF;

    v_parts := string_to_array(trim(p_location), ',');
    IF array_length(v_parts, 1) IS DISTINCT FROM 2 THEN
      RAISE EXCEPTION 'Invalid clock-in location format';
    END IF;

    BEGIN
      v_lat := trim(v_parts[1])::double precision;
      v_lng := trim(v_parts[2])::double precision;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Invalid clock-in location format';
    END;

    IF v_lat < -90 OR v_lat > 90 OR v_lng < -180 OR v_lng > 180 THEN
      RAISE EXCEPTION 'Invalid clock-in location format';
    END IF;

    v_dist := public.distance_meters(
      v_site.latitude, v_site.longitude, v_lat, v_lng
    );

    IF v_dist IS NULL OR v_dist > v_site.radius_meters THEN
      RAISE EXCEPTION
        'Outside workplace geofence (% m away, limit % m)',
        round(COALESCE(v_dist, 0))::integer,
        v_site.radius_meters;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.attendance a
    WHERE a.user_id = p_user_id
      AND a.date = v_today
  ) THEN
    RAISE EXCEPTION 'Attendance already exists for today';
  END IF;

  INSERT INTO public.attendance (
    user_id,
    clock_in_time,
    date,
    status,
    location
  )
  VALUES (
    p_user_id,
    now(),
    v_today,
    'in_progress',
    p_location
  )
  RETURNING * INTO v_record;

  RETURN v_record;
END;
$$;

REVOKE ALL ON FUNCTION public.clock_in_if_allowed(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.clock_in_if_allowed(UUID, TEXT) TO authenticated;
