-- ============================================================
-- MIGRATION: Expense claims + attachments + Storage bucket
-- Run in Supabase SQL Editor after core setup.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.expense_claims (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT NOT NULL DEFAULT '',
  category      TEXT NOT NULL DEFAULT 'other' CHECK (category IN (
    'meal', 'transport', 'accommodation', 'supplies', 'medical',
    'communications', 'training', 'client_entertainment', 'other'
  )),
  amount        NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  currency      TEXT NOT NULL DEFAULT 'MYR',
  expense_date  DATE NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_comment TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.claim_attachments (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id       UUID NOT NULL REFERENCES public.expense_claims(id) ON DELETE CASCADE,
  storage_path   TEXT NOT NULL,
  original_name  TEXT NOT NULL DEFAULT '',
  byte_size      BIGINT,
  content_type   TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (claim_id, storage_path)
);

CREATE INDEX IF NOT EXISTS expense_claims_user_id_idx ON public.expense_claims (user_id);
CREATE INDEX IF NOT EXISTS expense_claims_status_idx ON public.expense_claims (status);
CREATE INDEX IF NOT EXISTS expense_claims_created_at_idx ON public.expense_claims (created_at DESC);
CREATE INDEX IF NOT EXISTS claim_attachments_claim_id_idx ON public.claim_attachments (claim_id);

ALTER TABLE public.expense_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claim_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "expense_claims_select_own_or_admin" ON public.expense_claims;
CREATE POLICY "expense_claims_select_own_or_admin"
  ON public.expense_claims FOR SELECT TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

DROP POLICY IF EXISTS "expense_claims_insert_own" ON public.expense_claims;
CREATE POLICY "expense_claims_insert_own"
  ON public.expense_claims FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "expense_claims_update_admin" ON public.expense_claims;
CREATE POLICY "expense_claims_update_admin"
  ON public.expense_claims FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
  );

-- Employee may delete a **pending** claim they own (used if upload fails mid-submit).
DROP POLICY IF EXISTS "expense_claims_delete_own_pending" ON public.expense_claims;
CREATE POLICY "expense_claims_delete_own_pending"
  ON public.expense_claims FOR DELETE TO authenticated
  USING (auth.uid() = user_id AND status = 'pending');

DROP POLICY IF EXISTS "claim_attachments_select_via_claim" ON public.claim_attachments;
CREATE POLICY "claim_attachments_select_via_claim"
  ON public.claim_attachments FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.expense_claims c
      WHERE c.id = claim_id
        AND (
          c.user_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
        )
    )
  );

DROP POLICY IF EXISTS "claim_attachments_insert_own_pending" ON public.claim_attachments;
CREATE POLICY "claim_attachments_insert_own_pending"
  ON public.claim_attachments FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.expense_claims c
      WHERE c.id = claim_id
        AND c.user_id = auth.uid()
        AND c.status = 'pending'
    )
  );

-- Storage: private bucket; paths are {user_id}/{claim_id}/{filename}
INSERT INTO storage.buckets (id, name, public)
VALUES ('claim-attachments', 'claim-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "claim_attachments_storage_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "claim_attachments_storage_select_own_or_admin" ON storage.objects;

CREATE POLICY "claim_attachments_storage_insert_own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'claim-attachments'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

CREATE POLICY "claim_attachments_storage_select_own_or_admin"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'claim-attachments'
    AND (
      split_part(name, '/', 1) = auth.uid()::text
      OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
    )
  );

DROP POLICY IF EXISTS "claim_attachments_storage_delete_own" ON storage.objects;
CREATE POLICY "claim_attachments_storage_delete_own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'claim-attachments'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

-- If the table is already in the publication, this errors — safe to ignore.
ALTER PUBLICATION supabase_realtime ADD TABLE public.expense_claims;
ALTER PUBLICATION supabase_realtime ADD TABLE public.claim_attachments;
