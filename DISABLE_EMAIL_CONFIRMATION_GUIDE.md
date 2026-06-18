# Fix Signup Email Confirmation Error

## Problem
Users get this error when signing up:
```json
{"code":"unexpected_failure","message":"Error sending confirmation email"}
```

This happens because Supabase is trying to send confirmation emails but SMTP is not configured.

## Solution: Disable Email Confirmation in Supabase Dashboard

Follow these steps to fix the issue:

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Select your project: **bfqvzxczmvfteqbhgyvx**

### Step 2: Navigate to Authentication Settings
1. In the left sidebar, click on **Authentication**
2. Click on **Providers** (or **Email Auth**)
3. Scroll down to find **Email Auth** settings

### Step 3: Disable Email Confirmation
1. Look for the setting **"Enable email confirmations"** or **"Confirm email"**
2. **Toggle it OFF** (disable it)
3. Click **Save** at the bottom

### Alternative Path (if above doesn't work):
1. Go to **Authentication** → **Settings** → **Email Templates**
2. Look for **"Enable email confirmations"** toggle
3. **Turn it OFF**
4. Save changes

### Step 4: Verify the Fix
1. Try creating a new account on your website
2. The signup should now complete immediately without requiring email confirmation
3. Users will be logged in automatically after signup

## What This Does
- Users can sign up and log in immediately without email confirmation
- No confirmation email will be sent
- The signup error will be resolved
- User accounts are created instantly and fully functional

## Security Note
While disabling email confirmation makes signup easier, it means:
- Users don't need to verify they own the email address
- Consider adding email verification later once SMTP is properly configured
- You can re-enable confirmation once you have SMTP set up

## If You Want Email Confirmation Later
To enable email confirmation properly in the future:
1. Configure SMTP settings in Supabase Dashboard
2. Go to **Project Settings** → **Authentication** → **SMTP Settings**
3. Add your SMTP provider details (Gmail, SendGrid, etc.)
4. Test the connection
5. Re-enable email confirmations

---

**After making this change, test signup immediately - it should work without errors!**
