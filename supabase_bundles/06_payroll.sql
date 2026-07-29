-- ============================================================
-- BUNDLE 6 — Payroll module
-- Bundle for NEW Supabase project setup
-- Run order step: 6 of 7
-- Source files (in order):
--   - supabase_migration_payroll_module.sql
--   - supabase_migration_payroll_commission.sql
--   - supabase_migration_payroll_compensation_type.sql
--   - supabase_migration_payroll_employment_status.sql
--   - supabase_migration_payroll_additional_pay_kind.sql
--   - supabase_migration_payroll_salary_multi_component.sql
--   - supabase_migration_payroll_rls_fix_recursion.sql
--   - supabase_migration_payroll_employee_read_rls.sql
-- Idempotent where possible (safe to re-run after a partial failure).
-- ============================================================


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_module.sql
-- ------------------------------------------------------------

-- ============================================================
-- PAYROLL MODULE (single company) â€” Malaysia-oriented MVP
-- Run in Supabase SQL Editor after core app migrations.
-- EPF/SOCSO/EIS % are admin-editable; validate against official tables yearly.
-- ============================================================

-- â”€â”€ Statutory configuration (effective-dated; app picks latest by effective_from)
CREATE TABLE IF NOT EXISTS public.payroll_statutory_config (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label                  TEXT NOT NULL DEFAULT 'Default',
  effective_from         DATE NOT NULL DEFAULT CURRENT_DATE,
  epf_employee_pct       NUMERIC(8, 4) NOT NULL DEFAULT 11.0000,
  epf_employer_pct       NUMERIC(8, 4) NOT NULL DEFAULT 13.0000,
  epf_salary_ceiling     NUMERIC(14, 2),
  socso_employee_pct     NUMERIC(8, 4) NOT NULL DEFAULT 0.5000,
  socso_employer_pct      NUMERIC(8, 4) NOT NULL DEFAULT 1.7500,
  eis_employee_pct       NUMERIC(8, 4) NOT NULL DEFAULT 0.2000,
  eis_employer_pct       NUMERIC(8, 4) NOT NULL DEFAULT 0.2000,
  ot_hourly_multiplier   NUMERIC(8, 4) NOT NULL DEFAULT 1.5000,
  standard_hours_per_day NUMERIC(6, 2) NOT NULL DEFAULT 8.00,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One seed row if table empty (adjust to your year / official rates)
INSERT INTO public.payroll_statutory_config (label, effective_from)
SELECT 'Malaysia default template', CURRENT_DATE
WHERE NOT EXISTS (SELECT 1 FROM public.payroll_statutory_config LIMIT 1);

-- â”€â”€ Per-employee salary master (1:1 with users)
CREATE TABLE IF NOT EXISTS public.payroll_salary_settings (
  user_id              UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  staff_id             TEXT NOT NULL DEFAULT '',
  department           TEXT NOT NULL DEFAULT '',
  position             TEXT NOT NULL DEFAULT '',
  basic_salary         NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (basic_salary >= 0),
  fixed_allowance      NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (fixed_allowance >= 0),
  ot_eligible          BOOLEAN NOT NULL DEFAULT true,
  epf_category         TEXT NOT NULL DEFAULT 'standard',
  socso_category       TEXT NOT NULL DEFAULT 'standard',
  eis_eligible         BOOLEAN NOT NULL DEFAULT true,
  payment_method       TEXT NOT NULL DEFAULT 'bank_transfer',
  bank_name            TEXT NOT NULL DEFAULT '',
  bank_account_number  TEXT NOT NULL DEFAULT '',
  payroll_status       TEXT NOT NULL DEFAULT 'active'
    CHECK (payroll_status IN ('active', 'hold')),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- â”€â”€ Monthly payroll run
CREATE TABLE IF NOT EXISTS public.payroll_runs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_year           INTEGER NOT NULL CHECK (period_year >= 2020 AND period_year <= 2100),
  period_month          INTEGER NOT NULL CHECK (period_month >= 1 AND period_month <= 12),
  status                TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'calculated', 'approved', 'paid', 'cancelled')),
  statutory_config_id   UUID REFERENCES public.payroll_statutory_config(id) ON DELETE SET NULL,
  pay_date              DATE,
  notes                 TEXT NOT NULL DEFAULT '',
  total_net_pay         NUMERIC(16, 2),
  total_employer_cost   NUMERIC(16, 2),
  employee_count        INTEGER,
  created_by            UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_by           UUID REFERENCES public.users(id) ON DELETE SET NULL,
  paid_by               UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_at           TIMESTAMPTZ,
  paid_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (period_year, period_month)
);

