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
