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
