-- ============================================================
-- BUNDLE 3 — Leave, notifications & audit
-- Bundle for NEW Supabase project setup
-- Run order step: 3 of 7
-- Source files (in order):
--   - supabase_migration_leave_attachment.sql
--   - supabase_migration_notifications_audit.sql
--   - supabase_migration_annual_leave.sql
--   - supabase_migration_leave_types_expanded.sql
-- Idempotent where possible (safe to re-run after a partial failure).
-- ============================================================


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_leave_attachment.sql
-- ------------------------------------------------------------

-- ============================================================
-- MIGRATION: leave_requests.attachment_path + Storage bucket
-- Run in Supabase SQL Editor (existing projects only).
-- ============================================================

ALTER TABLE public.leave_requests
  ADD COLUMN IF NOT EXISTS attachment_path text;

INSERT INTO storage.buckets (id, name, public)
VALUES ('leave-attachments', 'leave-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Policies may already exist â€” drop if you need to re-run.
DROP POLICY IF EXISTS "leave_attachments_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "leave_attachments_select_own_or_admin" ON storage.objects;

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


-- ------------------------------------------------------------
-- END: supabase_migration_leave_attachment.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_notifications_audit.sql
-- ------------------------------------------------------------

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

-- Idempotent: 01_core / setup may already have added this table.
DO $pub$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_notifications'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications';
  END IF;
END
$pub$;


-- ------------------------------------------------------------
-- END: supabase_migration_notifications_audit.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_annual_leave.sql
-- ------------------------------------------------------------

-- ============================================================
-- MIGRATION: Annual leave entitlement, summaries, approve guard
-- Run in Supabase SQL Editor after core setup / prior migrations.
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS employment_start_date DATE,
  ADD COLUMN IF NOT EXISTS annual_leave_entitlement_override NUMERIC(4, 1);


-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Non-admins cannot change HR-only columns
-- â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
CREATE OR REPLACE FUNCTION public.users_protect_hr_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.employment_start_date IS DISTINCT FROM OLD.employment_start_date
     OR NEW.annual_leave_entitlement_override IS DISTINCT FROM OLD.annual_leave_entitlement_override THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin'
    ) THEN
      RAISE EXCEPTION 'Only admins can edit employment dates or annual leave entitlement override.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_protect_hr_fields ON public.users;
CREATE TRIGGER trg_users_protect_hr_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.users_protect_hr_fields();


