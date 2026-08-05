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
