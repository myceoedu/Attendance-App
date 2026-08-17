-- Admin monthly attendance notes (per employee / month).
-- Run in Supabase SQL Editor for existing projects.

CREATE TABLE IF NOT EXISTS public.monthly_attendance_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  period_year INT NOT NULL CHECK (period_year >= 2000 AND period_year <= 2100),
  period_month INT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  notes TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  UNIQUE (user_id, period_year, period_month)
);

CREATE INDEX IF NOT EXISTS monthly_attendance_notes_period_idx
  ON public.monthly_attendance_notes (period_year, period_month);

ALTER TABLE public.monthly_attendance_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read monthly attendance notes"
  ON public.monthly_attendance_notes;
CREATE POLICY "Admins read monthly attendance notes"
  ON public.monthly_attendance_notes FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins insert monthly attendance notes"
  ON public.monthly_attendance_notes;
CREATE POLICY "Admins insert monthly attendance notes"
  ON public.monthly_attendance_notes FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins update monthly attendance notes"
  ON public.monthly_attendance_notes;
CREATE POLICY "Admins update monthly attendance notes"
  ON public.monthly_attendance_notes FOR UPDATE TO authenticated
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

DROP POLICY IF EXISTS "Admins delete monthly attendance notes"
  ON public.monthly_attendance_notes;
CREATE POLICY "Admins delete monthly attendance notes"
  ON public.monthly_attendance_notes FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );
