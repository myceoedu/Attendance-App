-- Allow an employee to delete files on their own pending claim.
-- Needed so deleting a pending claim can cascade attachment rows.
-- Run in Supabase SQL Editor (existing projects).

DROP POLICY IF EXISTS "claim_attachments_delete_own_pending" ON public.claim_attachments;
CREATE POLICY "claim_attachments_delete_own_pending"
  ON public.claim_attachments FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.expense_claims c
      WHERE c.id = claim_id
        AND c.user_id = auth.uid()
        AND c.status = 'pending'
    )
  );
