-- ============================================================
-- MIGRATION: Expanded leave types + weighted annual (half-days)
-- Run after supabase_setup + supabase_migration_annual_leave.sql
-- ============================================================

ALTER TABLE public.leave_requests
  DROP CONSTRAINT IF EXISTS leave_requests_leave_type_check;

ALTER TABLE public.leave_requests
  ADD CONSTRAINT leave_requests_leave_type_check CHECK (
    leave_type IN (
      'annual',
      'annual_half_am',
      'annual_half_pm',
      'sick',
      'emergency',
      'unpaid',
      'maternity',
      'paternity',
      'marriage',
      'public_holiday'
    )
  );


-- Calendar-year annual “charge”: full [annual] uses inclusive calendar days in year;
-- half-day types use 0.5 when the single date falls in [p_year] (start must equal end — enforced by trigger).
CREATE OR REPLACE FUNCTION public.annual_leave_credit_in_year(
  p_leave_type TEXT,
  p_start DATE,
  p_end DATE,
  p_year INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  overlap_start DATE;
  overlap_end DATE;
BEGIN
  IF p_leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    IF p_start IS DISTINCT FROM p_end THEN
      RETURN 0::numeric;
    END IF;
    IF p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN
      RETURN 0::numeric;
    END IF;
    RETURN 0.5::numeric;
  END IF;

  IF p_leave_type IS DISTINCT FROM 'annual' THEN
    RETURN 0::numeric;
  END IF;

  IF p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN
    RETURN 0::numeric;
  END IF;

  overlap_start := GREATEST(p_start, make_date(p_year, 1, 1));
  overlap_end := LEAST(p_end, make_date(p_year, 12, 31));
  IF overlap_end < overlap_start THEN
    RETURN 0::numeric;
  END IF;

  RETURN (overlap_end - overlap_start + 1)::numeric;
END;
$$;


CREATE OR REPLACE FUNCTION public.annual_leave_days_for_requests(
  p_user_id UUID,
  p_year INTEGER,
  p_statuses TEXT[]
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    SUM(
      public.annual_leave_credit_in_year(
        lr.leave_type,
        lr.start_date,
        lr.end_date,
        p_year
      )
    ),
    0
  )::numeric
  FROM public.leave_requests lr
  WHERE lr.user_id = p_user_id
    AND lr.leave_type IN ('annual', 'annual_half_am', 'annual_half_pm')
    AND lr.status = ANY(p_statuses)
    AND lr.start_date <= make_date(p_year, 12, 31)
    AND lr.end_date >= make_date(p_year, 1, 1);
$$;


CREATE OR REPLACE FUNCTION public.assert_annual_leave_approval_allowed(p_leave_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  lr public.leave_requests%ROWTYPE;
  y_from INTEGER;
  y_to INTEGER;
  yy INTEGER;
  v_ent NUMERIC;
  v_used NUMERIC;
  v_other_pend NUMERIC;
  need NUMERIC;
BEGIN
  SELECT *
  INTO lr
  FROM public.leave_requests lr0
  WHERE lr0.id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF lr.leave_type NOT IN ('annual', 'annual_half_am', 'annual_half_pm') THEN
    RETURN;
  END IF;

  y_from := EXTRACT(YEAR FROM lr.start_date)::integer;
  y_to := EXTRACT(YEAR FROM lr.end_date)::integer;

  FOR yy IN y_from .. y_to LOOP
    need := public.annual_leave_credit_in_year(
      lr.leave_type,
      lr.start_date,
      lr.end_date,
      yy
    );

    IF need <= 0 THEN
      CONTINUE;
    END IF;

    v_ent := public.user_annual_entitlement_for_year(lr.user_id, yy);

    v_used := public.annual_leave_days_for_requests(
      lr.user_id, yy, ARRAY['approved']::TEXT[]
    );

    SELECT COALESCE(
      SUM(
        public.annual_leave_credit_in_year(
          r.leave_type,
          r.start_date,
          r.end_date,
          yy
        )
      ),
      0
    )
    INTO v_other_pend
    FROM public.leave_requests r
    WHERE r.user_id = lr.user_id
      AND r.leave_type IN ('annual', 'annual_half_am', 'annual_half_pm')
      AND r.status = 'pending'
      AND r.id <> lr.id
      AND r.start_date <= make_date(yy, 12, 31)
      AND r.end_date >= make_date(yy, 1, 1);

    IF need + v_used + COALESCE(v_other_pend, 0) > v_ent THEN
      RAISE EXCEPTION 'annual leave would exceed balance for calendar year %', yy;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) TO authenticated;


CREATE OR REPLACE FUNCTION public.approve_leave_and_clear_attendance(
  p_leave_id UUID,
  p_admin_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_leave public.leave_requests%ROWTYPE;
  v_removed_count INTEGER := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = v_actor_id
      AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve leave';
  END IF;

  SELECT *
  INTO v_leave
  FROM public.leave_requests
  WHERE id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF v_leave.status = 'approved' THEN
    RETURN jsonb_build_object(
      'attendance_removed_count', 0,
      'leave_id', v_leave.id,
      'status', v_leave.status
    );
  END IF;

  IF v_leave.status = 'rejected' THEN
    RAISE EXCEPTION 'Rejected leave cannot be approved directly';
  END IF;

  PERFORM public.assert_annual_leave_approval_allowed(p_leave_id);

  UPDATE public.leave_requests
  SET status = 'approved',
      admin_comment = COALESCE(p_admin_comment, v_leave.admin_comment)
  WHERE id = v_leave.id;

  -- Half-day annual: employee may still clock in for the other half — do not delete attendance.
  IF v_leave.leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    v_removed_count := 0;
  ELSE
    DELETE FROM public.attendance
    WHERE user_id = v_leave.user_id
      AND date >= v_leave.start_date
      AND date <= v_leave.end_date;

    GET DIAGNOSTICS v_removed_count = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'attendance_removed_count', v_removed_count,
    'leave_id', v_leave.id,
    'status', 'approved'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_leave_and_clear_attendance(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_leave_and_clear_attendance(UUID, TEXT)
  TO authenticated;


CREATE OR REPLACE FUNCTION public.leave_requests_enforce_half_day_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    IF NEW.start_date IS DISTINCT FROM NEW.end_date THEN
      RAISE EXCEPTION 'Half-day annual leave must use a single date (start_date = end_date)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leave_requests_half_day_dates ON public.leave_requests;
CREATE TRIGGER trg_leave_requests_half_day_dates
  BEFORE INSERT OR UPDATE OF leave_type, start_date, end_date
  ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.leave_requests_enforce_half_day_dates();
