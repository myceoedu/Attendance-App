-- ============================================================
-- OPTIONAL — Payroll test seed data
-- Bundle for NEW Supabase project setup
-- Run order step: After 1–7 only if you want fake test data
-- Source files (in order):
--   - supabase_seed_payroll_test_data.sql
-- Idempotent where possible (safe to re-run after a partial failure).
-- ============================================================


-- ------------------------------------------------------------
-- BEGIN: supabase_seed_payroll_test_data.sql
-- ------------------------------------------------------------

-- ============================================================
-- SEED DATA FOR PAYROLL / ATTENDANCE / LEAVE TESTING
-- Run in Supabase Dashboard â†’ SQL Editor.
--
-- Runs as the database role (bypasses RLS). Safe to re-run.
-- It seeds February, March, April, and August by default.
--
-- Important:
--   Leave days are excluded from attendance, so the calendar does not show
--   "Present" and "Leave" for the same day.
--
-- If your DB enforces unique (user_id, date), attendance rows are upserted.
-- Set v_user to a dedicated test employee if you do not want to overwrite
-- existing attendance in the selected months.
--
-- AFTER THIS SCRIPT:
--   Create payroll runs in the app (Payroll â†’ New period) for
--   each month you seeded, then tap Sync & Calculate.
--
-- EDIT THE TARGET EMPLOYEE CONSTANTS IN THE DO BLOCK BELOW IF NEEDED.
-- ============================================================

DO $$
DECLARE
  -- Target employee. Use ONE of these:
  --   1) v_user: paste public.users.id directly
  --   2) v_target_email: paste employee email
  --   3) v_target_username: paste employee username
  --
  -- If all are NULL, the script uses the newest employee row by created_at.
  v_user             uuid := NULL;
  v_target_email     text := NULL;
  v_target_username  text := NULL;

  v_year            int := 2026;
  v_months          int[] := ARRAY[2, 3, 4, 8]; -- Feb, Mar, Apr, Aug

  v_basic           numeric := 4500.00;
  v_allowance       numeric := 300.00;
  v_commission      numeric := 150.00;

  v_month_start     date;
  v_month_end       date;
  v_month           int;
  removed_leave     bigint;
