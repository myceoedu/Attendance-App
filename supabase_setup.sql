-- ============================================================
-- SUPABASE DATABASE SETUP
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. USERS TABLE (profile data, linked to auth.users)
CREATE TABLE public.users (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username   TEXT NOT NULL,
  name       TEXT NOT NULL DEFAULT '',
  email      TEXT NOT NULL DEFAULT '',
  role       TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('admin', 'employee')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX users_username_lower_idx ON public.users (lower(trim(username)));

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Everyone can read user profiles (needed for joins)
CREATE POLICY "Users are viewable by authenticated users"
  ON public.users FOR SELECT
  TO authenticated
  USING (true);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Allow insert during signup (from trigger or admin)
CREATE POLICY "Enable insert for service role and self"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);


-- 2. ATTENDANCE TABLE
CREATE TABLE public.attendance (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  clock_in_time  TIMESTAMPTZ,
  clock_out_time TIMESTAMPTZ,
  date           DATE NOT NULL DEFAULT CURRENT_DATE,
  status         TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('present', 'in_progress', 'completed')),
  location       TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- Employees see only their own; admins see all
CREATE POLICY "Employees read own attendance"
  ON public.attendance FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Employees insert own attendance"
  ON public.attendance FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Employees update own attendance"
  ON public.attendance FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);


-- 3. LEAVE REQUESTS TABLE
CREATE TABLE public.leave_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  leave_type       TEXT NOT NULL CHECK (leave_type IN ('annual', 'sick', 'emergency')),
  start_date       DATE NOT NULL,
  end_date         DATE NOT NULL,
  reason           TEXT NOT NULL DEFAULT '',
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_comment    TEXT,
  attachment_path  TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;

-- Employees see own; admins see all
CREATE POLICY "Employees read own leave requests"
  ON public.leave_requests FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Employees insert own leave requests"
  ON public.leave_requests FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Only admins can update leave requests (approve/reject)
CREATE POLICY "Admins update leave requests"
  ON public.leave_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );


-- ============================================================
-- OPTIONAL: Auto-create user profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_username text := lower(trim(COALESCE(NEW.raw_user_meta_data->>'username', '')));
  v_name text := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data->>'name'), ''),
    NULLIF(trim(NEW.raw_user_meta_data->>'username'), ''),
    ''
  );
BEGIN
  IF length(v_username) < 2 THEN
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

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- USERNAME LOGIN (resolve username → email for Supabase Auth)
-- ============================================================
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


-- ============================================================
-- STORAGE: Leave attachments (MC / doctor notes — PDF or images)
-- Dashboard → Storage → Create bucket "leave-attachments" (private) if INSERT fails.
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('leave-attachments', 'leave-attachments', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "leave_attachments_insert_own_folder"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'leave-attachments'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

CREATE POLICY "leave_attachments_select_own_or_admin"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'leave-attachments'
    AND (
      split_part(name, '/', 1) = auth.uid()::text
      OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
    )
  );


-- ============================================================
-- NOTIFICATIONS + AUDIT LOGS
-- ============================================================
CREATE TABLE public.app_notifications (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title                    TEXT NOT NULL DEFAULT '',
  body                     TEXT NOT NULL DEFAULT '',
  type                     TEXT NOT NULL DEFAULT 'general',
  related_leave_request_id UUID REFERENCES public.leave_requests(id) ON DELETE SET NULL,
  is_read                  BOOLEAN NOT NULL DEFAULT false,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications"
  ON public.app_notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications"
  ON public.app_notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.leave_audit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  leave_request_id UUID NOT NULL REFERENCES public.leave_requests(id) ON DELETE CASCADE,
  action          TEXT NOT NULL,
  from_status     TEXT,
  to_status       TEXT,
  comment         TEXT,
  actor_user_id   UUID REFERENCES public.users(id) ON DELETE SET NULL,
  actor_name      TEXT NOT NULL DEFAULT 'System',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.leave_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leave audit visible to owner or admin"
  ON public.leave_audit_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.leave_requests lr
      WHERE lr.id = leave_request_id
        AND (
          lr.user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role = 'admin'
          )
        )
    )
  );

CREATE OR REPLACE FUNCTION public.notify_new_leave_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_name text := COALESCE(
    NULLIF((SELECT u.name FROM public.users u WHERE u.id = NEW.user_id), ''),
    NULLIF((SELECT u.username FROM public.users u WHERE u.id = NEW.user_id), ''),
    'Employee'
  );
