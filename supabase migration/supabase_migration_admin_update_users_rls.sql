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
