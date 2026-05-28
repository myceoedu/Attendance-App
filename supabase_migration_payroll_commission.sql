-- Monthly commission (admin key-in) for payroll. Run in Supabase SQL Editor.

ALTER TABLE public.payroll_salary_settings
  ADD COLUMN IF NOT EXISTS monthly_commission NUMERIC(14, 2) NOT NULL DEFAULT 0
  CHECK (monthly_commission >= 0);

ALTER TABLE public.payroll_items
  ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(14, 2) NOT NULL DEFAULT 0
  CHECK (commission_amount >= 0);