BEGIN
  INSERT INTO public.leave_audit_logs (
    leave_request_id,
    action,
    to_status,
    actor_user_id,
    actor_name,
    comment
  )
  VALUES (
    NEW.id,
    'submitted',
    NEW.status,
    NEW.user_id,
    v_actor_name,
    NEW.reason
  );

  INSERT INTO public.app_notifications (
    user_id,
    title,
    body,
    type,
    related_leave_request_id
  )
  SELECT
    u.id,
    'New leave request',
    v_actor_name || ' submitted ' || initcap(NEW.leave_type) || ' leave.',
    'leave_submitted',
    NEW.id
  FROM public.users u
  WHERE u.role = 'admin';

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.audit_leave_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_actor_name text := COALESCE(
    NULLIF((SELECT u.name FROM public.users u WHERE u.id = v_actor_id), ''),
    NULLIF((SELECT u.username FROM public.users u WHERE u.id = v_actor_id), ''),
    'Admin'
  );
  v_action text := 'updated';
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status
     AND NEW.admin_comment IS NOT DISTINCT FROM OLD.admin_comment THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    v_action := CASE
      WHEN NEW.status = 'approved' THEN 'approved'
      WHEN NEW.status = 'rejected' THEN 'rejected'
      ELSE 'status_updated'
    END;
  ELSIF NEW.admin_comment IS DISTINCT FROM OLD.admin_comment THEN
    v_action := 'comment_updated';
  END IF;

  INSERT INTO public.leave_audit_logs (
    leave_request_id,
    action,
    from_status,
    to_status,
    comment,
    actor_user_id,
    actor_name
  )
  VALUES (
    NEW.id,
    v_action,
    OLD.status,
    NEW.status,
    NEW.admin_comment,
    v_actor_id,
    v_actor_name
  );

  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status IN ('approved', 'rejected') THEN
    INSERT INTO public.app_notifications (
      user_id,
      title,
      body,
      type,
      related_leave_request_id
    )
    VALUES (
      NEW.user_id,
      CASE
        WHEN NEW.status = 'approved' THEN 'Leave approved'
        ELSE 'Leave rejected'
      END,
      CASE
        WHEN COALESCE(NEW.admin_comment, '') = '' THEN
          'Your ' || initcap(NEW.leave_type) || ' leave request was ' || NEW.status || '.'
        ELSE
          'Your ' || initcap(NEW.leave_type) || ' leave request was ' || NEW.status || ': ' || NEW.admin_comment
      END,
      'leave_status',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_leave_submitted_notify
  AFTER INSERT ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_leave_request();

CREATE OR REPLACE TRIGGER trg_leave_audit_status
  AFTER UPDATE ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_leave_status_change();

CREATE OR REPLACE FUNCTION public.approve_leave_and_clear_attendance(
  p_leave_id UUID,
  p_admin_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_leave public.leave_requests%ROWTYPE;
  v_removed_count INTEGER := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = v_actor_id
      AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve leave';
  END IF;

  SELECT *
  INTO v_leave
  FROM public.leave_requests
  WHERE id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF v_leave.status = 'approved' THEN
    RETURN jsonb_build_object(
      'attendance_removed_count', 0,
      'leave_id', v_leave.id,
      'status', v_leave.status
    );
  END IF;

  IF v_leave.status = 'rejected' THEN
    RAISE EXCEPTION 'Rejected leave cannot be approved directly';
  END IF;

  UPDATE public.leave_requests
  SET status = 'approved',
      admin_comment = p_admin_comment
  WHERE id = v_leave.id;

  DELETE FROM public.attendance
  WHERE user_id = v_leave.user_id
    AND date >= v_leave.start_date
    AND date <= v_leave.end_date;

  GET DIAGNOSTICS v_removed_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'attendance_removed_count', v_removed_count,
    'leave_id', v_leave.id,
    'status', 'approved'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_leave_and_clear_attendance(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_leave_and_clear_attendance(UUID, TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.clock_in_if_allowed(
  p_user_id UUID,
  p_location TEXT DEFAULT NULL
)
RETURNS public.attendance
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
  v_today DATE := timezone('Asia/Kuala_Lumpur', now())::date;
  v_record public.attendance%ROWTYPE;
BEGIN
  IF v_actor_id IS DISTINCT FROM p_user_id
     AND NOT EXISTS (
       SELECT 1 FROM public.users u
       WHERE u.id = v_actor_id AND u.role = 'admin'
     ) THEN
    RAISE EXCEPTION 'Not allowed to clock in for this user';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.leave_requests lr
    WHERE lr.user_id = p_user_id
      AND lr.status = 'approved'
      AND lr.start_date <= v_today
      AND lr.end_date >= v_today
  ) THEN
    RAISE EXCEPTION 'Approved leave already covers today';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.attendance a
    WHERE a.user_id = p_user_id
      AND a.date = v_today
  ) THEN
    RAISE EXCEPTION 'Attendance already exists for today';
  END IF;

  INSERT INTO public.attendance (
    user_id,
    clock_in_time,
    date,
    status,
    location
  )
  VALUES (
    p_user_id,
    now(),
    v_today,
    'in_progress',
    p_location
  )
  RETURNING * INTO v_record;

  RETURN v_record;
END;
$$;

REVOKE ALL ON FUNCTION public.clock_in_if_allowed(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.clock_in_if_allowed(UUID, TEXT) TO authenticated;


-- ============================================================
-- REALTIME (mobile app listens for live updates)
-- Run once. If a table is already in the publication, Postgres errors — safe to ignore.
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance;
ALTER PUBLICATION supabase_realtime ADD TABLE public.leave_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;

-- Alternative: Dashboard → Database → Publications → supabase_realtime → add tables.


-- ============================================================
-- SEED: Create a test admin user (run AFTER signing up via app)
-- Replace 'YOUR_ADMIN_USER_UUID' with the actual auth user id
-- ============================================================
-- UPDATE public.users SET role = 'admin' WHERE id = 'YOUR_ADMIN_USER_UUID';
