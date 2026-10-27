# Songhothon: Mobile App Requirements

## 1. Overview

Songhothon is a mobile app for community savings and investment groups. Each group (organization) collects regular deposits from members, tracks each member's shares, and records the group's investments. Every organization's data is completely isolated from the others.

- **Platforms:** Android and iOS (cross-platform, e.g. Flutter or React Native)
- **Currency:** BDT (৳)

---

## 2. User Roles

| Role | Description |
|---|---|
| **Org Admin** | Creates and manages an organization. The creator becomes admin by default. An org can have multiple admins. |
| **Member** | Regular participant who deposits and views data according to the org's visibility settings. |

A user can be a member or admin in multiple organizations, with a different role in each.

---

## 3. Functional Requirements

### 3.1 Authentication
- Sign up with email and password.
- Login and logout.
- Secure session handling, with a forgot/reset password flow.

### 3.2 Onboarding (after first signup)
The user sees two options:
1. **Join an organization** by entering its slug (short code).
2. **Create an organization** (name, unique slug, optional description). The creator is auto-assigned **Admin**.

### 3.3 Multi-Organization Support
- A user can belong to multiple organizations.
- An **organization switcher** (top bar or profile menu) changes the active org.
- All screens show data only for the active org.
- Pending join requests are shown with a "Pending approval" status.

### 3.4 Membership Management
- **Join via slug:** creates a join request with status *Pending*. The org admin approves or rejects it, and the user is notified.
- **Admin adds a member** by phone number or email. If the person has no account yet, they receive an invite and are linked on signup.
- **Admin can remove or deactivate** a member.
- **Role management:** an admin can promote a member to Admin or demote an Admin to Member. At least one admin must always remain.

### 3.5 Shares and Deposit Configuration (Admin)
- Set the **per-share amount** (e.g. ৳500).
- Set the **deposit frequency**: weekly, monthly, or yearly.
- Assign each member a **number of shares**.
- **Deposit due = per-share amount × member's shares.** It is calculated automatically for each cycle.

### 3.6 Down Payment Configuration (Admin)
- Admin defines a special recurring deposit of a fixed amount per member, e.g. ৳5,000 every quarter.
- Configurable fields: amount, interval (e.g. quarterly), start date.
- It is tracked separately from regular deposits, with its own paid/pending/unpaid status.

### 3.7 Payments and Approval

**Member flow:**
1. Open the current due deposit.
2. Pay externally via **bKash or bank transfer**.
3. Mark it as paid and submit the **transaction ID** (bKash) or **bank account number/reference** (bank), with an optional screenshot.
4. Status becomes **Pending**.

**Admin flow:**
- View the list of pending payments, then **approve** or **reject** (with a reason).
- On approval, the status becomes **Paid** and the member gets a **push notification**.
- On rejection, the member is notified and can resubmit.

**Deposit statuses:** `Unpaid` → `Pending` (submitted) → `Paid` (approved), or `Rejected`.

> Payment verification is manual. There is no bKash or bank API integration in the first version.

### 3.8 Investment Records (Admin only)
Admin adds, edits, and deletes investment records. Fields:
- Title (e.g. "Land purchase")
- Type (land, business, etc.)
- Amount invested
- Start date, and duration or end date (e.g. 6 months)
- Notes and status (active, completed)

Total investment is calculated from these records.

### 3.9 Notifications
- **Push notifications** for:
  - Join request approved or rejected
  - Payment approved or rejected
  - Admin announcements
  - Deposit due reminders
- **Admin can send a custom push** to all members or selected members at any time.
- **Scheduled and repeating notifications:** admin sets a date and time, with repeat options (once, daily, weekly, monthly), for example a reminder on the 5th of every month.
- An in-app notification list stores past notifications.

### 3.10 Member Dashboard
Shown per organization:
- Personal total deposit (savings)
- Number of shares held
- Current month's deposit status (**Paid / Pending / Unpaid**)
- Total organization deposit
- Total organization investment
- Deposit history (personal)
- **Member list** with joining date

### 3.11 Data Visibility Control (Admin)
Admin configures whether members can see other members' data. Suggested toggles:
- Show other members' list: on/off
- Show other members' deposits and shares: on/off

Members always see their own savings and shares. Admins always see everything.

### 3.12 Admin Dashboard
- Pending join requests and pending payments (with counts)
- Collection summary for the current cycle (who has paid and who has not)
- Total deposit, total investment, member count
- Quick access to member management, shares, investments, and notifications

---

## 4. UI/UX Requirements
- Simple, clean, and standard design using Material (Android) and iOS-style components.
- Bottom navigation, for example: **Home, Deposits, Members, Investments (Admin), More**.
- Clear status colors: green for paid, orange for pending, red for unpaid.
- Easy org switching from any main screen.
- Optional later: Bangla and English language support.

---

## 5. Non-Functional Requirements
- **Data isolation:** every record is scoped to an organization ID, and access is checked on the server per request.
- **Security:** hashed passwords, HTTPS, and role checks on every admin API.
- **Audit trail:** log who approved a payment and when, and who changed roles or shares.
- **Performance:** dashboard loads in under 3 seconds on a normal mobile connection.
- **Push infrastructure:** Firebase Cloud Messaging (FCM).

---

## 6. Suggested Screens
1. Splash, Login, Signup, Forgot Password
2. Onboarding (Join or Create Org)
3. Organization Switcher
4. Member Dashboard
5. Deposit List and Submit Payment
6. Member List
7. Notifications
8. Profile and Settings
9. **Admin:** Join Requests, Payment Approvals, Member and Share Management, Deposit and Down Payment Settings, Investments, Send or Schedule Notification, Visibility Settings, Role Management

---

## 7. Points to Confirm
1. Can a member belong to an org without any shares (e.g. 0 shares)?
2. If a member's shares change mid-cycle, does the new amount apply from the next cycle only?
3. Should overdue deposits carry a late fee?
4. Can an admin mark a deposit as paid on behalf of a member (cash payments)?
5. Does a member's savings include the down payment, or are the two shown separately?
6. Should an org admin be able to delete the organization?
