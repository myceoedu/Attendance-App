-- Employee can delete their own pending leave (wrong MC or details).
-- Approved / rejected leave stays on file.
-- Run in Supabase SQL Editor (existing projects).

DROP POLICY IF EXISTS "Employees delete own pending leave requests"
  ON public.leave_requests;
CREATE POLICY "Employees delete own pending leave requests"
  ON public.leave_requests FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    AND status = 'pending'
  );

DROP POLICY IF EXISTS "leave_attachments_delete_own_folder" ON storage.objects;
CREATE POLICY "leave_attachments_delete_own_folder"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'leave-attachments'
    AND split_part(name, '/', 1) = auth.uid()::text
  );
