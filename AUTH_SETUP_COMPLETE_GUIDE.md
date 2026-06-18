# Complete Authentication Setup Guide

## Current Status

✅ Code is ready and working
✅ Database triggers configured
✅ Edge functions deployed
✅ SMTP configured in Supabase (per your confirmation)
❓ Need to verify redirect URLs

## Step-by-Step Configuration

### Step 1: Verify SMTP Settings

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth

Scroll to **SMTP Settings** and verify:
- ✅ Custom SMTP is enabled
- ✅ Host: `mail.souvenirpicker.com`
- ✅ Port: `587`
- ✅ Username: `support@souvenirpickers.com`
- ✅ Sender: `support@souvenirpickers.com`

### Step 2: Configure URL Settings (CRITICAL)

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

#### Site URL
```
https://souvenirpickers.com
```

#### Redirect URLs (Add ALL)
```
https://souvenirpickers.com
https://souvenirpickers.com/**
http://localhost:5173
http://localhost:5173/**
```

**Why:** Without these, you'll get 400/401 errors on email confirmations

### Step 3: Configure Email Templates (Optional but Recommended)

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates

Customize these templates:
- **Confirm signup** - Sent when users register
- **Magic Link** - Sent for passwordless login
- **Reset password** - Sent for password resets

Use the `{{ .ConfirmationURL }}` variable for links.

### Step 4: Email Provider Settings

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/providers

#### Email Provider
- ✅ Enabled
- **Confirm email:** Choose based on your needs:
  - ☑️ **Enabled** = Users must confirm email before signing in (more secure)
  - ☐ **Disabled** = Users can sign in immediately (faster onboarding)

Recommendation: **Enable** for production, **Disable** for testing

#### Rate Limits
- Verify rate limits are reasonable
- Default is usually fine for production

### Step 5: Test Authentication

#### Option A: Use Debug Tool (Recommended)
1. Open: `https://souvenirpickers.com/test-auth-debug.html`
2. Test each function:
   - Sign Up
   - Sign In
   - Password Reset
   - Magic Link
3. Check for any errors in the debug output

#### Option B: Test in Main App
1. Go to your main app
2. Try signing up with a test email
3. Check your email for confirmation
4. Complete the flow

## Common Issues and Solutions

### Issue 1: "Email link is invalid or has expired"
**Cause:** Redirect URL not whitelisted
**Solution:** Add all redirect URLs in Step 2

### Issue 2: 400/401 Error on Sign Up
**Cause:** Configuration mismatch
**Solutions:**
1. Verify SMTP settings
2. Check redirect URLs
3. Verify Site URL is correct
4. Check Supabase logs for specific error

### Issue 3: Email Not Received
**Causes:**
1. SMTP credentials incorrect
2. Email in spam folder
3. SMTP host blocking
4. Rate limit exceeded

**Solutions:**
1. Verify SMTP settings in dashboard
2. Check spam folder
3. Check Supabase Auth Logs
4. Wait and try again

### Issue 4: "User already registered"
**Cause:** Email already exists
**Solution:** Either:
- Use a different email
- Delete the user from Supabase Auth dashboard
- Try signing in instead

## Checking Supabase Logs

To see exactly what's happening:

1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs
2. Look for recent errors
3. Common error patterns:
   - **SMTP errors** = SMTP configuration issue
   - **Invalid redirect** = URL configuration issue
   - **Rate limit** = Too many attempts
   - **User exists** = Email already registered

## Testing Checklist

Use this checklist to verify everything works:

- [ ] SMTP settings configured and saved
- [ ] Site URL set to `https://souvenirpickers.com`
- [ ] All redirect URLs added (including wildcards)
- [ ] Email provider enabled
- [ ] Test sign-up completed successfully
- [ ] Confirmation email received
- [ ] Email confirmation link works
- [ ] Can sign in after confirmation
- [ ] Password reset email works
- [ ] Password reset flow completes
- [ ] Magic link email works (if using)

## Architecture Overview

### How Authentication Works Now

1. **Sign Up:**
   - User submits email/password
   - Supabase creates auth.users record
   - Supabase sends confirmation email (via your SMTP)
   - User clicks confirmation link
   - Database trigger creates profile automatically
   - User can now sign in

2. **Password Reset:**
   - User requests password reset
   - Supabase sends reset email (via your SMTP)
   - User clicks reset link
   - User enters new password
   - Password updated in Supabase

3. **Magic Link:**
   - User requests magic link
   - Supabase sends magic link email (via your SMTP)
   - User clicks magic link
   - User is signed in automatically

### Database Triggers

- `handle_new_user()` - Automatically creates profile when:
  - User signs up with auto-confirm enabled (immediate)
  - User confirms email (when email confirmation enabled)

### Edge Functions

These handle custom functionality:
- `send-password-reset` - Custom password reset emails
- `send-magic-link-recovery` - Custom magic link emails
- `send-confirmation-email` - Custom confirmation emails

## Next Steps After Configuration

1. **Test thoroughly** using the debug tool
2. **Monitor Auth Logs** for any errors
3. **Customize email templates** for better branding
4. **Set up rate limits** appropriately for your scale
5. **Enable MFA** if needed for additional security

## Support

If you're still experiencing issues:

1. Check the debug tool output for specific errors
2. Review Supabase Auth Logs
3. Verify all configuration steps above
4. Check that SMTP credentials are correct
5. Ensure your domain's DNS is configured properly

## Configuration URLs Quick Reference

- **Project Dashboard:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
- **Auth Settings:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth
- **URL Configuration:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration
- **Email Templates:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates
- **Auth Logs:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs
- **Providers:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/providers

---

**Remember:** The most common cause of 400/401 errors is missing redirect URLs. Make sure ALL redirect URLs are added including the wildcard patterns (`**`).
