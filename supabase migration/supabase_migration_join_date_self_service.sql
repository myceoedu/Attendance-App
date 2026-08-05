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
