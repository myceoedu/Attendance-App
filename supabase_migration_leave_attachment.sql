-- ============================================================
-- MIGRATION: leave_requests.attachment_path + Storage bucket
-- Run in Supabase SQL Editor (existing projects only).
-- ============================================================

ALTER TABLE public.leave_requests
  ADD COLUMN IF NOT EXISTS attachment_path text;

INSERT INTO storage.buckets (id, name, public)
VALUES ('leave-attachments', 'leave-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Policies may already exist — drop if you need to re-run.
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
