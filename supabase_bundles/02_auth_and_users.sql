-- ============================================================
-- BUNDLE 2 — Auth & users
-- Bundle for NEW Supabase project setup
-- Run order step: 2 of 7
-- Source files (in order):
--   - supabase_migration_username_auth.sql
--   - supabase_migration_username_flexible.sql
--   - supabase_migration_employee_profile_extended.sql
--   - supabase_migration_join_date_self_service.sql
--   - supabase_migration_admin_update_users_rls.sql
-- Idempotent where possible (safe to re-run after a partial failure).
-- ============================================================


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_username_auth.sql
-- ------------------------------------------------------------

-- ============================================================
-- MIGRATION: Username login + registration (EXISTING DB only)
-- Supabase â†’ SQL Editor. Fix errors manually if a step already ran.
-- ============================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS username text;

-- Backfill: email local-part + short id suffix (unique per row)
UPDATE public.users u
SET username = lower(
  regexp_replace(split_part(coalesce(nullif(trim(u.email), ''), 'user'), '@', 1), '[^a-zA-Z0-9_]', '_', 'g')
  || '_' || substr(replace(u.id::text, '-', ''), 1, 8)
)
WHERE u.username IS NULL OR trim(u.username) = '';

ALTER TABLE public.users ALTER COLUMN username SET NOT NULL;

DROP INDEX IF EXISTS users_username_lower_idx;
CREATE UNIQUE INDEX users_username_lower_idx
  ON public.users (lower(trim(username)));

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  -- Keep display form (spaces/case). Uniqueness is via lower(trim(username)).
  v_username text := trim(both FROM regexp_replace(
    COALESCE(NEW.raw_user_meta_data->>'username', ''),
    '\s+',
    ' ',
    'g'
  ));
  v_name text := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(trim(NEW.raw_user_meta_data->>'username'), ''),
    ''
  );
BEGIN
  IF length(v_username) < 3 THEN
    RAISE EXCEPTION 'username required in user metadata';
  END IF;
  INSERT INTO public.users (id, email, name, username, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_name,
    v_username,
    COALESCE(NEW.raw_user_meta_data->>'role', 'employee')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_email_for_login(p_username text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.email
  FROM public.users u
  WHERE lower(trim(u.username)) = lower(trim(p_username))
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_email_for_login(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_email_for_login(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE lower(trim(u.username)) = lower(trim(p_username))
  );
$$;

REVOKE ALL ON FUNCTION public.is_username_available(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_username_available(text) TO anon, authenticated;


-- ------------------------------------------------------------
-- END: supabase_migration_username_auth.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_username_flexible.sql
-- ------------------------------------------------------------

-- ============================================================
-- Flexible usernames (spaces + mixed case), e.g. "AHMAD FAIZ"
-- Safe to run on an existing project. Login stays case-insensitive.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  -- Keep display form (spaces/case). Uniqueness is via lower(trim(username)).
  v_username text := trim(both FROM regexp_replace(
    COALESCE(NEW.raw_user_meta_data->>'username', ''),
    '\s+',
    ' ',
    'g'
  ));
  v_name text := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(trim(NEW.raw_user_meta_data->>'username'), ''),
    ''
  );
BEGIN
  IF length(v_username) < 3 THEN
    RAISE EXCEPTION 'username required in user metadata';
  END IF;
  INSERT INTO public.users (id, email, name, username, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    v_name,
    v_username,
    COALESCE(NEW.raw_user_meta_data->>'role', 'employee')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Uniqueness remains case-insensitive (AHMAD FAIZ == ahmad faiz).
DROP INDEX IF EXISTS users_username_lower_idx;
CREATE UNIQUE INDEX users_username_lower_idx
  ON public.users (lower(trim(username)));


-- ------------------------------------------------------------
-- END: supabase_migration_username_flexible.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_employee_profile_extended.sql
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- END: supabase_migration_employee_profile_extended.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_join_date_self_service.sql
-- ------------------------------------------------------------

-- ============================================================
-- Allow employees to update their own employment_start_date
-- Run in Supabase SQL Editor after prior migrations.
--
-- Previously only admins could change employment_start_date.
-- Self-service profile now sends this field for the signed-in user.
-- ============================================================

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


-- ------------------------------------------------------------
-- END: supabase_migration_join_date_self_service.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_admin_update_users_rls.sql
-- ------------------------------------------------------------

-- Admins can update any user profile (in addition to "own row" policy).
-- Run in Supabase SQL Editor if updates from the admin app are blocked by RLS.

DROP POLICY IF EXISTS "Admins can update any user profile" ON public.users;

CREATE POLICY "Admins can update any user profile"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );


-- ------------------------------------------------------------
-- END: supabase_migration_admin_update_users_rls.sql
-- ------------------------------------------------------------

