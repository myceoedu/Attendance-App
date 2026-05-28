-- ============================================================
-- Fix: infinite recursion detected in policy for "payroll_runs"
-- (PostgreSQL 42P17)
--
-- Cause: employee SELECT policies cross-reference payroll_runs
-- and payroll_items. Each RLS check re-enters the other table's
-- policies → loop.
--
-- Run in Supabase SQL Editor after payroll module + employee RLS.
-- ============================================================

-- Status lookup without re-entering RLS on payroll_runs
CREATE OR REPLACE FUNCTION public.payroll_run_status_for_rls(p_run_id uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT status::text FROM public.payroll_runs WHERE id = p_run_id LIMIT 1;
$$;

-- Row existence on payroll_items without re-entering RLS on payroll_items
CREATE OR REPLACE FUNCTION public.user_has_payroll_item_for_rls(
  p_run_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.payroll_items pi
    WHERE pi.payroll_run_id = p_run_id AND pi.user_id = p_user_id
  );
$$;

REVOKE ALL ON FUNCTION public.payroll_run_status_for_rls(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.user_has_payroll_item_for_rls(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.payroll_run_status_for_rls(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_payroll_item_for_rls(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS payroll_items_employee_select_own ON public.payroll_items;
CREATE POLICY payroll_items_employee_select_own
  ON public.payroll_items FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND public.payroll_run_status_for_rls(payroll_run_id) IN ('approved', 'paid')
  );

DROP POLICY IF EXISTS payroll_runs_employee_select_own ON public.payroll_runs;
CREATE POLICY payroll_runs_employee_select_own
  ON public.payroll_runs FOR SELECT
  TO authenticated
  USING (
    status IN ('approved', 'paid')
    AND public.user_has_payroll_item_for_rls(id, auth.uid())
  );
