# Password Reset - Ready to Test

The password reset system is now configured and ready for testing with the **correct Supabase project** (`bfqvzxczmvfteqbhgyvx`).

## What's Been Fixed

### 1. Configuration Safeguards
- ✅ Removed all hardcoded fallback URLs
- ✅ Added runtime validation in `src/lib/supabase.ts`
- ✅ Added build-time validation script
- ✅ App will crash immediately if wrong project is detected
- ✅ `.env` file updated with correct project credentials

### 2. Password Reset System
- ✅ Edge function `send-password-reset` is deployed and active
- ✅ Uses Bluehost SMTP for email delivery
- ✅ Professional HTML email template
- ✅ Reset link redirects to `/reset-password`
- ✅ Frontend handles token validation and password updates

### 3. Test Tools Created
- ✅ `public/test-password-reset-final.html` - Complete password reset test
- ✅ `public/check-smtp-config.html` - SMTP configuration checker
- ✅ `test-smtp-secret` edge function deployed

## Testing Instructions

### Step 1: Check SMTP Configuration

**IMPORTANT:** Password reset requires SMTP secrets to be configured in Supabase.

1. Open: `http://localhost:5173/check-smtp-config.html` (or deployed URL)
2. Click "Check SMTP Configuration"
3. Verify all 5 SMTP secrets are found

**If any secrets are missing:**
1. Go to [Supabase Dashboard → Edge Functions](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/functions)
2. Click "Manage Secrets"
3. Add these secrets from your `.env` file:
   - `SMTP_HOST` = mail.souvenirpicker.com
   - `SMTP_PORT` = 587
   - `SMTP_USER` = support@souvenirpickers.com
   - `SMTP_PASS` = (your password from .env)
   - `SMTP_FROM` = support@souvenirpickers.com

### Step 2: Test Password Reset Flow

1. **Open Test Page:**
   - URL: `http://localhost:5173/test-password-reset-final.html`
   - Or deployed: `https://souvenirpickers.com/test-password-reset-final.html`

2. **Configuration Check:**
   - Page will automatically verify the correct Supabase project is being used
   - All checks should pass with green checkmarks

3. **Send Reset Email:**
   - Enter a valid email address (must be a user in your database)
   - Click "Send Password Reset Email"
   - Should see success message

4. **Check Your Email:**
   - Look for email from "SouvenirPickers Support"
   - Subject: "Reset Your Password - SouvenirPickers"
   - Check spam/junk folder if not in inbox

5. **Complete Password Reset:**
   - Click "Reset Password Now" button in email
   - Should redirect to `/reset-password` page
   - Enter new password (min 6 characters)
   - Confirm new password
   - Click "Reset Password"

6. **Verify Success:**
   - Should see success message
   - Automatically redirected to login page
   - Try logging in with new password

### Step 3: Test From Main App

1. Go to main login page
2. Click "Forgot Password?"
3. Enter your email
4. Submit and check email
5. Follow reset link
6. Complete password reset

## Password Reset Flow

```
User clicks "Forgot Password"
    ↓
Frontend calls edge function:
  /functions/v1/send-password-reset
    ↓
Edge function:
  1. Generates recovery link via Supabase Admin API
  2. Sends email via Bluehost SMTP
  3. Returns success/error
    ↓
User receives email with reset link
    ↓
User clicks "Reset Password Now"
    ↓
Redirected to /reset-password with token in URL
    ↓
Frontend validates token and sets session
    ↓
User enters new password
    ↓
Password updated via supabase.auth.updateUser()
    ↓
User logged out and redirected to login
```

## Email Template

The reset email includes:
- Professional design with SouvenirPickers branding
- Large "Reset Password Now" button
- Security notice
- Expiry warning (1 hour)
- Fallback plain text link
- Support contact information

## Error Handling

The system handles:
- ✅ Invalid email addresses
- ✅ Non-existent users
- ✅ Expired reset links
- ✅ SMTP configuration issues
- ✅ Network errors
- ✅ Password validation errors

## Verification Checklist

Before considering password reset complete:

- [ ] SMTP secrets configured in Supabase
- [ ] `test-smtp-secret` function returns all secrets found
- [ ] Test email sent successfully
- [ ] Email received in inbox (or spam)
- [ ] Reset link redirects to correct page
- [ ] New password accepted and updated
- [ ] Can log in with new password
- [ ] Old password no longer works

## Common Issues

### Email Not Received
1. Check spam/junk/promotions folder
2. Verify SMTP secrets are configured
3. Check email address is valid and exists in database
4. Check Supabase logs for errors

### Reset Link Doesn't Work
1. Link expires after 1 hour
2. Check redirect URL is correct
3. Verify session handling in frontend
4. Check browser console for errors

### Password Update Fails
1. Verify password meets minimum requirements (6 characters)
2. Check passwords match
3. Ensure session is valid
4. Check browser console for errors

## Project Safety

With the new configuration safeguards:
- ❌ Cannot accidentally use wrong Supabase project
- ✅ Build fails if wrong project detected
- ✅ App crashes on load if wrong project configured
- ✅ Clear error messages indicate exact problem

To verify project at any time:
```bash
npm run validate
```

## Support

If issues persist:
1. Check Supabase Dashboard logs
2. Check browser console for errors
3. Verify edge function is deployed
4. Test SMTP configuration
5. Review `.env` file for correct values

## Next Steps

After successful testing:
1. Deploy to production
2. Test on live domain
3. Verify production SMTP settings
4. Test with real user accounts
5. Monitor email delivery rates