BEGIN
  IF v_user IS NULL THEN
    SELECT u.id INTO v_user
    FROM public.users u
    WHERE u.role = 'employee'
      AND (
        v_target_email IS NULL
        OR lower(trim(u.email)) = lower(trim(v_target_email))
      )
      AND (
        v_target_username IS NULL
        OR lower(trim(u.username)) = lower(trim(v_target_username))
      )
    ORDER BY u.created_at DESC, u.name NULLS LAST, u.username
    LIMIT 1;
  END IF;

  IF v_user IS NULL THEN
    RAISE EXCEPTION
      'No matching employee found. Set v_user, v_target_email, or v_target_username for a public.users row with role = employee.';
  END IF;

  -- Salary master (1:1 with users). Keeps other columns at sane defaults.
  INSERT INTO public.payroll_salary_settings (
    user_id,
    staff_id,
    department,
    position,
    employment_status,
    basic_salary,
    fixed_allowance,
    monthly_commission,
    monthly_incentive,
    monthly_increment,
    compensation_type,
    ot_eligible,
    epf_category,
    socso_category,
    eis_eligible,
    payment_method,
    payroll_status,
    updated_at
  )
  VALUES (
    v_user,
    'TEST-001',
    'Operations',
    'Test Staff',
    'permanent',
    v_basic,
    v_allowance,
    v_commission,
    0,
    0,
    'employee',
    true,
    'standard',
    'standard',
    true,
    'bank_transfer',
    'active',
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    basic_salary         = EXCLUDED.basic_salary,
    fixed_allowance      = EXCLUDED.fixed_allowance,
    monthly_commission   = EXCLUDED.monthly_commission,
    monthly_incentive    = EXCLUDED.monthly_incentive,
    monthly_increment    = EXCLUDED.monthly_increment,
    employment_status    = EXCLUDED.employment_status,
    compensation_type    = EXCLUDED.compensation_type,
    payroll_status       = EXCLUDED.payroll_status,
    updated_at           = now();

  -- Remove only previous seed leave rows for the selected months.
  DELETE FROM public.leave_requests lr
  WHERE lr.user_id = v_user
    AND lr.reason LIKE '[payroll seed]%'
    AND EXTRACT(YEAR FROM lr.start_date)::int = v_year
    AND EXTRACT(MONTH FROM lr.start_date)::int = ANY(v_months);
  GET DIAGNOSTICS removed_leave = ROW_COUNT;

  RAISE NOTICE 'Target user_id = %', v_user;
  RAISE NOTICE 'Target employee = %',
    (
      SELECT COALESCE(NULLIF(u.name, ''), u.username) || ' <' || u.email || '>'
      FROM public.users u
      WHERE u.id = v_user
    );
  RAISE NOTICE 'Removed % prior seed leave row(s)', removed_leave;

  -- Insert approved leave first. These days will be removed from attendance.
  WITH leave_seed(month_no, start_day, end_day, leave_type, label) AS (
    VALUES
      (2,  5,  6, 'unpaid',         'February unpaid leave'),
      (2, 19, 19, 'annual',         'February annual leave'),
      (3, 10, 11, 'unpaid',         'March unpaid leave'),
      (3, 25, 25, 'sick',           'March sick leave'),
      (4, 14, 15, 'unpaid',         'April unpaid leave'),
      (8, 12, 13, 'unpaid',         'August unpaid leave'),
      (8, 26, 26, 'annual',         'August annual leave')
  )
  INSERT INTO public.leave_requests (
    user_id,
    leave_type,
    start_date,
    end_date,
    reason,
    status,
    admin_comment
  )
  SELECT
    v_user,
    leave_type,
    make_date(v_year, month_no, start_day),
    make_date(v_year, month_no, end_day),
    '[payroll seed] ' || label,
    'approved',
    'Inserted by supabase_seed_payroll_test_data.sql'
  FROM leave_seed
  WHERE month_no = ANY(v_months);

  -- Remove attendance on approved leave dates so the calendar stays clear.
  WITH leave_dates AS (
    SELECT gs.d::date AS leave_date
    FROM public.leave_requests lr
    CROSS JOIN LATERAL generate_series(
      lr.start_date,
      lr.end_date,
      interval '1 day'
    ) AS gs(d)
    WHERE lr.user_id = v_user
      AND lr.status = 'approved'
      AND lr.reason LIKE '[payroll seed]%'
      AND EXTRACT(YEAR FROM lr.start_date)::int = v_year
      AND EXTRACT(MONTH FROM lr.start_date)::int = ANY(v_months)
  )
  DELETE FROM public.attendance a
  USING leave_dates ld
  WHERE a.user_id = v_user
    AND a.date = ld.leave_date;

  -- Weekday attendance Mon-Fri: upsert for unique (user_id, date).
  -- present_days = count of rows with non-null clock_in_time (matches app).
  INSERT INTO public.attendance (
    user_id,
    clock_in_time,
    clock_out_time,
    date,
    status,
    location
  )
  SELECT
    v_user,
    (to_char(d::date, 'YYYY-MM-DD') || ' 09:00:00+08')::timestamptz,
    (to_char(d::date, 'YYYY-MM-DD') || ' 18:00:00+08')::timestamptz,
    d::date,
    'completed',
    'Test seed'
  FROM unnest(v_months) AS seeded_month(month_no)
  CROSS JOIN LATERAL generate_series(
    make_date(v_year, seeded_month.month_no, 1),
    (make_date(v_year, seeded_month.month_no, 1) + interval '1 month - 1 day')::date,
    interval '1 day'
  ) AS s(d)
  WHERE EXTRACT(ISODOW FROM s.d) BETWEEN 1 AND 5
    AND NOT EXISTS (
      SELECT 1
      FROM public.leave_requests lr
      WHERE lr.user_id = v_user
        AND lr.status = 'approved'
        AND lr.reason LIKE '[payroll seed]%'
        AND s.d::date BETWEEN lr.start_date AND lr.end_date
    )
  ON CONFLICT (user_id, date) DO UPDATE SET
    clock_in_time  = EXCLUDED.clock_in_time,
    clock_out_time = EXCLUDED.clock_out_time,
    status         = EXCLUDED.status,
    location       = EXCLUDED.location;

  FOREACH v_month IN ARRAY v_months LOOP
    v_month_start := make_date(v_year, v_month, 1);
    v_month_end := (v_month_start + interval '1 month - 1 day')::date;
    RAISE NOTICE
      'Seeded %/%: weekday attendance from % to %, excluding approved seed leave days. In the app: Payroll -> New period -> Sync & Calculate.',
      v_month,
      v_year,
      v_month_start,
      v_month_end;
  END LOOP;
END $$;


-- ------------------------------------------------------------
-- END: supabase_seed_payroll_test_data.sql
-- ------------------------------------------------------------

