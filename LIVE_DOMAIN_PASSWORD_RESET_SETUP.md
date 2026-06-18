# Password Reset Setup for www.souvenirpickers.com

## Overview
This guide will help you enable password reset functionality on your live domain www.souvenirpickers.com.

---

## Step 1: Deploy Updated Frontend

Your React app has been built with all password reset fixes included:
- Dynamic redirect URLs that work with any domain
- Enhanced token detection for reset links
- Proper session validation

### Download Deployment Package

The deployment package is ready: `souvenirpickers-password-reset-fix.tar.gz`

### Upload to Your Web Server

1. **Download the package** from your project directory
2. **Connect to your web server** (via FTP, cPanel File Manager, or SSH)
3. **Navigate to your website's root directory** (usually `public_html` or `www`)
4. **Extract the package**:
   ```bash
   tar -xzf souvenirpickers-password-reset-fix.tar.gz
   ```

The package includes:
- `index.html` (entry point)
- `assets/` folder (all compiled JS and CSS)
- `_redirects` (for SPA routing)
- All necessary static files

---

## Step 2: Configure Supabase Redirect URLs

This is **CRITICAL** for password reset to work!

### Access Supabase Dashboard

1. Go to: **https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration**

   OR navigate manually:
   - Go to https://supabase.com/dashboard
   - Click your project: `bfqvzxczmvfteqbhgyvx`
   - Click **Authentication** (shield icon) in left sidebar
   - Click **URL Configuration**

### Configure Site URL

Set the **Site URL** to:
```
https://www.souvenirpickers.com
```

### Add Redirect URLs

In the **Redirect URLs** section, add these URLs (one per line):

```
https://www.souvenirpickers.com
https://souvenirpickers.com
https://www.souvenirpickers.com/*
https://souvenirpickers.com/*
```

**Why both versions?**
- Some users may access via `www.souvenirpickers.com`
- Others may use `souvenirpickers.com` (without www)
- The wildcards (`/*`) allow any path on your domain

### Save Configuration

Click **Save** at the bottom of the page.

---

## Step 3: Test Password Reset Flow

### 3.1 Request Password Reset

1. Go to **https://www.souvenirpickers.com**
2. Click **"Forgot Password?"** on the login page
3. Enter your email address
4. Click **"Send Reset Link"**

You should see: "If an account exists with this email, you will receive a password reset link."

### 3.2 Check Your Email

1. Check your inbox for an email from Supabase
2. Subject: "Reset Your Password" (or similar)
3. **Check spam folder** if you don't see it

### 3.3 Click Reset Link

The email will contain a link like:
```
https://www.souvenirpickers.com/#access_token=...&type=recovery
```

1. Click the link
2. You should be redirected to www.souvenirpickers.com
3. The app will automatically detect the reset token
4. You'll see a "Reset Your Password" form

### 3.4 Set New Password

1. Enter your new password (minimum 8 characters)
2. Confirm the password
3. Click **"Reset Password"**
4. You'll be logged out automatically
5. Log in with your new password

---

## How It Works

1. **User clicks "Forgot Password"**
   - App checks if email exists (without revealing this to user)
   - Calls Supabase `resetPasswordForEmail()`

2. **Supabase sends email**
   - Email contains magic link with recovery token
   - Link redirects to `window.location.origin` (your current domain)

3. **User clicks link in email**
   - Browser opens: `https://www.souvenirpickers.com/#type=recovery&access_token=...`
   - App detects `type=recovery` in URL
   - Shows password reset form

4. **User enters new password**
   - App validates password strength
   - Calls Supabase `updateUser()` with new password
   - Logs user out for security
   - Redirects to login page

---

## Troubleshooting

### Issue: "Not receiving reset email"

**Solutions:**
1. Check spam/junk folder
2. Wait 60 seconds between requests (rate limiting)
3. Verify the email exists in your database
4. Check Supabase email settings:
   - Go to **Authentication → Email Templates**
   - Make sure "Reset Password" template is enabled

### Issue: "Invalid or expired reset link"

**Solutions:**
1. Reset links expire after 1 hour
2. Request a new password reset
3. Don't click the link multiple times (tokens are single-use)

### Issue: "Reset link redirects to wrong domain"

**Solutions:**
1. Verify you added your domain to Supabase redirect URLs
2. Make sure you saved the configuration
3. Try clearing browser cache
4. Use incognito/private browsing to test

### Issue: Reset button doesn't work

**Solutions:**
1. Open browser console (F12)
2. Look for error messages
3. Verify you deployed the latest build
4. Check that all files in the `dist/` folder were uploaded

---

## Email Configuration (Optional)

For better email deliverability in production:

### Configure Custom SMTP

1. Go to **Project Settings → Auth → SMTP Settings** in Supabase
2. Choose a provider:
   - **SendGrid** (Free: 100 emails/day)
   - **Mailgun** (Free: 1,000 emails/month)
   - **AWS SES** (Very cheap, high volume)

3. Enter SMTP credentials:
   ```
   Host: smtp.yousprovider.com
   Port: 587
   Username: [Your username/apikey]
   Password: [Your password/API key]
   Sender Email: noreply@souvenirpickers.com
   Sender Name: Souvenir Pickers
   ```

4. Click **Save**
5. Send a test email to verify

### Customize Email Template

1. Go to **Authentication → Email Templates**
2. Select "Reset Password"
3. Customize:
   - Subject line
   - Email body
   - Button text
   - Add your logo
4. Use your brand colors
5. Click **Save**

---

## Security Notes

- Reset links expire after 1 hour
- Links can only be used once
- User is automatically logged out after password change
- Rate limiting: 1 request per minute per email
- All password reset requests are logged in Supabase

---

## Quick Reference

**Deployment Package:** `souvenirpickers-password-reset-fix.tar.gz`

**Supabase Project ID:** `bfqvzxczmvfteqbhgyvx`

**Configuration URL:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

**Required Redirect URLs:**
- https://www.souvenirpickers.com
- https://souvenirpickers.com
- https://www.souvenirpickers.com/*
- https://souvenirpickers.com/*

**Test Email Addresses** (from your database):
- costin@emagbirotica.ro
- cristi.tenea@officetooffice.ro
- cristi.tenea10@gmail.com

---

## Support

If you encounter issues:

1. Check browser console for errors (F12)
2. Check Supabase logs: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs
3. Verify deployment: View source on www.souvenirpickers.com to confirm latest files
4. Test with different email addresses

---

## Summary

✅ **Frontend built** with password reset fixes
✅ **Deployment package ready** for upload
✅ **Edge functions active** on Supabase
⚠️ **Action required:** Configure Supabase redirect URLs (Step 2)
⚠️ **Action required:** Deploy frontend to www.souvenirpickers.com (Step 1)

Once completed, password reset will work perfectly on your live domain!
