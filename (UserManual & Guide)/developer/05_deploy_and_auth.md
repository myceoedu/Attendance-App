# Deploy and auth URLs

How production web hosting and Supabase Auth redirects fit together.

---

## Typical production URL

Example used in this project:

`https://attendance-app-peach-rho.vercel.app` (CURRENT DOMAIN/LINK WEBSITE OR APP)

Update this doc if the production domain changes.

---

## Vercel (or similar) env vars

Set for the Flutter web build: *GO TO ENVIRONMENT VARIABLES DAN EDIT URL & ANON KEY KPD YG LATEST IF GUNA NEW ACC SUPABASE DAN SAVE* - *LEPAS TU REDEPLOY DEKAT DEPLOYMENTS*

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
https://attendance-app-peach-rho.vercel.app

### Redirect URLs (examples)
https://attendance-app-peach-rho.vercel.app/**
http://localhost:(follow current running local host)/**
http://127.0.0.1:(follow current running local host)/**

Wildcard form `http://localhost:**` may not always be accepted depending on Supabase UI — prefer explicit ports or `/**` patterns Supabase allows.

---

## Password reset redirect

- `lib/utils/auth_redirect.dart`
- `AuthProvider.sendPasswordResetEmail`
- `SetNewPasswordScreen`

If redirect URL is not allow-listed, users click the email and only see login — recovery UI never opens.

### Built-in email rate limit (common in testing)

Supabase’s default email provider allows about **2 auth emails per hour project-wide (FREE VERSION)** (`/auth/v1/recover`, signup, etc.). Symptom: **429** / `email rate limit exceeded`. Changing network or email often does **not** help until the window resets.

**Emergency unlock (no email):** Full steps for HR/admins: [user/02_admin_guide.md §2b](../user/02_admin_guide.md#2b-emergency-set-a-users-password-admin--developer).

Never put `service_role` in the Flutter client. Rotate the key if it was exposed.
*SERVICE ROLE KEY BOLEH COPY DEKAT (SUPABASE-PROJECT SETTING-API KEY)*
---

## Edge Function: admin-create-user

Admin **Add employee** calls this function so the admin session is not replaced.

```bash
supabase functions deploy admin-create-user --no-verify-jwt
```

Source: `supabase/functions/admin-create-user/index.ts`

Never put `service_role` in the Flutter client.

---

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
