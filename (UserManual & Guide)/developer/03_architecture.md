# Architecture

How the Flutter app is structured.

---

## High-level flow

```text
main.dart
  → Supabase.initialize
  → AuthProvider.init
  → AuthGate
       → LoginScreen (guest)
       → SetNewPasswordScreen (password recovery)
       → AdminShell / EmployeeShell (signed in)
```

---

## State management

- **Provider** with `AuthProvider`
- Profile cached via `SessionProfileCache` for faster startup
- Feature screens mostly use local `StatefulWidget` state + `SupabaseService`

Do **not** assume Riverpod/Bloc — this project uses Provider.

---

## Navigation

File: `lib/utils/app_route.dart`

| Platform | Behaviour |
|----------|-----------|
| Web | Instant push/pop (`_InstantPageRoute`) — avoids sluggish animated transitions |
| iOS native | Instant push, short Cupertino reverse |
| Android / desktop | Short fade |

Helpers:

- `pushAppPage(context, page)`
- `popApp(context)`

Prefer these over raw `MaterialPageRoute` for consistency.

> Note: On web/PWA, **browser edge-swipe back** uses History API and can feel slower than the AppBar back button. This is expected with the current route strategy.

---

## Shells (tabs)

### Employee (`EmployeeShell`)

Tabs:

0. Home (`EmployeeHomeTab`)
1. Clock (`EmployeeAttendanceTab`)
2. Profile (`ProfileTab`)

Uses lazy `IndexedStack` so visited tabs stay warm.

### Admin (`AdminShell`)

Tabs:

0. Home (`AdminHomeTab`)
1. Attendance overview
2. Employees list

Same lazy IndexedStack pattern.

---

## Services

Central API layer:

`lib/services/supabase_service.dart`

Also:

| Service | Role |
|---------|------|
| `app_realtime.dart` | Realtime channel helpers |
| `payroll_engine.dart` | Payroll calculation |
| `announcement_badge_service.dart` | Unread announcement counts |
| PDF helpers | Profile / payslip export |

Prefer adding new backend calls in services — not deep inside widgets.

---

## Time zone

Malaysia time helpers:

`lib/utils/app_time.dart`

Attendance “today” and many SQL functions use **Asia/Kuala_Lumpur**.

---

## Auth / password recovery

| Piece | File |
|-------|------|
| Reset email + redirect | `AuthRedirect`, `SupabaseService.sendPasswordResetEmail` |
| Recovery flag | `AuthProvider.passwordRecoveryPending` |
| Bootstrap from URL | `AuthLinkBootstrap` (before URL cleanup) |
| Set password UI | `SetNewPasswordScreen` |
| Config contact | `help_support_config.dart` |

Flow:

1. Forgot password sends email with `redirectTo` including `passwordReset=1`
2. App detects recovery session
3. Shows set password screen
4. Updates password, signs out, returns to login with success banner

---

## Geofence architecture

```text
Admin saves work_site (id=1)
        ↓
Employee clock-in
        ↓
Client: GPS + distance check (fast UX)
        ↓
RPC clock_in_if_allowed (server truth)
```

Utils: `lib/utils/geofence.dart`  
Model: `lib/models/work_site.dart`

---

## Performance patterns already used

- In-flight request dedupe / short caches (employees, work site)
- `AsyncLoadGuard` on loads
- `ValueNotifier` for clocks (avoid full rebuild every second)
- Home dashboards: count queries + `RepaintBoundary` + skip unchanged `setState`
- Lazy tab creation in shells

When adding features, avoid:

- Fetching huge lists only to show a count
- Soft multi-layer shadows on long scrollable grids (web cost)
- Rebuilding whole dashboards on every realtime event when data did not change

---

## Next

- [Features and key files](04_features_and_key_files.md)
