-- Optional: speeds up employee attendance log + leave history pagination.
-- Run in Supabase SQL editor if not already present.

CREATE INDEX IF NOT EXISTS idx_attendance_user_date_id_desc
  ON attendance (user_id, date DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_user_date_asc
  ON attendance (user_id, date ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_leave_requests_user_created_desc
  ON leave_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_leave_requests_user_status_created_desc
  ON leave_requests (user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_leave_requests_overlap_approved
  ON leave_requests (user_id, status, start_date, end_date);
