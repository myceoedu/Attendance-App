# Supabase and database

This page explains how the backend is set up.

---

## Where SQL lives

| Location | Use when |
|----------|----------|
| `supabase bundles/` | Supabase project (run in order) - COPY YANG NI PON DAH OKAY FROM (01-LATEST)
| `supabase migration` | **Existing** project feature patches |

Always read:

- [`supabase_bundles/README.md`](../../supabase_bundles/README.md)

---

## New project — run order

In Supabase → **SQL Editor**, run:

| Step | File |
|------|------|
| 1 | `01_core_setup.sql` |
| 2 | `02_auth_and_users.sql` |
| 3 | `03_leave.sql` |
| 4 | `04_announcements.sql` |
| 5 | `05_claims.sql` |
| 6 | `06_payroll.sql` |
| 7 | `07_indexes.sql` |
| 8 | `09_work_site.sql` (WORK LOCATION) |
| Optional | `08_seed_payroll_test_data_OPTIONAL.sql` |

#MAKE SURE RUNNING SUCCESS SEBELUM RUNNING NEXT FILE#

---

## Auth essentials

### Email provider

Supabase → Authentication → Providers → Email CONFIRM -> enabled.

### URL configuration

Supabase → Authentication → URL configuration:

- **Site URL** = production app URL  (LICK WEB/APP YG KITA RUNNING)-DOMAIN
  Example: `https://attendance-app-peach-rho.vercel.app`
- **Redirect URLs** must include:
  - Production `https://your-app.vercel.app/**`
  - Local `http://localhost:PORT/**` and/or `http://127.0.0.1:PORT/**`

Password reset emails use `redirectTo` with `?passwordReset=1`  
(see `lib/utils/auth_redirect.dart`).

### Confirm email

For testing, many teams disable “Confirm email”.  
For production, decide with the client and test the full flow.

*CLOSE CONFIRM EMAIL KALAU NAK REGISTER RAMAI USER IF GUNA SUPABASE YANG FREE NOT PRO VERSION*
---

## Core tables (high level)

| Table / area | Purpose |
|--------------|---------|
| `auth.users` | Supabase Auth accounts |
| `public.users` | App profile (role, username, HR fields) |
| `attendance` | Clock records |
| `leave_requests` (+ attachments) | Leave |
| `expense_claims` (+ attachments) | Claims |
| Payroll tables | Runs, items, salary, statutory |
| `company_announcements` | News |
| `work_site` | Singleton geofence (id = 1) |
| `app_notifications` | In-app notifications |

---

## Important RPCs / triggers

| Name | Purpose |
|------|---------|
| `handle_new_user` | Creates `public.users` row on signup (needs username metadata) |
| `get_email_for_login` | Username → email for login |
| `is_username_available` | Username check |
| `clock_in_if_allowed` | Clock-in with leave + geofence checks |
| `distance_meters` | Haversine helper for geofence |

---

## Storage buckets

Confirm these exist:

- `leave-attachments`
- `claim-attachments`

Created by claims/leave SQL bundles (or manually if missing).

---

## Promote admin

```sql
UPDATE public.users
SET role = 'admin'
WHERE email = 'ADMIN-EMAIL@gmail.com';
```

---

## Geofence notes for developers

- Table: `public.work_site` singleton (`id = 1`)
- When `is_active = true`, clock-in requires `location` as `"lat,lng"`
- Server rejects out-of-range punches even if the client is bypassed
- Admin UI: `lib/screens/admin/admin_work_site_screen.dart`
- Map picker: OpenStreetMap via `flutter_map`

---

## Next

- [Architecture](03_architecture.md)
- [Features and key files](04_features_and_key_files.md)
