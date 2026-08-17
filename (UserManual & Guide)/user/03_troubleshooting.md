# Troubleshooting

Use this page when something does not work.  
Try the steps in order.

---

## Login and account

### I cannot create an account

1. Check email and password are valid
2. Try a username that is not already taken
3. If you see “too many attempts”, wait 2 hours and try **once**
4. Ask an admin/developer to check Supabase **Authentication → Users** for stuck accounts

### “An account with this email already exists”

- Sign in instead, or use **Forgot password**
- Or ask admin to remove a stuck Auth user, then register again

### I forgot my password

1. Login → **Forgot password?**
2. Enter your email → send reset email
3. Open the **newest** email link (copy/paste into the **same browser** you use for the app if the mail app breaks the link)
4. Set and confirm a new password
5. Sign in

If the link only opens login and does not show “Set new password”:

- Request a new email (wait if rate-limited — see below)
- Make sure Redirect URLs are configured (developer task)
- Open the link in the same browser you use for the app

### “Too many reset attempts” / email rate limit exceeded / 429

- Supabase’s built-in email is limited (about **2 auth emails per hour** for the whole project)
- Waiting and using a different email or network often **does not** help until the hour resets
- **Staff:** wait up to 1 hour, then try Forgot password **once**  
- **Admin/developer emergency:** set a temporary password with the Admin API — see [Admin guide §2b](02_admin_guide.md#2b-emergency-set-a-users-password-admin--developer)

Passwords **cannot** be viewed in the database or dashboard. Only a new password can be set.

---

## Clock in / out

### Clock in is blocked because of leave

- You have approved leave covering today
- Contact HR if that is a mistake

### Location is required / GPS not working

1. Allow location permission for the browser or app
2. Turn on phone GPS / Location Services
3. Try outdoors or near a window
4. Refresh and try again

### “Outside workplace” / too far away

1. Move closer to the office
2. Tap refresh on the distance hint (if shown)
3. Ask admin to check **Workplace location** pin and radius

### I already clocked in today

- The app usually allows one attendance record per day
- Use **Clock Out** if you are still working
- Ask admin to check the attendance record if something looks wrong

---

## Leave and claims

### My leave/claim stays pending

- Waiting for admin approval is normal
- Ask your manager/HR to open Leave or Claims

### I cannot upload a file

- Use a common type (image, PDF, etc.)
- Check file size and internet connection
- Try again on a stable network

### Claim amount currency

- Claims are **MYR (RM)** only

---

## Payslips

### I see no payslips

- HR may not have an approved/paid payroll run yet
- Ask admin to check Payroll

---

## App feels slow

### Scrolling Home feels heavy

1. Close other browser tabs
2. Pull to refresh once
3. Use Add to Home Screen instead of many open Safari tabs
4. Developer may need to check performance notes in the developer docs

### Edge swipe back feels delayed

- Prefer the **← back** button in the app bar  
  (on web/PWA, edge-swipe uses the browser and can feel slower)

---

## Who to contact

| Issue type | Contact |
|------------|---------|
| HR / leave / claims / payslip questions | Your manager or HR |
| App technical problems | Support phone **+60 11-7078 7014** |
| Database / deploy / admin role issues | Your developer |

In Help & support you can **copy diagnostics** and share them when asking for help.

---

## Next

- [Getting started](00_getting_started.md)
- [Employee guide](01_employee_guide.md)
- [Admin guide](02_admin_guide.md)
- Docs home → [docs/README.md](../README.md)
