# myRekod documentation

**Start here** if you are a new **user** or a new **developer** taking over this project.

myRekod is a Flutter HR app for:

- Attendance (clock in / out)
- Leave
- Expense claims
- Payroll / payslips
- Announcements
- Workplace location (geofence for clock-in)

---

## Who should read what?

### I am a staff member (employee)

Read these in order:

1. [Getting started](user/00_getting_started.md)
2. [Employee guide](user/01_employee_guide.md)
3. [Troubleshooting](user/03_troubleshooting.md) — only when something goes wrong

### I am HR / an administrator

Read these in order:

1. [Getting started](user/00_getting_started.md)
2. [Admin guide](user/02_admin_guide.md)
3. [Employee guide](user/01_employee_guide.md) — useful so you know what staff see
4. [Troubleshooting](user/03_troubleshooting.md)

### I am a new developer

Read these in order:

1. [Project overview](developer/00_overview.md)
2. [Setup and run](developer/01_setup_and_run.md)
3. [Supabase and database](developer/02_supabase_and_database.md)
4. [Architecture](developer/03_architecture.md)
5. [Features and key files](developer/04_features_and_key_files.md)
6. [Deploy and auth URLs](developer/05_deploy_and_auth.md)
7. [Handover checklist](developer/06_handover_checklist.md)

Also skim the **user** guides so you understand the product.

---

## Folder map

```text
docs/
  README.md                 ← you are here
  user/                     ← editable User Manual chapters (Markdown)
  developer/                ← editable Developer Handover chapters (Markdown)
  scripts/                  ← creates PDFs from the Markdown chapters
  pdf/                      ← finished PDFs only; share these with readers
```

## Choose the format

| If you want to… | Open |
|-----------------|------|
| Read or update the User Manual in Cursor/Git | [`user/`](user/) |
| Read or update the Developer Handover in Cursor/Git | [`developer/`](developer/) |
| Share or print the User Manual | [myRekod_User_Manual.pdf](pdf/myRekod_User_Manual.pdf) |
| Share or print the Developer Handover | [myRekod_Developer_Handover.pdf](pdf/myRekod_Developer_Handover.pdf) |

The Markdown chapters are the **single source of truth**. PDFs are generated from those chapters, so the PDF folder contains no editable duplicate manual content.

## Refresh the PDFs after editing Markdown

From the project root, run:

```bash
node "docs (UserManual & Guide)/scripts/build-pdf-manuals.mjs"
```

Node.js is required. The command rebuilds both PDFs in `pdf/`.

---

## Support contact (in-app)

| Item | Value |
|------|--------|
| Phone | +60 11-7078 7014 |
| Hours | Monday–Friday, 9:00–18:00 Malaysia Time (MYT) |

Configured in: `lib/constants/help_support_config.dart`

---

## Quick product facts

| Topic | Fact |
|-------|------|
| App name | myRekod |
| Platform | Flutter (web first; also Android/iOS capable) |
| Backend | Supabase (Auth, Postgres, Storage, Realtime) |
| Claims currency | MYR only |
| Geofence | One workplace site; clock-in only |
| Password reset | Email link → set new password → login |
| Password emergency | Admin/developer sets temp password via Supabase Admin API (see [Admin guide §2b](user/02_admin_guide.md#2b-emergency-set-a-users-password-admin--developer)) — passwords cannot be viewed |

---

*Keep this folder updated when features change.*
