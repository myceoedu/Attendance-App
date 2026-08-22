-- ============================================================
-- SEED: today only — 22 August 2026, morning half day 09:00–13:00
-- Run in Supabase → SQL Editor.
--
-- Edit the email list: keep ONLY staff who came today.
-- Delete any email who did not come. Do not leave a trailing comma
-- after the last email.
--
-- Clock in 09:00, clock out 13:00 (Malaysia, +08) → half day AM.
-- Safe to re-run for the same emails (deletes today's row first).
-- ============================================================

DO $$
DECLARE
  v_day       date := DATE '2026-08-22';
  v_listed    int;
  v_matched   int;
  v_deleted   int;
  v_inserted  int;
BEGIN
  CREATE TEMP TABLE tmp_today_emails (
    email text PRIMARY KEY
  ) ON COMMIT DROP;

  -- >>> KEEP ONLY PEOPLE WHO CAME TODAY <<<
  INSERT INTO tmp_today_emails (email) VALUES
    ('syakilarzb@gmail.com'),
    ('shahririskandar26@gmail.com'),
    ('qurrotuamni96@gmail.com'),
    ('nurfatihahariffin07@gmail.com'),
    ('faizahmadadam@gmail.com'),
    ('angududn04@gmail.com'),
    ('aisyahnurain1401@gmail.com'),
    ('aishah.myceoedu@gmail.com');

  SELECT COUNT(*) INTO v_listed FROM tmp_today_emails;

  SELECT COUNT(*) INTO v_matched
  FROM tmp_today_emails e
  JOIN public.users u ON lower(trim(u.email)) = lower(e.email);

  IF v_matched < v_listed THEN
    RAISE EXCEPTION
      'Some emails were not found in public.users (listed %, matched %). Fix the list and re-run.',
      v_listed,
      v_matched;
  END IF;

  DELETE FROM public.attendance a
  USING public.users u, tmp_today_emails e
  WHERE a.user_id = u.id
    AND lower(trim(u.email)) = lower(e.email)
    AND a.date = v_day;
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
    (to_char(v_day, 'YYYY-MM-DD') || ' 09:00:00+08')::timestamptz,
    (to_char(v_day, 'YYYY-MM-DD') || ' 13:00:00+08')::timestamptz,
    v_day,
    'completed',
    'Office'
  FROM tmp_today_emails e
  JOIN public.users u
    ON lower(trim(u.email)) = lower(e.email)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.leave_requests lr
    WHERE lr.user_id = u.id
      AND lr.status = 'approved'
      AND v_day BETWEEN lr.start_date AND lr.end_date
  );
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RAISE NOTICE 'Today %. Matched % email(s). Deleted % old row(s). Inserted % half-day (09:00–13:00) row(s).',
    v_day, v_matched, v_deleted, v_inserted;
END $$;

-- Everyone who has a 22 Aug 2026 attendance row
SELECT
  u.email,
  u.name,
  a.date,
  a.clock_in_time AT TIME ZONE 'Asia/Kuala_Lumpur' AS clock_in_my,
  a.clock_out_time AT TIME ZONE 'Asia/Kuala_Lumpur' AS clock_out_my,
  a.status
FROM public.attendance a
JOIN public.users u ON u.id = a.user_id
WHERE a.date = DATE '2026-08-22'
ORDER BY u.email;
