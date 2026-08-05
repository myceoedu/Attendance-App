# Setup and run

Follow this to run myRekod on your machine.

---

## Prerequisites

- Flutter SDK (project uses Dart SDK `^3.8.1`)
- Chrome (for web) or Android/iOS tooling if needed
- Access to the Supabase project (URL + anon key)
- Git

Check Flutter:

```bash
flutter doctor
```

---

## 1. Get the code

```bash
cd "D:\Android Studio Project\attendance_app"
flutter pub get
```

---

## 2. Configure Supabase

Config lives in:

`lib/config/app_config.dart`

It supports:

1. Compile-time env:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
2. Fallback defaults inside `app_config.dart` when env is empty

### Local run with defaults

If defaults already point to the correct project, just run:

```bash
flutter run -d chrome
```

### Local run with explicit env

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Optional for password-reset redirects:

```bash
--dart-define=APP_ORIGIN=http://localhost:YOUR_PORT
```

---

## 3. Run the app

```bash
flutter run -d chrome
```

Other devices:

```bash
flutter devices
flutter run -d windows
flutter run -d edge
```

After adding packages (e.g. `flutter_map`), do a **full restart**, not only hot reload.

---

## 4. First admin user

1. Register a user in the app
2. In Supabase SQL Editor:

```sql
UPDATE public.users
SET role = 'admin'
WHERE email = 'your-admin@email.com';
```

3. Sign out and sign in again

---

## 5. Useful commands

```bash
flutter pub get
flutter analyze
flutter test
dart analyze lib
```

---

## 6. Common first-day issues

| Problem | Fix |
|---------|-----|
| Blank / config error | Set Supabase URL + anon key |
| Signup fails | Run auth SQL bundles / triggers |
| Password reset lands on login only | Fix Auth Redirect URLs (see deploy doc) |
| Workplace location missing table | Run `supabase_migration_work_site_geofence.sql` |
| Map picker needs restart | Full restart after `flutter_map` install |

---

## Next

- [Supabase and database](02_supabase_and_database.md)
- [Architecture](03_architecture.md)
