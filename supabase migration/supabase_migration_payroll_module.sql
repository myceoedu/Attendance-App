-- ============================================================
-- PAYROLL MODULE (single company) — Malaysia-oriented MVP
-- Run in Supabase SQL Editor after core app migrations.
-- EPF/SOCSO/EIS % are admin-editable; validate against official tables yearly.
-- ============================================================

-- ── Statutory configuration (effective-dated; app picks latest by effective_from)
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

-- ── Per-employee salary master (1:1 with users)
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

-- ── Monthly payroll run
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

-- ── Line items per employee per run (amounts stored after calculate)
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

-- ── RLS (admins only)
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
