# Handover checklist

Use this on day 1 of taking over the project.

---

## Access you should receive

- [ ] Git repository access
- [ ] Supabase project access (Dashboard)
- [ ] Vercel (or host) project access
- [ ] Production app URL
- [ ] At least one admin test account
- [ ] Support phone ownership / update rights (`help_support_config.dart`)

---

## Verify the environment

- [ ] `flutter pub get` works
- [ ] `flutter run -d chrome` opens the app
- [ ] App talks to the correct Supabase project
- [ ] SQL bundles / migrations already applied on that project
- [ ] Storage buckets exist
- [ ] Auth Site URL + Redirect URLs match production + local

---

## Verify product flows

### Employee
- [ ] Register / login
- [ ] Forgot password → set new password → login
- [ ] Clock in / clock out
- [ ] Apply leave
- [ ] Submit claim (MYR)
- [ ] View announcements
- [ ] Open Help & support

### Admin
- [ ] Home dashboard loads
- [ ] Edit an employee
- [ ] Approve/reject leave
- [ ] Approve/reject claim
- [ ] Open payroll hub
- [ ] Post announcement
- [ ] Set Workplace location on map, enforce ON, save
- [ ] Confirm employee outside radius cannot clock in

---

## Read these docs

- [ ] [docs/README.md](../README.md)
- [ ] [User getting started](../user/00_getting_started.md)
- [ ] [Employee guide](../user/01_employee_guide.md)
- [ ] [Admin guide](../user/02_admin_guide.md)
- [ ] [Developer overview](00_overview.md)
- [ ] [Setup and run](01_setup_and_run.md)
- [ ] [Supabase and database](02_supabase_and_database.md)
- [ ] [Architecture](03_architecture.md)
- [ ] [Features and key files](04_features_and_key_files.md)
- [ ] [Deploy and auth](05_deploy_and_auth.md)

---

## Known care points (do not ignore)

1. **Wrong Supabase project** — many “bugs” are missing SQL on the active project  
2. **Password reset Redirect URLs** — must include app origin  
3. **Geofence SQL** — table `work_site` + updated `clock_in_if_allowed` required  
4. **Payroll RLS recursion** — run fix migration if payslips error `42P17`  
5. **Web performance** — avoid heavy rebuilds/shadow stacks on dashboards  
6. **Signup rate limit (429)** — tell testers to wait, not spam Create account  
7. **OSM tiles** — `flutter_map` uses OpenStreetMap; respect tile usage policy for heavy production traffic

---

## When you change a feature

1. Update the matching **user** doc if staff/admin steps change  
2. Update **developer** feature map if files move  
3. Add/adjust SQL migration if schema/RPC changes  
4. Redeploy web + confirm Auth URLs if domain changes  



You’re ready when the checkboxes above are done and you can demo employee + admin happy paths without guessing.