CREATE INDEX IF NOT EXISTS payroll_runs_period_idx
  ON public.payroll_runs (period_year DESC, period_month DESC);

-- â”€â”€ Line items per employee per run (amounts stored after calculate)
CREATE TABLE IF NOT EXISTS public.payroll_items (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payroll_run_id         UUID NOT NULL REFERENCES public.payroll_runs(id) ON DELETE CASCADE,
  user_id                UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  employee_name_snapshot TEXT NOT NULL DEFAULT '',
  working_weekdays       INTEGER NOT NULL DEFAULT 0,
  present_days           INTEGER NOT NULL DEFAULT 0,
  ot_hours               NUMERIC(10, 2) NOT NULL DEFAULT 0,
  unpaid_leave_days      NUMERIC(10, 2) NOT NULL DEFAULT 0,
  basic_amount           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  allowance_amount       NUMERIC(14, 2) NOT NULL DEFAULT 0,
  ot_amount              NUMERIC(14, 2) NOT NULL DEFAULT 0,
  unpaid_leave_deduction NUMERIC(14, 2) NOT NULL DEFAULT 0,
  epf_employee           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  epf_employer           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  socso_employee         NUMERIC(14, 2) NOT NULL DEFAULT 0,
  socso_employer         NUMERIC(14, 2) NOT NULL DEFAULT 0,
  eis_employee           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  eis_employer           NUMERIC(14, 2) NOT NULL DEFAULT 0,
  gross_pay              NUMERIC(14, 2) NOT NULL DEFAULT 0,
  total_deduction        NUMERIC(14, 2) NOT NULL DEFAULT 0,
  net_salary             NUMERIC(14, 2) NOT NULL DEFAULT 0,
  calc_note              TEXT NOT NULL DEFAULT '',
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (payroll_run_id, user_id)
);

CREATE INDEX IF NOT EXISTS payroll_items_run_idx ON public.payroll_items (payroll_run_id);
CREATE INDEX IF NOT EXISTS payroll_items_user_idx ON public.payroll_items (user_id);

-- â”€â”€ RLS (admins only)
ALTER TABLE public.payroll_statutory_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_salary_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payroll_statutory_admin_all ON public.payroll_statutory_config;
CREATE POLICY payroll_statutory_admin_all
  ON public.payroll_statutory_config FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS payroll_salary_admin_all ON public.payroll_salary_settings;
CREATE POLICY payroll_salary_admin_all
  ON public.payroll_salary_settings FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS payroll_runs_admin_all ON public.payroll_runs;
CREATE POLICY payroll_runs_admin_all
  ON public.payroll_runs FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS payroll_items_admin_all ON public.payroll_items;
CREATE POLICY payroll_items_admin_all
  ON public.payroll_items FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

-- Optional: realtime (ignore error if already added)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.payroll_runs;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.payroll_items;


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_module.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_commission.sql
-- ------------------------------------------------------------

-- Monthly commission (admin key-in) for payroll. Run in Supabase SQL Editor.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS monthly_commission NUMERIC(14, 2) NOT NULL DEFAULT 0
  CHECK (monthly_commission >= 0);

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(14, 2) NOT NULL DEFAULT 0
  CHECK (commission_amount >= 0);


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_commission.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_compensation_type.sql
-- ------------------------------------------------------------

-- Compensation type: employee (statutory + unpaid weekday rules) vs intern (allowance / calendar days).
-- Run in Supabase SQL Editor after payroll module migration.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS compensation_type TEXT NOT NULL DEFAULT 'employee';

