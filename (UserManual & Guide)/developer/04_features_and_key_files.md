# Features and key files

Use this as a map when you need to change a feature quickly.

---

## Auth & onboarding

| Feature | Key files |
|---------|-----------|
| Login | `lib/screens/login_screen.dart` |
| Register | `lib/screens/register_screen.dart` |
| Forgot password | `lib/screens/forgot_password_screen.dart` |
| Set new password (email link) | `lib/screens/set_new_password_screen.dart` |
| Auth state | `lib/providers/auth_provider.dart` |
| Redirect / recovery URL | `lib/utils/auth_redirect.dart`, `lib/utils/auth_link_bootstrap.dart` |
| App entry(MAIN) / AuthGate | `lib/main.dart` |
| Config | `lib/config/app_config.dart` |

---

## Employee app

| Feature | Key files |
|---------|-----------|
| Shell(3 BUTTON YG BAWAH TU) / tabs | `lib/screens/employee/employee_shell.dart` |
| Home | `lib/screens/employee/employee_home_tab.dart` |
| Clock in/out | `lib/screens/employee/employee_attendance_tab.dart` |
| Attendance history/log | `attendance_history_screen.dart`, `employee_attendance_log_screen.dart` |
| Leave | `leave_tab.dart`, `apply_leave_screen.dart` |
| Claims | `claims_screen.dart`, `submit_claim_screen.dart`, `claim_detail_screen.dart` |
| Payslips | `employee_payroll_history_screen.dart`, `employee_payslip_detail_screen.dart` |
| Profile | `profile_tab.dart` |
| Announcements | `lib/screens/announcements_screen.dart` |
| Help | `lib/screens/help_support_screen.dart` |

---

## Admin app

| Feature | Key files |
|---------|-----------|
| Shell / tabs | `lib/screens/admin/admin_shell.dart` |
| Home | `lib/screens/admin/admin_home_tab.dart` |
| Employees list/edit | `employee_list_screen.dart`, `admin_employee_edit_screen.dart`, `admin_add_employee_screen.dart` |
| Admin create employee | Edge Function `supabase/functions/admin-create-user` |
| Attendance overview | `attendance_overview_screen.dart`, calendar screens |
| Leave inbox | `leave_management_screen.dart` (home shortcut opens this directly) |
| Claims | `claim_management_screen.dart` |
| Announcements | `admin_announcements_screen.dart` |
| Workplace geofence | `admin_work_site_screen.dart`, `work_site_map_picker_screen.dart` |
| OSM map widget | `lib/widgets/work_site_osm_map.dart` |
| Payroll hub | `lib/screens/admin/payroll/*` |

---

## Shared services / utils

| Concern | File |
|---------|------|
| Almost all backend calls | `lib/services/supabase_service.dart` |
| Realtime subscriptions | `lib/services/app_realtime.dart` |
| Payroll math | `lib/services/payroll_engine.dart` + `lib/payroll/*` |
| Malaysia time | `lib/utils/app_time.dart` |
| Friendly errors | `lib/utils/error_messages.dart` |
| Geofence math | `lib/utils/geofence.dart` |
| Profile validators | `lib/utils/profile_validators.dart` |
| Theme / colours | `lib/constants/app_theme.dart` |
| Support phone/email | `lib/constants/help_support_config.dart` |

---

## Models (examples)

Under `lib/models/`:

- `app_user.dart`
- `attendance.dart`
- `leave_request.dart`
- `expense_claim.dart`
- `work_site.dart`
- payroll models (`payroll_run.dart`, `payroll_item.dart`, …)

---

## SQL feature mapping

| App feature | SQL starting point |
|-------------|--------------------|
| Users / auth profile | `02_auth_and_users.sql` |
| Attendance + clock RPC | `01_core_setup.sql`, updated in leave/geofence migrations |
| Leave | `03_leave.sql` |
| Announcements | `04_announcements.sql` |
| Claims | `05_claims.sql` |
| Payroll | `06_payroll.sql` |
| Indexes | `07_indexes.sql` |
| Geofence | `09_work_site.sql` or root `supabase_migration_work_site_geofence.sql` |

---

## Dependencies worth knowing

From `pubspec.yaml`:

- `supabase_flutter`
- `provider`
- `geolocator`
- `flutter_map` + `latlong2` (OpenStreetMap picker)
- `intl`, `file_picker`, `pdf`, `table_calendar`, `google_fonts`, …

---

## Next

- [Deploy and auth](05_deploy_and_auth.md)
- [Handover checklist](06_handover_checklist.md)
