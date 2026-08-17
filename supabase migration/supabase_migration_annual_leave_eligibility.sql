-- Annual leave is for permanent and contract staff only.
-- Interns (employment_status or intern pay) have no annual entitlement.
-- Run in Supabase SQL Editor after payroll employment_status + annual leave.

CREATE OR REPLACE FUNCTION public.user_has_annual_leave(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_status TEXT;
  v_comp TEXT;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_actor <> p_user_id AND NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = v_actor AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not allowed to read this annual leave eligibility';
  END IF;

  SELECT p.employment_status, p.compensation_type
  INTO v_status, v_comp
  FROM public.payroll_salary_settings p
  WHERE p.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN TRUE;
  END IF;

  IF lower(trim(COALESCE(v_comp, ''))) = 'intern' THEN
    RETURN FALSE;
  END IF;

  RETURN lower(trim(COALESCE(v_status, 'permanent'))) IN ('permanent', 'contract');
EXCEPTION
  WHEN undefined_table THEN
    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.user_has_annual_leave(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_has_annual_leave(UUID) TO authenticated;


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
  IF NOT public.user_has_annual_leave(p_user_id) THEN
    RETURN 0;
  END IF;

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

  v_svc := EXTRACT(YEAR FROM AGE(make_date(p_year, 12, 31)::timestamp, v_ref::timestamp));

  RETURN public.default_annual_entitlement(v_svc);
END;
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

  IF NOT public.user_has_annual_leave(lr.user_id) THEN
    RAISE EXCEPTION 'annual leave is only for permanent and contract staff';
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


CREATE OR REPLACE FUNCTION public.leave_requests_enforce_annual_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.leave_type IN ('annual', 'annual_half_am', 'annual_half_pm')
     AND NOT public.user_has_annual_leave(NEW.user_id) THEN
    RAISE EXCEPTION 'annual leave is only for permanent and contract staff';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leave_requests_annual_eligibility ON public.leave_requests;
CREATE TRIGGER trg_leave_requests_annual_eligibility
  BEFORE INSERT OR UPDATE OF leave_type, user_id
  ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.leave_requests_enforce_annual_eligibility();
