# Deploy and auth URLs

How production web hosting and Supabase Auth redirects fit together.

---

## Typical production URL

Example used in this project:

`https://attendance-app-peach-rho.vercel.app`

Update this doc if the production domain changes.

---

## Vercel (or similar) env vars

Set for the Flutter web build:

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |

Pass them into the build as `--dart-define=...` in your CI/build script.

If env vars are missing/empty, the app falls back to defaults in `lib/config/app_config.dart`.

After changing env vars → **redeploy**.

---

## Supabase Auth URL configuration

Dashboard → **Authentication** → **URL configuration**

### Site URL

```text
https://attendance-app-peach-rho.vercel.app
```

(No trailing path required; use your real production origin.)

### Redirect URLs (examples)

```text
https://attendance-app-peach-rho.vercel.app/**
http://localhost:4840/**
http://127.0.0.1:4840/**
```

Add any other local Flutter web ports you use (`flutter run` often changes ports).

Wildcard form `http://localhost:**` may not always be accepted depending on Supabase UI — prefer explicit ports or `/**` patterns Supabase allows.

---

## Password reset redirect

App code builds redirect like:

```text
{APP_ORIGIN}?passwordReset=1
```

See:

- `lib/utils/auth_redirect.dart`
- `AuthProvider.sendPasswordResetEmail`
- `SetNewPasswordScreen`

If redirect URL is not allow-listed, users click the email and only see login — recovery UI never opens.

### Built-in email rate limit (common in testing)

Supabase’s default email provider allows about **2 auth emails per hour project-wide** (`/auth/v1/recover`, signup, etc.). Symptom: **429** / `email rate limit exceeded`. Changing network or email often does **not** help until the window resets.

**Production:** configure **Custom SMTP** (Project Settings → Auth → SMTP).

**Emergency unlock (no email):** Admin API `PUT /auth/v1/admin/users/{uid}` with `service_role` and `{ "password": "..." }`. Full steps for HR/admins: [user/02_admin_guide.md §2b](../user/02_admin_guide.md#2b-emergency-set-a-users-password-admin--developer).

Never put `service_role` in the Flutter client. Rotate the key if it was exposed.

---

## Help & support contact

Edit:

`lib/constants/help_support_config.dart`

| Field | Current idea |
|-------|----------------|
| `supportPhone` | `+60 11-7078 7014` |
| `supportEmail` | empty (hidden) |
| `officeHours` | Mon–Fri 9:00–18:00 MYT |

---

## Storage

Production Supabase project must have buckets:

- `leave-attachments`
- `claim-attachments`

---

## Smoke test after deploy

1. Open production URL
2. Sign in as employee → clock tab loads
3. Sign in as admin → home shortcuts load
4. Forgot password → email link opens **Set new password**
5. Admin Workplace location → map loads → save works
6. Employee clock-in with geofence ON near the pin

---

## Next

- [Handover checklist](06_handover_checklist.md)
