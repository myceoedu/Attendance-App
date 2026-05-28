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
