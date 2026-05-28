-- ============================================================
-- MIGRATION: Annual leave entitlement, summaries, approve guard
-- Run in Supabase SQL Editor after core setup / prior migrations.
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS employment_start_date DATE,
  ADD COLUMN IF NOT EXISTS annual_leave_entitlement_override NUMERIC(4, 1);


-- ───────────────────────────────────────────────
-- Non-admins cannot change HR-only columns
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.users_protect_hr_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.employment_start_date IS DISTINCT FROM OLD.employment_start_date
     OR NEW.annual_leave_entitlement_override IS DISTINCT FROM OLD.annual_leave_entitlement_override THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Only admins can edit employment dates or annual leave entitlement override.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_protect_hr_fields ON public.users;
CREATE TRIGGER trg_users_protect_hr_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_protect_hr_fields();


CREATE OR REPLACE FUNCTION public.default_annual_entitlement(p_years NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_years IS NULL OR p_years < 2 THEN 8::numeric
    WHEN p_years >= 2 AND p_years <= 5 THEN 12::numeric
    ELSE 16::numeric
  END;
$$;


CREATE OR REPLACE FUNCTION public.annual_leave_overlap_days(
  p_start DATE,
  p_end DATE,
  p_year INTEGER
)
RETURNS INTEGER
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN 0
    ELSE (
      LEAST(p_end, make_date(p_year, 12, 31))
      - GREATEST(p_start, make_date(p_year, 1, 1))
      + 1
    )
  END::integer;
$$;


CREATE OR REPLACE FUNCTION public.user_annual_entitlement_for_year(
  p_user_id UUID,
  p_year INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override NUMERIC;
  v_created DATE;
  v_emp DATE;
  v_ref DATE;
  v_svc NUMERIC;
BEGIN
  SELECT
    u.annual_leave_entitlement_override,
    (timezone('Asia/Kuala_Lumpur'::text, u.created_at))::date,
    u.employment_start_date
  INTO v_override, v_created, v_emp
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF v_override IS NOT NULL THEN
    RETURN v_override;
  END IF;

  v_ref := COALESCE(v_emp, v_created);
  IF v_ref > make_date(p_year, 12, 31) THEN
    RETURN 0;
  END IF;

  -- Years of service (calendar) as of Dec 31 of [p_year]
  v_svc := EXTRACT(YEAR FROM AGE(make_date(p_year, 12, 31)::timestamp, v_ref::timestamp));

  RETURN public.default_annual_entitlement(v_svc);
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
  SELECT COALESCE(SUM(public.annual_leave_overlap_days(lr.start_date, lr.end_date, p_year)), 0)::numeric
  FROM public.leave_requests lr
  WHERE lr.user_id = p_user_id
    AND lr.leave_type = 'annual'
    AND lr.status = ANY(p_statuses)
    AND lr.start_date <= make_date(p_year, 12, 31)
    AND lr.end_date >= make_date(p_year, 1, 1);
$$;


CREATE OR REPLACE FUNCTION public.get_annual_leave_summary(p_user_id UUID, p_year INTEGER)
RETURNS TABLE (
  entitlement NUMERIC,
  used NUMERIC,
  pending NUMERIC,
  remaining NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_ent NUMERIC;
  v_used NUMERIC;
  v_pend NUMERIC;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_actor <> p_user_id AND NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = v_actor AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not allowed to read this annual leave summary';
  END IF;

  v_ent := public.user_annual_entitlement_for_year(p_user_id, p_year);
  v_used := public.annual_leave_days_for_requests(
    p_user_id, p_year, ARRAY['approved']::TEXT[]
  );
  v_pend := public.annual_leave_days_for_requests(
    p_user_id, p_year, ARRAY['pending']::TEXT[]
  );

  entitlement := v_ent;
  used := v_used;
  pending := v_pend;
  remaining := GREATEST(0::numeric, COALESCE(v_ent, 0) - COALESCE(v_used, 0) - COALESCE(v_pend, 0));

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.get_annual_leave_summary(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_annual_leave_summary(UUID, INTEGER) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_annual_leave_summaries_batch(
  p_user_ids UUID[],
  p_year INTEGER
)
RETURNS TABLE (
  user_id UUID,
  entitlement NUMERIC,
  used NUMERIC,
  pending NUMERIC,
  remaining NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  uid UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_actor AND u.role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can batch-read annual leave summaries';
  END IF;

  FOREACH uid IN ARRAY p_user_ids
  LOOP
    SELECT
      g.entitlement,
      g.used,
      g.pending,
      g.remaining
    INTO entitlement, used, pending, remaining
    FROM public.get_annual_leave_summary(uid, p_year) AS g;

    user_id := uid;
    RETURN NEXT;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.get_annual_leave_summaries_batch(UUID[], INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_annual_leave_summaries_batch(UUID[], INTEGER) TO authenticated;


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
  v_ent NUMERIC;
  v_used NUMERIC;
  v_other_pend NUMERIC;
  ov INTEGER;
BEGIN
  SELECT *
  INTO lr
  FROM public.leave_requests lr0
  WHERE lr0.id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF lr.leave_type IS DISTINCT FROM 'annual' THEN
    RETURN;
  END IF;

  y_from := EXTRACT(YEAR FROM lr.start_date)::integer;
  y_to := EXTRACT(YEAR FROM lr.end_date)::integer;

  FOR yy IN y_from .. y_to LOOP
    ov := public.annual_leave_overlap_days(lr.start_date, lr.end_date, yy);

    IF ov <= 0 THEN
      CONTINUE;
    END IF;

    v_ent := public.user_annual_entitlement_for_year(lr.user_id, yy);

    v_used := public.annual_leave_days_for_requests(
      lr.user_id, yy, ARRAY['approved']::TEXT[]
    );

    SELECT COALESCE(SUM(public.annual_leave_overlap_days(r.start_date, r.end_date, yy)), 0)
    INTO v_other_pend
    FROM public.leave_requests r
    WHERE r.user_id = lr.user_id
      AND r.leave_type = 'annual'
      AND r.status = 'pending'
      AND r.id <> lr.id
      AND r.start_date <= make_date(yy, 12, 31)
      AND r.end_date >= make_date(yy, 1, 1);

    IF ov::numeric + v_used + COALESCE(v_other_pend, 0) > v_ent THEN
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

  DELETE FROM public.attendance
  WHERE user_id = v_leave.user_id
    AND date >= v_leave.start_date
    AND date <= v_leave.end_date;

  GET DIAGNOSTICS v_removed_count = ROW_COUNT;

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
