-- ============================================================
-- SEED: weekday attendance 1–21 August 2026 for named staff
-- Run in Supabase Dashboard → SQL Editor (copy this whole file).
--
-- Does NOT insert Saturday or Sunday.
-- Clock in 09:00, clock out 18:00 (Malaysia, +08). Status: completed.
-- Skips a weekday if that person already has approved leave that day.
-- Safe to re-run: deletes 1–21 Aug 2026 attendance for these emails first,
-- then inserts again.
--
-- Workdays created (unless leave skipped a day):
--   Most staff: 3–7, 10–14, 17–21 August 2026 (15 days)
--   shahririskandar26@gmail.com: from 11 August only (11–14, 17–21 = 9 days)
-- ============================================================

-- Preview emails (optional): run this SELECT alone first if you want.
-- SELECT e.email, u.id, u.name,
--        CASE WHEN u.id IS NULL THEN 'NOT FOUND' ELSE 'OK' END AS match
-- FROM (VALUES
--   ('syakilarzb@gmail.com'),
--   ('shahririskandar26@gmail.com'),
--   ('qurrotuamni96@gmail.com'),
--   ('nurfatihahariffin07@gmail.com'),
--   ('faizahmadadam@gmail.com'),
--   ('angududn04@gmail.com'),
--   ('aisyahnurain1401@gmail.com'),
--   ('aishah.myceoedu@gmail.com')
-- ) AS e(email)
-- LEFT JOIN public.users u ON lower(trim(u.email)) = lower(trim(e.email));

DO $$
DECLARE
  v_start     date := DATE '2026-08-01';
  v_end       date := DATE '2026-08-21';
  v_expected  int  := 8;
  v_matched   int;
  v_deleted   int;
  v_inserted  int;
BEGIN
  CREATE TEMP TABLE tmp_seed_emails (
    email      text PRIMARY KEY,
    start_date date NOT NULL
  ) ON COMMIT DROP;

  INSERT INTO tmp_seed_emails (email, start_date) VALUES
    ('syakilarzb@gmail.com',            DATE '2026-08-01'),
    ('shahririskandar26@gmail.com',     DATE '2026-08-11'),
    ('qurrotuamni96@gmail.com',         DATE '2026-08-01'),
    ('nurfatihahariffin07@gmail.com',   DATE '2026-08-01'),
    ('faizahmadadam@gmail.com',         DATE '2026-08-01'),
    ('angududn04@gmail.com',            DATE '2026-08-01'),
    ('aisyahnurain1401@gmail.com',      DATE '2026-08-01'),
    ('aishah.myceoedu@gmail.com',       DATE '2026-08-01');

  SELECT COUNT(*) INTO v_matched
  FROM tmp_seed_emails e
  JOIN public.users u ON lower(trim(u.email)) = lower(e.email);

  IF v_matched < v_expected THEN
    RAISE EXCEPTION
      'Expected % users by email, found %. Fix missing emails in public.users, then re-run.',
      v_expected,
      v_matched;
  END IF;

  DELETE FROM public.attendance a
  USING public.users u, tmp_seed_emails e
  WHERE a.user_id = u.id
    AND lower(trim(u.email)) = lower(e.email)
    AND a.date BETWEEN v_start AND v_end;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO public.attendance (
    user_id,
    clock_in_time,
    clock_out_time,
    date,
    status,
    location
  )
  SELECT
    u.id,
    (to_char(s.d::date, 'YYYY-MM-DD') || ' 09:00:00+08')::timestamptz,
    (to_char(s.d::date, 'YYYY-MM-DD') || ' 18:00:00+08')::timestamptz,
    s.d::date,
    'completed',
    'Office'
  FROM tmp_seed_emails e
  JOIN public.users u
    ON lower(trim(u.email)) = lower(e.email)
  CROSS JOIN generate_series(v_start, v_end, interval '1 day') AS s(d)
  WHERE s.d::date >= e.start_date
    AND EXTRACT(ISODOW FROM s.d) BETWEEN 1 AND 5
    AND NOT EXISTS (
      SELECT 1
      FROM public.leave_requests lr
      WHERE lr.user_id = u.id
        AND lr.status = 'approved'
        AND s.d::date BETWEEN lr.start_date AND lr.end_date
    );
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RAISE NOTICE 'Matched % users. Deleted % old row(s). Inserted % weekday attendance row(s) for % to % (Sat/Sun skipped).',
    v_matched, v_deleted, v_inserted, v_start, v_end;
END $$;

-- Check result after the DO block
SELECT
  u.email,
  u.name,
  COUNT(*) AS weekday_rows,
  MIN(a.date) AS first_day,
  MAX(a.date) AS last_day
FROM public.attendance a
JOIN public.users u ON u.id = a.user_id
WHERE a.date BETWEEN DATE '2026-08-01' AND DATE '2026-08-21'
  AND lower(trim(u.email)) IN (
    'syakilarzb@gmail.com',
    'shahririskandar26@gmail.com',
    'qurrotuamni96@gmail.com',
    'nurfatihahariffin07@gmail.com',
    'faizahmadadam@gmail.com',
    'angududn04@gmail.com',
    'aisyahnurain1401@gmail.com',
    'aishah.myceoedu@gmail.com'
  )
GROUP BY u.email, u.name
ORDER BY u.email;
