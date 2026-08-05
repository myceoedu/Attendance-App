# Admin guide

This guide is for **HR / administrators**.  
Use it to manage staff, attendance, leave, claims, payroll, and workplace location.

---

## 1. Admin Home

After login (with an admin account), you see the **admin dashboard**.

### Today’s pulse

Quick numbers such as:

- Team size
- Clocked in
- Clocked out
- Items needing action (leave / claims)

### Shortcuts

From Home you can open:

| Shortcut | What you do there |
|----------|-------------------|
| Leave hub | Review leave requests |
| Payroll | Salaries, runs, payslips |
| Attendance | Who clocked in/out (also a bottom tab) |
| Team | Employee list |
| Claims | Approve expense claims |
| Announcements | Post company news |
| Workplace location | Set office GPS + clock-in radius |
| Help & support | FAQs and support phone |

Pull down to refresh.

---

## 2. Employees (team)

1. Open the **Employees** bottom tab (or Team from Home)
2. Find and tap an employee
3. Edit details such as:
   - Full name, phone, address
   - Role (Employee / Admin)
   - Job title, department, employee ID
   - Employment start date
   - EPF / SOCSO / bank
   - Education and emergency contact
   - Annual leave override (optional)
4. Tap **Save changes**

### Important

- **Email** and **username** are set at registration and are not edited on this screen
- To make someone an admin, set **Role** to Admin and save  
  (or ask a developer to update `public.users.role` in Supabase)

---

## 3. Attendance

1. Open the **Attendance** bottom tab
2. Review who clocked in / out today
3. Use calendar or monthly views if available for deeper checks

Employees create their own punches from the Clock tab.  
Admins mainly monitor and investigate.

---

## 4. Leave management

1. Home → **Leave hub**
2. Choose how you want to review leave (pending list and/or by employee)
3. Open a request
4. **Approve** or **Reject**
5. Add a clear reason when rejecting

Employees see the new status in their Leave section.

---

## 5. Claims management

1. Home → **Claims**
2. Open a pending claim
3. Check:
   - Amount (MYR)
   - Category
   - Receipts / attachments
4. Approve or reject

---

## 6. Payroll

1. Home → **Payroll**
2. Typical flow:

### A. Salary settings
- Set or edit employee salary components
- Choose EPF category where needed

### B. Statutory settings
- Review EPF / SOCSO / EIS related settings used by payroll

### C. Payroll runs
1. Create or open a payroll run for a period
2. Generate / review employee items
3. Check amounts
4. Approve / mark paid according to your process

### D. Payslips
- After a run is approved/paid, employees can view payslips in their app

If employees see no payslips, check that a run exists and is in the right status.

---

## 7. Announcements

1. Home → **Announcements**
2. Create a title and message
3. Publish
4. Staff see it under Announcements on their Home screen

---

## 8. Workplace location (very important)

This sets **one office location** for clock-in.

### What it does

- Staff must be inside your chosen radius to **clock in**
- **Clock out** is not checked
- The saved pin does **not** follow the admin phone home

### How to set it

1. Home → **Workplace location**
2. Enter a workplace name (example: `HQ Office`)
3. Set the map pin using either:
   - **Pick on OpenStreetMap** → tap the office on the map → confirm, or
   - **Use my current location** while standing at the real office
4. Set **Radius (metres)**  
   Example: `100`  
   Allowed roughly **20–5000**
5. Turn **Enforce on clock-in** **ON**
6. Tap **Save workplace**

### Tips

| Tip | Why |
|-----|-----|
| Stand at the real office when using GPS | Saves the correct pin |
| Start with 100 m | Good balance for GPS accuracy |
| Increase radius if staff near the door fail often | Indoor GPS can be slightly off |
| Turn enforce OFF only for testing | Otherwise staff can clock in from anywhere |

### Map preview

- The teal circle shows the allowed clock-in area
- Tap the preview or **Pick on OpenStreetMap** to edit the pin

---

## 9. Help & support

Same Help screen as employees, with admin tips.

| Contact | Detail |
|---------|--------|
| Phone | +60 11-7078 7014 |
| Hours | Mon–Fri, 9:00–18:00 MYT |

---

## 10. Admin daily checklist

1. Open Home → check pulse numbers
2. Review pending **Leave** and **Claims**
3. Check **Attendance** if needed
4. Post an **Announcement** when there is company news
5. Keep **Workplace location** accurate if the office moves
6. Run **Payroll** on your company schedule

---

## Next

- Staff view → [Employee guide](01_employee_guide.md)
- Problems → [Troubleshooting](03_troubleshooting.md)
- Docs home → [docs/README.md](../README.md)
