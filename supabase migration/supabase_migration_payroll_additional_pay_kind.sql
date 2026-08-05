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

-- Infer historical kind (cannot distinguish incentive/increment — default allowance).
UPDATE public.payroll_salary_settings
SET additional_pay_kind = CASE
  WHEN monthly_commission > 0 AND fixed_allowance = 0 THEN 'commission'
  ELSE 'allowance'
END;

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS additional_pay_kind TEXT;
