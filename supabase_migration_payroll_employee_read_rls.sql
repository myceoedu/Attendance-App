-- ============================================================
-- Employee read access to own payslips (approved / paid runs only)
-- Run in Supabase SQL after supabase_migration_payroll_module.sql
-- ============================================================

-- Employees can SELECT their own payroll line items when the parent run
-- is approved or paid (draft/calculated remain HR-only).
DROP POLICY IF EXISTS payroll_items_employee_select_own ON public.payroll_items;
CREATE POLICY payroll_items_employee_select_own
  ON public.payroll_items FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.payroll_runs pr
      WHERE pr.id = payroll_items.payroll_run_id
        AND pr.status IN ('approved', 'paid')
    )
  );

-- Employees can SELECT payroll run headers for runs where they have a line
-- (same approved/paid gate).
DROP POLICY IF EXISTS payroll_runs_employee_select_own ON public.payroll_runs;
CREATE POLICY payroll_runs_employee_select_own
  ON public.payroll_runs FOR SELECT
  TO authenticated
  USING (
    status IN ('approved', 'paid')
    AND EXISTS (
      SELECT 1
      FROM public.payroll_items pi
      WHERE pi.payroll_run_id = payroll_runs.id
        AND pi.user_id = auth.uid()
    )
  );
