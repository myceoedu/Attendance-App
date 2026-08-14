# Developer overview

This document is for a **new developer** taking over myRekod.

---

## What you are inheriting

| Item | Detail |
|------|--------|
| Product | myRekod — attendance, leave, claims, payroll, announcements, location required to clock in (if open) |
| Client | Flutter app (`attendance_app`(FILE)) |
| Backend | Supabase (Auth, Postgres, Storage, Realtime) |
| Primary UI target | Web (Chrome), also runnable on Android/iOS/desktop | better running on chrome choose(2) after write flutter run in terminal.
| State | Provider (`AuthProvider`) |
| Navigation | Custom `AppRoute` / `pushAppPage` (instant on web) |

---

## Repository layout (important folders)

```text
attendance_app/
  lib/                         Flutter app source
    config/app_config.dart     Supabase URL + anon key defaults / env (ada 2 key saja yang perlu copy dari supabase untk connect dgn supabase)
    constants/                 Theme, help support config
    models/                    Data models
    providers/                 AuthProvider
    screens/                   UI (admin/ + employee/)
    services/                  SupabaseService, payroll, realtime
    utils/                     Routes, time, location(open-location required/ close-location no need), validators
    widgets/                   Shared UI (OSM map, tiles, etc.)
  supabase_bundles/            Ordered SQL for NEW projects
  supabase_migration_*.sql     One-off migrations for EXISTING projects
  UserManual & Guide/          This handover documentation
  pubspec.yaml                 Dependencies
```

---

## Main product areas

1. **Auth** — email/password, username login, password recovery UI
2. **Attendance** — clock in/out, history, admin overview
3. **work location** — one `work_site`, clock-in only
4. **Leave** — apply, approve, attachments, balances
5. **Claims** — MYR expenses + attachments
6. **Payroll** — salary settings, statutory, runs, payslips
7. **Announcements** — company posts + unread badge
8. **Help** — FAQs + support phone

---

## Roles

Stored in `public.users.role`:

- `employee` → `EmployeeShell`
- `admin` → `AdminShell`

Promote an admin in SQL: CARA SET USER JADI ADMIN (SUPABASE-SQL EDITOR-CREATE NEW SNIPPET- PASTE & CLICK RUN)

```sql
UPDATE public.users
SET role = 'admin'
WHERE email = 'someone@gmail.com';
```

---

## Documentation map for developers

| File | Purpose |
|------|---------|
| [01_setup_and_run.md](01_setup_and_run.md) | Install, run, env |
| [02_supabase_and_database.md](02_supabase_and_database.md) | SQL bundles & migrations |
| [03_architecture.md](03_architecture.md) | App structure & patterns |
| [04_features_and_key_files.md](04_features_and_key_files.md) | Where each feature lives |
| [05_deploy_and_auth.md](05_deploy_and_auth.md) | Vercel + Auth redirect URLs |
| [06_handover_checklist.md](06_handover_checklist.md) | Day-1 checklist |
| [SAMBUNGAN FILE] |

Also read user docs under `UserManual&Guide/user/` so you understand the product.

---

## Related SQL docs

- Bundle guide: [`supabase_bundles/README.md`](../../supabase_bundles/README.md)
- Work site migration: [`supabase_migration_work_site_geofence.sql`](../../supabase_migration_work_site_geofence.sql)