ALTER TABLE public.payroll_salary_settings
  DROP CONSTRAINT IF EXISTS payroll_salary_settings_compensation_type_check;

ALTER TABLE public.payroll_salary_settings
  ADD CONSTRAINT payroll_salary_settings_compensation_type_check
  CHECK (compensation_type IN ('employee', 'intern'));

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS compensation_type TEXT NOT NULL DEFAULT 'employee';

ALTER TABLE public.payroll_items
  DROP CONSTRAINT IF EXISTS payroll_items_compensation_type_check;

ALTER TABLE public.payroll_items
  ADD CONSTRAINT payroll_items_compensation_type_check
  CHECK (compensation_type IN ('employee', 'intern'));


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_compensation_type.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_employment_status.sql
-- ------------------------------------------------------------

-- HR employment category (permanent, contract, probation, intern, part time).
-- Run in Supabase SQL Editor.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS employment_status TEXT NOT NULL DEFAULT 'permanent';

ALTER TABLE public.payroll_salary_settings
  DROP CONSTRAINT IF EXISTS payroll_salary_settings_employment_status_check;

ALTER TABLE public.payroll_salary_settings
  ADD CONSTRAINT payroll_salary_settings_employment_status_check
  CHECK (employment_status IN (
    'permanent',
    'contract',
    'probation',
    'intern',
    'part_time'
  ));

-- Backfill any legacy NULLs (should not happen with NOT NULL + default).
UPDATE public.payroll_salary_settings
SET employment_status = 'permanent'
WHERE employment_status IS NULL;

UPDATE public.payroll_salary_settings
SET updated_at = now()
WHERE updated_at IS NULL;


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_employment_status.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_additional_pay_kind.sql
-- ------------------------------------------------------------

-- Additional pay type on salary master (allowance vs commission vs incentive vs increment).
-- Payroll items store a snapshot label for payslips.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS additional_pay_kind TEXT NOT NULL DEFAULT 'allowance';

ALTER TABLE public.payroll_salary_settings
  DROP CONSTRAINT IF EXISTS payroll_salary_settings_additional_pay_kind_check;

ALTER TABLE public.payroll_salary_settings
  ADD CONSTRAINT payroll_salary_settings_additional_pay_kind_check
  CHECK (additional_pay_kind IN ('allowance', 'commission', 'incentive', 'increment'));

-- Legacy rows: if both allowance and commission were set, merge into one allowance bucket.
UPDATE public.payroll_salary_settings
SET
  fixed_allowance = fixed_allowance + monthly_commission,
  monthly_commission = 0
WHERE fixed_allowance > 0 AND monthly_commission > 0;

-- Infer historical kind (cannot distinguish incentive/increment â€” default allowance).
UPDATE public.payroll_salary_settings
SET additional_pay_kind = CASE
  WHEN monthly_commission > 0 AND fixed_allowance = 0 THEN 'commission'
  ELSE 'allowance'
END;

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS additional_pay_kind TEXT;


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_additional_pay_kind.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_salary_multi_component.sql
-- ------------------------------------------------------------

-- Split salary add-ons into four optional monthly amounts (allowance, commission, incentive, increment).
-- Run after supabase_migration_payroll_additional_pay_kind.sql if that file was already applied.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS monthly_incentive NUMERIC(14, 2) NOT NULL DEFAULT 0
    CHECK (monthly_incentive >= 0);

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS monthly_increment NUMERIC(14, 2) NOT NULL DEFAULT 0
    CHECK (monthly_increment >= 0);

-- Old single-bucket rows (if additional_pay_kind exists): incentive/increment lived in monthly_commission.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'payroll_salary_settings'
      AND column_name = 'additional_pay_kind'
  ) THEN
    UPDATE public.payroll_salary_settings
    SET
      monthly_incentive = monthly_commission,
      monthly_commission = 0
    WHERE additional_pay_kind = 'incentive' AND monthly_commission > 0;

    UPDATE public.payroll_salary_settings
    SET
      monthly_increment = monthly_commission,
      monthly_commission = 0
    WHERE additional_pay_kind = 'increment' AND monthly_commission > 0;

    ALTER TABLE public.payroll_salary_settings
      DROP CONSTRAINT IF EXISTS payroll_salary_settings_additional_pay_kind_check;
    ALTER TABLE public.payroll_salary_settings
      DROP COLUMN additional_pay_kind;
  END IF;
