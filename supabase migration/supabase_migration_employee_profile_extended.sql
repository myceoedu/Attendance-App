-- ============================================================
-- EMPLOYEE SELF-SERVICE PROFILE (extended fields)
-- Run in Supabase SQL Editor after prior migrations.
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS marital_status TEXT,
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS ic_number TEXT,
  ADD COLUMN IF NOT EXISTS job_title TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS employee_code TEXT,
  ADD COLUMN IF NOT EXISTS epf_number TEXT,
  ADD COLUMN IF NOT EXISTS socso_number TEXT,
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
  ADD COLUMN IF NOT EXISTS education_level TEXT,
  ADD COLUMN IF NOT EXISTS education_institution TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_relationship TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT;


-- Optional company-unique employee badge (not enforced unique to allow blanks)
CREATE UNIQUE INDEX IF NOT EXISTS users_employee_code_unique
  ON public.users (employee_code)
  WHERE employee_code IS NOT NULL AND trim(employee_code) <> '';


-- Harden: only admins may change role or HR-only columns (extend existing trigger)
CREATE OR REPLACE FUNCTION public.users_protect_hr_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Only admins can change role.';
    END IF;
  END IF;

  IF NEW.annual_leave_entitlement_override IS DISTINCT FROM OLD.annual_leave_entitlement_override THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Only admins can edit annual leave entitlement override.';
    END IF;
  END IF;

  IF NEW.employment_start_date IS DISTINCT FROM OLD.employment_start_date THEN
    IF auth.uid() IS DISTINCT FROM NEW.id THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin'
      ) THEN
        RAISE EXCEPTION 'Only admins can edit employment start date for other users.';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
