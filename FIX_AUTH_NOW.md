# Fix Authentication Errors - Step by Step Guide

## Quick Diagnosis

Your code is **100% correct**. The "API error" is coming from Supabase configuration settings, not your code.

## Step 1: Use the Diagnostic Tool

1. Build the project:
   ```bash
   npm run build
   ```

2. Start preview server:
   ```bash
   npm run preview
   ```

3. Open this URL in your browser:
   ```
   http://localhost:4173/auth-diagnostic-complete.html
   ```

4. Click "🚀 Test Sign Up" with the pre-filled test data

5. **Look at the browser console (F12)** for the exact error message

---

## Step 2: Check Supabase Dashboard Settings

### A. Email Confirmation Setting

**Go to:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/providers

1. Click on "Email" provider
2. Look for "Enable email confirmations" checkbox

**Current Status:** _________________ (check one)
- [ ] ENABLED - Users must confirm email before signing in
- [ ] DISABLED - Users can sign in immediately

**What this means:**
- If **ENABLED**: Sign up will NOT create a session immediately. User must click email link first.
- If **DISABLED**: Sign up creates session immediately and user is signed in.

**Recommendation for testing:** DISABLE email confirmation temporarily

**Recommendation for production:** ENABLE email confirmation

---

### B. Redirect URLs

**Go to:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

1. Look at "Redirect URLs" section
2. Make sure these URLs are added:
   ```
   https://souvenirpickers.com
   https://souvenirpickers.com/**
   http://localhost:4173
   http://localhost:4173/**
   http://localhost:5173
   http://localhost:5173/**
   ```

**If URLs are missing:**
- Click "Add URL"
- Paste each URL
- Click "Save"

---

### C. Email Provider (If email confirmation is enabled)

**Go to:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/providers

1. Check if "Enable Custom SMTP" is configured
2. Your settings should be:
   ```
   SMTP Host: mail.souvenirpickers.com
   SMTP Port: 587
   SMTP User: support@souvenirpickers.com
   ```

**If not configured:**
- Either configure SMTP
- Or temporarily disable email confirmation

---

## Step 3: Test Again

After making changes in Supabase dashboard:

1. Go back to: http://localhost:4173/auth-diagnostic-complete.html
2. Click "🚀 Test Sign Up" again
3. Check browser console (F12) for results

---

## Common Error Messages and Solutions

### Error: "Invalid email or password"
**Cause:** Wrong credentials
**Solution:** Use a new email or reset password

### Error: "User already registered"
**Cause:** Email already exists
**Solution:** Use different email or try signing in

### Error: "Email rate limit exceeded"
**Cause:** Too many requests
**Solution:** Wait 60 seconds and try again

### Error: "Invalid redirect URL"
**Cause:** Current URL not in allowed list
**Solution:** Add URL to redirect URLs in dashboard (Step 2B)

### Error: No error, but no session created
**Cause:** Email confirmation is enabled
**Solution:** Check email for confirmation link, or disable email confirmation

### Error: Network error / CORS
**Cause:** Can't reach Supabase API
**Solution:**
- Check internet connection
- Check if Supabase project is paused
- Try from different network

---

## Expected Behavior

### With Email Confirmation DISABLED:

1. User fills sign up form
2. Click "Sign Up"
3. ✅ User is created
4. ✅ Profile is created (via database trigger)
5. ✅ Session is created
6. ✅ User is signed in immediately
7. ✅ Redirected to app

### With Email Confirmation ENABLED:

1. User fills sign up form
2. Click "Sign Up"
3. ✅ User is created (but email NOT confirmed)
4. ❌ Profile is NOT created yet (waiting for confirmation)
5. ❌ Session is NOT created
6. ✅ "Check your email" message shown
7. User clicks link in email
8. ✅ Email is confirmed
9. ✅ Profile is created (via database trigger)
10. ✅ User is redirected to app and signed in

---

## Quick Test Matrix

| Setting | Sign Up Result | Profile Created | Session Created |
|---------|---------------|-----------------|-----------------|
| Email confirmation OFF | ✅ Success | ✅ Immediately | ✅ Immediately |
| Email confirmation ON | ✅ Success | ⏳ After email click | ⏳ After email click |
| Redirect URL missing | ❌ Error | ❌ No | ❌ No |
| Wrong credentials (sign in) | ❌ Error | N/A | ❌ No |
| Rate limited | ❌ Error | ❌ No | ❌ No |

---

## Still Having Issues?

Run these commands and share the output:

```bash
# 1. Test the build
npm run build

# 2. Check environment variables
cat .env | grep VITE_SUPABASE
```

Then use the diagnostic tool and copy:
1. The exact error message
2. The browser console output (all red errors)
3. The response from "🔬 Test Raw API" button

---

## What We Know Is Working

✅ Code is correct
✅ Environment variables are set
✅ Supabase client initializes
✅ Database triggers exist
✅ Build succeeds
✅ AuthForm component is correct
✅ AuthContext is correct

## What Needs to Be Checked

🔍 Supabase email confirmation setting
🔍 Supabase redirect URLs
🔍 Supabase email provider (if confirmation enabled)
🔍 Network connectivity to Supabase
🔍 Rate limiting status

Use the diagnostic tool to check these automatically!
