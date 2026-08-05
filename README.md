# myRekod (attendance_app)

Flutter HR app for attendance, leave, claims, payroll, announcements, and workplace geofence.  
Backend: **Supabase**.

---

## Documentation (start here)

All handover docs for **users** and **new developers** are in:

### → [docs/README.md](docs/README.md)

| Audience | Go to |
|----------|--------|
| Employees & admins | [docs/user/](docs/user/) |
| Developers | [docs/developer/](docs/developer/) |
| PDF manuals | [docs/pdf/](docs/pdf/) — User Manual + Developer Handover |

---

## Quick start (developers)

```bash
flutter pub get
flutter run -d chrome
```

Configure Supabase in `lib/config/app_config.dart` or via:

```bash
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
```

Database setup: [supabase_bundles/README.md](supabase_bundles/README.md)

---

## Support (in-app)

Phone: **+60 11-7078 7014**  
Configured in `lib/constants/help_support_config.dart`
