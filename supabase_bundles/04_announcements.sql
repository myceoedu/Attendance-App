-- ============================================================
-- BUNDLE 4 — Company announcements
-- Bundle for NEW Supabase project setup
-- Run order step: 4 of 7
-- Source files (in order):
--   - supabase_migration_company_announcements.sql
-- Idempotent where possible (safe to re-run after a partial failure).
-- ============================================================


-- ------------------------------------------------------------
-- BEGIN: supabase_migration_company_announcements.sql
-- ------------------------------------------------------------

-- Company-wide announcements (authored by admins; visible to all authenticated users).
-- Run in Supabase SQL Editor. Ensures Realtime can stream inserts if you use the app subscriber.

CREATE TABLE IF NOT EXISTS public.company_announcements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title      TEXT NOT NULL DEFAULT '',
  body       TEXT NOT NULL DEFAULT '',
  created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT company_announcements_title_not_empty CHECK (length(trim(title)) > 0)
);

CREATE INDEX IF NOT EXISTS company_announcements_created_at_idx
  ON public.company_announcements (created_at DESC);

ALTER TABLE public.company_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users read announcements"
  ON public.company_announcements;
DROP POLICY IF EXISTS "Admins insert announcements"
  ON public.company_announcements;
DROP POLICY IF EXISTS "Admins delete announcements"
  ON public.company_announcements;

CREATE POLICY "Authenticated users read announcements"
  ON public.company_announcements
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins insert announcements"
  ON public.company_announcements
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
    AND created_by = auth.uid()
  );

CREATE POLICY "Admins delete announcements"
  ON public.company_announcements
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

-- Optional: enable Realtime for live updates (Dashboard â†’ Database â†’ Publications,
-- or run once if not already present):
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.company_announcements;
-- so that the app can listen for live updates and display the new announcements.
-- run in supabase sql editor.
-- what is the command to run this file?

-- ------------------------------------------------------------
-- END: supabase_migration_company_announcements.sql
-- ------------------------------------------------------------