END $$;

-- Payroll line items: store each component for payslips and reports.
ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS incentive_amount NUMERIC(14, 2) NOT NULL DEFAULT 0;

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS increment_amount NUMERIC(14, 2) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'payroll_items'
      AND column_name = 'additional_pay_kind'
  ) THEN
    ALTER TABLE public.payroll_items DROP COLUMN additional_pay_kind;
  END IF;
END $$;


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_salary_multi_component.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_rls_fix_recursion.sql
-- ------------------------------------------------------------

-- ============================================================
-- Fix: infinite recursion detected in policy for "payroll_runs"
-- (PostgreSQL 42P17)
--
-- Cause: employee SELECT policies cross-reference payroll_runs
-- and payroll_items. Each RLS check re-enters the other table's
-- policies â†’ loop.
--
-- Run in Supabase SQL Editor after payroll module + employee RLS.
-- ============================================================

-- Status lookup without re-entering RLS on payroll_runs
CREATE OR REPLACE FUNCTION public.payroll_run_status_for_rls(p_run_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT status::text FROM public.payroll_runs WHERE id = p_run_id LIMIT 1;
$$;

-- Row existence on payroll_items without re-entering RLS on payroll_items
CREATE OR REPLACE FUNCTION public.user_has_payroll_item_for_rls(
  p_run_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.payroll_items pi
    WHERE pi.payroll_run_id = p_run_id AND pi.user_id = p_user_id
  );
$$;

REVOKE ALL ON FUNCTION public.payroll_run_status_for_rls(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.user_has_payroll_item_for_rls(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.payroll_run_status_for_rls(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_payroll_item_for_rls(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS payroll_items_employee_select_own ON public.payroll_items;
CREATE POLICY payroll_items_employee_select_own
  ON public.payroll_items FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.payroll_run_status_for_rls(payroll_run_id) IN ('approved', 'paid')
  );

DROP POLICY IF EXISTS payroll_runs_employee_select_own ON public.payroll_runs;
CREATE POLICY payroll_runs_employee_select_own
  ON public.payroll_runs FOR SELECT
  TO authenticated
  USING (
    status IN ('approved', 'paid')
    AND public.user_has_payroll_item_for_rls(id, auth.uid())
  );


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_rls_fix_recursion.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_payroll_employee_read_rls.sql
-- ------------------------------------------------------------

-- ============================================================
-- Employee read access to own payslips (approved / paid runs only)
-- Run in Supabase SQL after supabase_migration_payroll_module.sql
-- ============================================================

-- Employees can SELECT their own payroll line items when the parent run
-- is approved or paid (draft/calculated remain HR-only).
DROP POLICY IF EXISTS payroll_items_employee_select_own ON public.payroll_items;
CREATE POLICY payroll_items_employee_select_own
  ON public.payroll_items FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.payroll_runs pr
      WHERE pr.id = payroll_items.payroll_run_id
        AND pr.status IN ('approved', 'paid')
    )
  );

-- Employees can SELECT payroll run headers for runs where they have a line
-- (same approved/paid gate).
DROP POLICY IF EXISTS payroll_runs_employee_select_own ON public.payroll_runs;
CREATE POLICY payroll_runs_employee_select_own
  ON public.payroll_runs FOR SELECT
  TO authenticated
  USING (
    status IN ('approved', 'paid')
    AND EXISTS (
      SELECT 1
      FROM public.payroll_items pi
      WHERE pi.payroll_run_id = payroll_runs.id
        AND pi.user_id = auth.uid()
    )
  );


-- ------------------------------------------------------------
-- END: supabase_migration_payroll_employee_read_rls.sql
-- ------------------------------------------------------------