CREATE OR REPLACE FUNCTION public.default_annual_entitlement(p_years NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_years IS NULL OR p_years < 2 THEN 8::numeric
    WHEN p_years >= 2 AND p_years <= 5 THEN 12::numeric
    ELSE 16::numeric
  END;
$$;


CREATE OR REPLACE FUNCTION public.annual_leave_overlap_days(
  p_start DATE,
  p_end DATE,
  p_year INTEGER
)
RETURNS INTEGER
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN 0
    ELSE (
      LEAST(p_end, make_date(p_year, 12, 31))
      - GREATEST(p_start, make_date(p_year, 1, 1))
      + 1
    )
  END::integer;
$$;


CREATE OR REPLACE FUNCTION public.user_annual_entitlement_for_year(
  p_user_id UUID,
  p_year INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_override NUMERIC;
  v_created DATE;
  v_emp DATE;
  v_ref DATE;
  v_svc NUMERIC;
BEGIN
  SELECT
    u.annual_leave_entitlement_override,
    (timezone('Asia/Kuala_Lumpur'::text, u.created_at))::date,
    u.employment_start_date
  INTO v_override, v_created, v_emp
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF v_override IS NOT NULL THEN
    RETURN v_override;
  END IF;

  v_ref := COALESCE(v_emp, v_created);
  IF v_ref > make_date(p_year, 12, 31) THEN
    RETURN 0;
  END IF;

  -- Years of service (calendar) as of Dec 31 of [p_year]
  v_svc := EXTRACT(YEAR FROM AGE(make_date(p_year, 12, 31)::timestamp, v_ref::timestamp));

  RETURN public.default_annual_entitlement(v_svc);
END;
$$;


CREATE OR REPLACE FUNCTION public.annual_leave_days_for_requests(
  p_user_id UUID,
  p_year INTEGER,
  p_statuses TEXT[]
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(public.annual_leave_overlap_days(lr.start_date, lr.end_date, p_year)), 0)::numeric
  FROM public.leave_requests lr
  WHERE lr.user_id = p_user_id
    AND lr.leave_type = 'annual'
    AND lr.status = ANY(p_statuses)
    AND lr.start_date <= make_date(p_year, 12, 31)
    AND lr.end_date >= make_date(p_year, 1, 1);
$$;


CREATE OR REPLACE FUNCTION public.get_annual_leave_summary(p_user_id UUID, p_year INTEGER)
RETURNS TABLE (
  entitlement NUMERIC,
  used NUMERIC,
  pending NUMERIC,
  remaining NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_ent NUMERIC;
  v_used NUMERIC;
  v_pend NUMERIC;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_actor <> p_user_id AND NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = v_actor AND u.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not allowed to read this annual leave summary';
  END IF;

  v_ent := public.user_annual_entitlement_for_year(p_user_id, p_year);
  v_used := public.annual_leave_days_for_requests(
    p_user_id, p_year, ARRAY['approved']::TEXT[]
  );
  v_pend := public.annual_leave_days_for_requests(
    p_user_id, p_year, ARRAY['pending']::TEXT[]
  );

  entitlement := v_ent;
  used := v_used;
  pending := v_pend;
  remaining := GREATEST(0::numeric, COALESCE(v_ent, 0) - COALESCE(v_used, 0) - COALESCE(v_pend, 0));

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.get_annual_leave_summary(UUID, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_annual_leave_summary(UUID, INTEGER) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_annual_leave_summaries_batch(
  p_user_ids UUID[],
  p_year INTEGER
)
RETURNS TABLE (
  user_id UUID,
  entitlement NUMERIC,
  used NUMERIC,
  pending NUMERIC,
  remaining NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor UUID := auth.uid();
  uid UUID;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_actor AND u.role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can batch-read annual leave summaries';
  END IF;

  FOREACH uid IN ARRAY p_user_ids
  LOOP
    SELECT
      g.entitlement,
      g.used,
      g.pending,
      g.remaining
    INTO entitlement, used, pending, remaining
    FROM public.get_annual_leave_summary(uid, p_year) AS g;

    user_id := uid;
    RETURN NEXT;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.get_annual_leave_summaries_batch(UUID[], INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_annual_leave_summaries_batch(UUID[], INTEGER) TO authenticated;


CREATE OR REPLACE FUNCTION public.assert_annual_leave_approval_allowed(p_leave_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  lr public.leave_requests%ROWTYPE;
  y_from INTEGER;
  y_to INTEGER;
  v_ent NUMERIC;
  v_used NUMERIC;
  v_other_pend NUMERIC;
  ov INTEGER;
BEGIN
  SELECT *
  INTO lr
  FROM public.leave_requests lr0
  WHERE lr0.id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF lr.leave_type IS DISTINCT FROM 'annual' THEN
    RETURN;
  END IF;

  y_from := EXTRACT(YEAR FROM lr.start_date)::integer;
  y_to := EXTRACT(YEAR FROM lr.end_date)::integer;

  FOR yy IN y_from .. y_to LOOP
    ov := public.annual_leave_overlap_days(lr.start_date, lr.end_date, yy);

    IF ov <= 0 THEN
      CONTINUE;
    END IF;

    v_ent := public.user_annual_entitlement_for_year(lr.user_id, yy);

    v_used := public.annual_leave_days_for_requests(
      lr.user_id, yy, ARRAY['approved']::TEXT[]
    );

    SELECT COALESCE(SUM(public.annual_leave_overlap_days(r.start_date, r.end_date, yy)), 0)
    INTO v_other_pend
    FROM public.leave_requests r
    WHERE r.user_id = lr.user_id
      AND r.leave_type = 'annual'
      AND r.status = 'pending'
      AND r.id <> lr.id
      AND r.start_date <= make_date(yy, 12, 31)
      AND r.end_date >= make_date(yy, 1, 1);

    IF ov::numeric + v_used + COALESCE(v_other_pend, 0) > v_ent THEN
      RAISE EXCEPTION 'annual leave would exceed balance for calendar year %', yy;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) TO authenticated;


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

  PERFORM public.assert_annual_leave_approval_allowed(p_leave_id);

  UPDATE public.leave_requests
  SET status = 'approved',
      admin_comment = COALESCE(p_admin_comment, v_leave.admin_comment)
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


-- ------------------------------------------------------------
-- END: supabase_migration_annual_leave.sql
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_leave_types_expanded.sql
-- ------------------------------------------------------------

-- ============================================================
-- MIGRATION: Expanded leave types + weighted annual (half-days)
-- Run after supabase_setup + supabase_migration_annual_leave.sql
-- ============================================================

ALTER TABLE public.leave_requests
  DROP CONSTRAINT IF EXISTS leave_requests_leave_type_check;

ALTER TABLE public.leave_requests
  ADD CONSTRAINT leave_requests_leave_type_check CHECK (
    leave_type IN (
      'annual',
      'annual_half_am',
      'annual_half_pm',
      'sick',
      'emergency',
      'unpaid',
      'maternity',
      'paternity',
      'marriage',
      'public_holiday'
    )
  );


-- Calendar-year annual â€œchargeâ€: full [annual] uses inclusive calendar days in year;
-- half-day types use 0.5 when the single date falls in [p_year] (start must equal end â€” enforced by trigger).
CREATE OR REPLACE FUNCTION public.annual_leave_credit_in_year(
  p_leave_type TEXT,
  p_start DATE,
  p_end DATE,
  p_year INTEGER
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  overlap_start DATE;
  overlap_end DATE;
BEGIN
  IF p_leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    IF p_start IS DISTINCT FROM p_end THEN
      RETURN 0::numeric;
    END IF;
    IF p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN
      RETURN 0::numeric;
    END IF;
    RETURN 0.5::numeric;
  END IF;

  IF p_leave_type IS DISTINCT FROM 'annual' THEN
    RETURN 0::numeric;
  END IF;

  IF p_end < make_date(p_year, 1, 1) OR p_start > make_date(p_year, 12, 31) THEN
    RETURN 0::numeric;
  END IF;

  overlap_start := GREATEST(p_start, make_date(p_year, 1, 1));
  overlap_end := LEAST(p_end, make_date(p_year, 12, 31));
  IF overlap_end < overlap_start THEN
    RETURN 0::numeric;
  END IF;

  RETURN (overlap_end - overlap_start + 1)::numeric;
END;
$$;


CREATE OR REPLACE FUNCTION public.annual_leave_days_for_requests(
  p_user_id UUID,
  p_year INTEGER,
  p_statuses TEXT[]
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    SUM(
      public.annual_leave_credit_in_year(
        lr.leave_type,
        lr.start_date,
        lr.end_date,
        p_year
      )
    ),
    0
  )::numeric
  FROM public.leave_requests lr
  WHERE lr.user_id = p_user_id
    AND lr.leave_type IN ('annual', 'annual_half_am', 'annual_half_pm')
    AND lr.status = ANY(p_statuses)
    AND lr.start_date <= make_date(p_year, 12, 31)
    AND lr.end_date >= make_date(p_year, 1, 1);
$$;


CREATE OR REPLACE FUNCTION public.assert_annual_leave_approval_allowed(p_leave_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  lr public.leave_requests%ROWTYPE;
  y_from INTEGER;
  y_to INTEGER;
  yy INTEGER;
  v_ent NUMERIC;
  v_used NUMERIC;
  v_other_pend NUMERIC;
  need NUMERIC;
BEGIN
  SELECT *
  INTO lr
  FROM public.leave_requests lr0
  WHERE lr0.id = p_leave_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Leave request not found';
  END IF;

  IF lr.leave_type NOT IN ('annual', 'annual_half_am', 'annual_half_pm') THEN
    RETURN;
  END IF;

  y_from := EXTRACT(YEAR FROM lr.start_date)::integer;
  y_to := EXTRACT(YEAR FROM lr.end_date)::integer;

  FOR yy IN y_from .. y_to LOOP
    need := public.annual_leave_credit_in_year(
      lr.leave_type,
      lr.start_date,
      lr.end_date,
      yy
    );

    IF need <= 0 THEN
      CONTINUE;
    END IF;

    v_ent := public.user_annual_entitlement_for_year(lr.user_id, yy);

    v_used := public.annual_leave_days_for_requests(
      lr.user_id, yy, ARRAY['approved']::TEXT[]
    );

    SELECT COALESCE(
      SUM(
        public.annual_leave_credit_in_year(
          r.leave_type,
          r.start_date,
          r.end_date,
          yy
        )
      ),
      0
    )
    INTO v_other_pend
    FROM public.leave_requests r
    WHERE r.user_id = lr.user_id
      AND r.leave_type IN ('annual', 'annual_half_am', 'annual_half_pm')
      AND r.status = 'pending'
      AND r.id <> lr.id
      AND r.start_date <= make_date(yy, 12, 31)
      AND r.end_date >= make_date(yy, 1, 1);

    IF need + v_used + COALESCE(v_other_pend, 0) > v_ent THEN
      RAISE EXCEPTION 'annual leave would exceed balance for calendar year %', yy;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_annual_leave_approval_allowed(UUID) TO authenticated;


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

  PERFORM public.assert_annual_leave_approval_allowed(p_leave_id);

  UPDATE public.leave_requests
  SET status = 'approved',
      admin_comment = COALESCE(p_admin_comment, v_leave.admin_comment)
  WHERE id = v_leave.id;

  -- Half-day annual: employee may still clock in for the other half â€” do not delete attendance.
  IF v_leave.leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    v_removed_count := 0;
  ELSE
    DELETE FROM public.attendance
    WHERE user_id = v_leave.user_id
      AND date >= v_leave.start_date
      AND date <= v_leave.end_date;

    GET DIAGNOSTICS v_removed_count = ROW_COUNT;
  END IF;

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


CREATE OR REPLACE FUNCTION public.leave_requests_enforce_half_day_dates()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.leave_type IN ('annual_half_am', 'annual_half_pm') THEN
    IF NEW.start_date IS DISTINCT FROM NEW.end_date THEN
      RAISE EXCEPTION 'Half-day annual leave must use a single date (start_date = end_date)';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_leave_requests_half_day_dates ON public.leave_requests;
CREATE TRIGGER trg_leave_requests_half_day_dates
  BEFORE INSERT OR UPDATE OF leave_type, start_date, end_date
  ON public.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.leave_requests_enforce_half_day_dates();


-- ------------------------------------------------------------
-- END: supabase_migration_leave_types_expanded.sql
-- ------------------------------------------------------------

