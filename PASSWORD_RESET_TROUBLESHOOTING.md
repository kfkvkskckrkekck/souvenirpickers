# Password Reset Email Troubleshooting Guide

## Current Status

The password reset functionality is implemented and working correctly from the application side. However, you're not receiving emails because **Supabase email delivery needs to be configured**.

## Why Emails Aren't Sending

By default, Supabase has limited email delivery capabilities:

1. **Rate Limiting** - Free tier has strict email limits (3-4 emails per hour)
2. **Email Confirmations** - May be disabled or using development mode
3. **SMTP Not Configured** - Production apps need custom SMTP settings

## How to Fix

### Option 1: Check Supabase Email Settings (Quick Fix)

1. Go to your Supabase Dashboard: https://bfqvzxczmvfteqbhgyvx.supabase.co
2. Navigate to **Authentication → Email Templates**
3. Look for **"Reset Password"** template
4. Make sure it's **enabled**
5. Click **"Send Test Email"** to verify it works

### Option 2: Enable Email Auth (If Disabled)

1. Go to **Authentication → Providers**
2. Make sure **Email** is enabled
3. Check **"Enable email confirmations"** if needed
4. Save changes

### Option 3: Configure Custom SMTP (Recommended for Production)

For reliable email delivery, configure a custom SMTP provider:

1. Go to **Project Settings → Auth → SMTP Settings**
2. Choose an SMTP provider:
   - **SendGrid** (Free tier: 100 emails/day)
   - **Mailgun** (Free tier: 1000 emails/month)
   - **AWS SES** (Very cheap, high volume)
   - **Gmail SMTP** (For testing only)

3. Enter SMTP credentials:
   ```
   Host: smtp.sendgrid.net (or your provider)
   Port: 587
   Username: apikey
   Password: [Your API key]
   Sender Email: noreply@yourdomain.com
   Sender Name: LiveSouvenir
   ```

4. Test the configuration

### Option 4: Check Supabase Logs

1. Go to **Project Settings → API → Logs**
2. Filter by **"Auth"**
3. Look for password reset requests
4. Check for any error messages

## Testing the Current Implementation

### Step 1: Open Browser Console

1. Open your app in a browser
2. Press **F12** to open Developer Tools
3. Click on the **Console** tab

### Step 2: Trigger Password Reset

1. Click **"Forgot Password?"**
2. Enter a valid email address (one that exists in your database)
3. Click **"Send Reset Link"**

### Step 3: Check Console Output

You should see detailed logs like:
```
Starting password reset for: user@example.com
User lookup result: User found
Sending password reset email via Supabase auth...
✅ Password reset email request successful!
Response data: {}
⚠️ Note: If you do not receive an email:
1. Check your spam/junk folder
2. Verify email settings in Supabase dashboard...
```

If you see errors, they will help identify the issue.

## Common Issues

### Issue: "Email not found in database"

**Solution**: The email address doesn't exist in your system. Try with one of these emails from your database:
- costin@emagbirotica.ro
- cristi.tenea@officetooffice.ro
- cristi.tenea10@gmail.com

### Issue: "Rate limit exceeded"

**Solution**: Supabase free tier limits emails. Wait 1 hour and try again, or upgrade your plan.

### Issue: "SMTP not configured"

**Solution**: Configure custom SMTP (see Option 3 above)

### Issue: Email goes to spam

**Solution**:
1. Check spam/junk folder
2. Add noreply@mail.app.supabase.co to your contacts
3. Configure custom domain SMTP for production

## Temporary Workaround (Development Only)

Since emails may not be working, here's a manual password reset using SQL:

```sql
-- Update password directly in database (DEVELOPMENT ONLY)
-- Replace 'user@example.com' with actual email
-- Replace 'newpassword123' with desired password

UPDATE auth.users
SET encrypted_password = crypt('newpassword123', gen_salt('bf'))
WHERE email = 'user@example.com';
```

**⚠️ WARNING**: This bypasses security. Only use for development/testing!

## What Works Now

1. ✅ Password reset form with validation
2. ✅ Email existence check (secure)
3. ✅ Reset link generation
4. ✅ Password reset page
5. ✅ New password validation
6. ✅ Auto-logout after reset
7. ✅ Detailed error logging

## What Needs Configuration

1. ❌ Email delivery (Supabase settings)
2. ❌ Custom SMTP (for production)
3. ❌ Email templates customization (optional)

## Next Steps

1. **Immediate**: Check Supabase dashboard email settings
2. **Short-term**: Test with the browser console to verify API calls work
3. **Production**: Set up custom SMTP provider
4. **Optional**: Customize email templates with your branding

## Support Resources

- Supabase Auth Docs: https://supabase.com/docs/guides/auth
- SMTP Setup Guide: https://supabase.com/docs/guides/auth/auth-smtp
- Email Templates: https://supabase.com/docs/guides/auth/auth-email-templates

## Contact

If you continue to have issues after following this guide, check:
1. Browser console for specific error messages
2. Supabase dashboard logs
3. Supabase support for email configuration help
