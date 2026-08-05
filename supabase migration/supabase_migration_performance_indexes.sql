-- Performance indexes for existing app queries. Run in Supabase SQL Editor.
-- These do not change app behavior; they speed up filters, ordering, and joins.

CREATE INDEX IF NOT EXISTS idx_users_role_name
  ON public.users (role, name);

CREATE INDEX IF NOT EXISTS idx_attendance_user_date
  ON public.attendance (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_date_clock_in
  ON public.attendance (date DESC, clock_in_time);

CREATE INDEX IF NOT EXISTS idx_leave_requests_user_status_dates
  ON public.leave_requests (user_id, status, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_leave_requests_status_dates
  ON public.leave_requests (status, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_leave_requests_created_at
  ON public.leave_requests (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_expense_claims_user_created_at
  ON public.expense_claims (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_expense_claims_created_at
  ON public.expense_claims (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_claim_attachments_claim_created_at
  ON public.claim_attachments (claim_id, created_at);

CREATE INDEX IF NOT EXISTS idx_app_notifications_user_read_created
  ON public.app_notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_company_announcements_created_at
  ON public.company_announcements (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payroll_salary_settings_updated_at
  ON public.payroll_salary_settings (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_payroll_items_run_employee
  ON public.payroll_items (payroll_run_id, employee_name_snapshot);

CREATE INDEX IF NOT EXISTS idx_payroll_items_user_updated_at
  ON public.payroll_items (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_payroll_runs_period
  ON public.payroll_runs (period_year DESC, period_month DESC);

CREATE INDEX IF NOT EXISTS idx_leave_audit_logs_request_created_at
  ON public.leave_audit_logs (leave_request_id, created_at DESC);
