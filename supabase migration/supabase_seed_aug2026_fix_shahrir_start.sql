-- ============================================================
-- One-off fix: shahririskandar26@gmail.com starts 11 August 2026
-- Run in Supabase → SQL Editor if you already seeded Aug 1–21.
--
-- Deletes that user's attendance before 11 Aug 2026
-- (in the 1–21 Aug seed window). Saturday/Sunday were never inserted.
-- Weekdays removed: 3, 4, 5, 6, 7, 10 August 2026.
-- ============================================================

DELETE FROM public.attendance a
USING public.users u
WHERE a.user_id = u.id
  AND lower(trim(u.email)) = 'shahririskandar26@gmail.com'
  AND a.date >= DATE '2026-08-01'
  AND a.date <  DATE '2026-08-11';

-- Check: first day should be 2026-08-11
SELECT
  u.email,
  u.name,
  a.date,
  a.status,
  a.clock_in_time,
  a.clock_out_time
FROM public.attendance a
JOIN public.users u ON u.id = a.user_id
WHERE lower(trim(u.email)) = 'shahririskandar26@gmail.com'
  AND a.date BETWEEN DATE '2026-08-01' AND DATE '2026-08-21'
ORDER BY a.date;
