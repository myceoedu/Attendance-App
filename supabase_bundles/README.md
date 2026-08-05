# Supabase setup bundles (new project)

Use these when creating a **new** Supabase project.  
Original `supabase_setup.sql` / `supabase_migration_*.sql` files stay in the repo root unchanged.

Bundles follow the **same schema** as the existing app migrations (no new tables/features).

## How to run

1. Open **Supabase Dashboard → SQL Editor**
2. Run each file below **in order** (1 → 7)
3. Wait for success before the next file
4. Skip `08_...OPTIONAL` unless you want fake payroll test rows

| Step | File | Feature |
|------|------|---------|
| 1 | `01_core_setup.sql` | Base tables, RLS, triggers, realtime |
| 2 | `02_auth_and_users.sql` | Username login (flexible names like `AHMAD FAIZ`), profile fields, admin user RLS |
| 3 | `03_leave.sql` | Leave attachments, notifications, audit, annual leave, leave types |
| 4 | `04_announcements.sql` | Company announcements |
| 5 | `05_claims.sql` | Expense claims + attachments storage |
| 6 | `06_payroll.sql` | Full payroll schema + RLS fixes |
| 7 | `07_indexes.sql` | Performance indexes |
| 8 | `09_work_site.sql` | One-site clock-in geofence (`work_site`) |
| Optional | `08_seed_payroll_test_data_OPTIONAL.sql` | Test seed data only |

Existing projects: run root file `supabase_migration_work_site_geofence.sql` once.

## If you already ran 01 + 02

Re-run the **updated** `03_leave.sql` (whole file).  
It is safe to re-run: overlapping pieces use `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE`, and realtime publication adds are **idempotent** (no more `42710` duplicate member error).

Then continue with `04` → `07`.

## After SQL

1. **Project settings → API** — copy Project URL + `anon` key into the Flutter app (`lib/config/app_config.dart` or `--dart-define`)
2. **Authentication** — enable Email provider; set Site URL / redirect URLs.
   For password reset, allow your app origin(s), e.g.
   `http://localhost:**` / `https://attendance-app-peach-rho.vercel.app/**`
   (reset emails use `?passwordReset=1` on that origin).
3. **Storage** — confirm buckets `leave-attachments` and `claim-attachments` exist
4. Register a user in the app, then promote an admin:

```sql
UPDATE public.users
SET role = 'admin'
WHERE email = 'your-admin@email.com';
```

## Notes

- Prefer an **empty** project for first-time setup.
- Do **not** use the optional seed on a real production company database.
- you need to run database file (01 - 09 except 08) if you create new supabase account.