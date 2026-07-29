-- ============================================================
-- MIGRATION: Username login + registration (EXISTING DB only)
-- Supabase → SQL Editor. Fix errors manually if a step already ran.
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
