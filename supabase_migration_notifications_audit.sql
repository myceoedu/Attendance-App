-- ============================================================
-- MIGRATION: notifications inbox + leave audit logs
-- Run in Supabase SQL Editor (existing projects).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_notifications (
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

DROP POLICY IF EXISTS "Users read own notifications" ON public.app_notifications;
DROP POLICY IF EXISTS "Users update own notifications" ON public.app_notifications;

CREATE POLICY "Users read own notifications"
  ON public.app_notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications"
  ON public.app_notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.leave_audit_logs (
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

DROP POLICY IF EXISTS "Leave audit visible to owner or admin" ON public.leave_audit_logs;

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

DROP TRIGGER IF EXISTS trg_leave_submitted_notify ON public.leave_requests;
DROP TRIGGER IF EXISTS trg_leave_audit_status ON public.leave_requests;
DROP FUNCTION IF EXISTS public.notify_new_leave_request();
DROP FUNCTION IF EXISTS public.audit_leave_status_change();

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

CREATE TRIGGER trg_leave_submitted_notify
  AFTER INSERT ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_new_leave_request();

CREATE TRIGGER trg_leave_audit_status
  AFTER UPDATE ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_leave_status_change();

-- Allow admins to delete attendance rows (needed for leave-approval cleanup).
DROP POLICY IF EXISTS "Admins delete attendance" ON public.attendance;
CREATE POLICY "Admins delete attendance"
  ON public.attendance FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

DROP FUNCTION IF EXISTS public.approve_leave_and_clear_attendance(UUID, TEXT);
DROP FUNCTION IF EXISTS public.clock_in_if_allowed(UUID, TEXT);

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

ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
