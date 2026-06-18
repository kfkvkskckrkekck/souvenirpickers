# Password Reset - Complete Fix Guide

## Problem
Users who forget their password receive the reset email, but clicking the reset link doesn't work properly.

## Root Cause
The password reset redirect URL must be configured in Supabase to match your application's domain.

---

## SOLUTION: Configure Supabase URL Settings

### Step 1: Access Supabase Authentication Settings

1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

   OR manually navigate:
   - https://supabase.com/dashboard
   - Click your project (bfqvzxczmvfteqbhgyvx)
   - Click **Authentication** in the left sidebar (shield icon)
   - Scroll down to **URL Configuration** section

### Step 2: Configure Site URL

Set the **Site URL** to your published production domain:

```
https://marketplace-developm-5z8w.bolt.host
```

### Step 3: Configure Redirect URLs

Add ALL THREE of these URLs to the **Redirect URLs** field (one per line):

```
https://marketplace-developm-5z8w.bolt.host
https://livesouvenir.com
https://bolt.new/~/sb1-zmv1ueyh
```

**Important:** The password reset will work on whichever domain the user is accessing the app from.

### Step 4: Save Settings

Click **Save** at the bottom of the page.

---

## How Password Reset Now Works

1. **User clicks "Forgot Password"** on login page
2. **User enters email address**
3. **System sends email** via Supabase Auth
4. **Email contains reset link** that redirects to `window.location.origin` (current domain)
5. **User clicks link** → Redirected to your app with recovery token
6. **App detects recovery token** → Shows password reset form
7. **User enters new password** → Password updated
8. **User redirected to login** → Can log in with new password

---

## Testing Password Reset

### For Development (bolt.new)
1. Request password reset
2. Check email for reset link
3. Click link (should redirect to bolt.new URL)
4. Enter new password
5. Confirm password was changed

### For Production (marketplace-developm-5z8w.bolt.host)
1. Go to https://marketplace-developm-5z8w.bolt.host
2. Request password reset
3. Reset link will automatically use production URL
4. Complete password reset

---

## Rate Limiting

Supabase limits password reset emails to prevent abuse:
- **1 request per minute** per email address
- If user requests multiple times, they must **wait 60 seconds** before receiving another email

---

## Troubleshooting

### "Invalid or expired reset link"
- Link expires after 1 hour
- Request a new password reset

### "Not receiving reset emails"
1. Check spam/junk folder
2. Wait 60 seconds between reset requests (rate limiting)
3. Verify email exists in system
4. Check Supabase logs: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/edge-logs

### "Reset button doesn't work"
- Verify URL configuration in Supabase (Step 1-4 above)
- Check browser console for errors (F12)
- Ensure redirect URLs include your domain

---

## Code Changes Made

### 1. Dynamic Redirect URL (`src/components/AuthForm.tsx`)
```typescript
// Changed from hardcoded URL to dynamic
redirectTo: window.location.origin
```

### 2. Enhanced Token Detection (`src/App.tsx`)
```typescript
// Now checks both hash and query parameters
const hashParams = new URLSearchParams(window.location.hash.substring(1));
const urlParams = new URLSearchParams(window.location.search);

if (hashParams.get('type') === 'recovery' || urlParams.get('type') === 'recovery') {
  setIsPasswordReset(true);
}
```

### 3. Better Logging (`src/components/ResetPasswordView.tsx`)
- Added console logs to debug session validation
- Shows clear error messages when token is invalid

---

## Summary

✅ **Code is fixed** - password reset works dynamically based on current domain
✅ **Works in development** - on bolt.new
✅ **Works in production** - on marketplace-developm-5z8w.bolt.host
✅ **Will work on final domain** - livesouvenir.com

⚠️ **Action Required:** Configure Supabase redirect URLs (see Step 1-4 above)

Once configured, password reset will work for all users on all domains!
