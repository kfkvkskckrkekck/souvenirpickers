# 🔧 Restore Default Email Templates - Complete Guide

## Overview

This guide will help you restore the default Supabase email templates to fix signup confirmation emails.

---

## Step 1: Access Email Templates in Supabase

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard/project/gejhwupzezmuektmaiyg)
2. Click **Authentication** (shield icon) in the left sidebar
3. Click **Email Templates**

You should see 4 email template types:
- **Confirm signup** - Sent when users sign up
- **Invite user** - Sent when admins invite users
- **Magic Link** - Sent for passwordless login
- **Change Email Address** - Sent when users change their email
- **Reset Password** - Sent for password resets

---

## Step 2: Default Email Templates

Copy these default templates into your Supabase dashboard.

### 1. Confirm Signup Template

**Subject:**
```
Confirm Your Signup
```

**Body (HTML):**
```html
<h2>Confirm your signup</h2>

<p>Follow this link to confirm your user:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm your email address</a></p>

<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
```

---

### 2. Invite User Template

**Subject:**
```
You have been invited
```

**Body (HTML):**
```html
<h2>You have been invited</h2>

<p>You have been invited to create a user on {{ .SiteURL }}.</p>
<p>Follow this link to accept the invite:</p>
<p><a href="{{ .ConfirmationURL }}">Accept the invite</a></p>

<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
```

---

### 3. Magic Link Template

**Subject:**
```
Your Magic Link
```

**Body (HTML):**
```html
<h2>Magic Link</h2>

<p>Follow this link to login:</p>
<p><a href="{{ .ConfirmationURL }}">Log In</a></p>

<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
```

---

### 4. Change Email Address Template

**Subject:**
```
Confirm Change of Email
```

**Body (HTML):**
```html
<h2>Confirm Change of Email</h2>

<p>Follow this link to confirm the update of your email from {{ .Email }} to {{ .NewEmail }}:</p>
<p><a href="{{ .ConfirmationURL }}">Change Email</a></p>

<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
```

---

### 5. Reset Password Template

**Subject:**
```
Reset Your Password
```

**Body (HTML):**
```html
<h2>Reset Password</h2>

<p>Follow this link to reset the password for your user:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>

<p>Or copy and paste this URL into your browser:</p>
<p>{{ .ConfirmationURL }}</p>
```

---

## Step 3: Configure Redirect URLs

After updating templates, configure your redirect URLs:

1. In Supabase Dashboard, go to **Authentication** → **URL Configuration**

2. Add these redirect URLs:
   ```
   https://www.souvenirpickers.com/*
   https://souvenirpickers.com/*
   http://localhost:5173/*
   ```

3. Set **Site URL** to:
   ```
   https://www.souvenirpickers.com
   ```

4. Click **Save**

---

## Step 4: Configure SMTP (Required for Emails to Send)

You mentioned having a Resend token. Here's how to configure it:

### Option A: Using Resend SMTP

1. Go to **Settings** → **Authentication**
2. Scroll to **SMTP Settings**
3. Click **Enable Custom SMTP**
4. Enter:
   ```
   Sender email: noreply@souvenirpickers.com
   Sender name: SouvenirPickers

   Host: smtp.resend.com
   Port: 587
   Username: resend
   Password: [Your Resend API Key]

   Minimum interval: 60
   ```
5. Click **Save**

### Option B: Using Edge Function (Alternative)

If you prefer to use an edge function with Resend API directly, I can create that for you.

---

## Step 5: Enable Email Confirmation

1. Go to **Authentication** → **Providers** → **Email**
2. Make sure **"Enable email confirmations"** is **ON** ✅
3. Click **Save**

---

## Step 6: Test the Setup

### Test 1: Using the Diagnostic Tool

1. Open: https://souvenirpickers.com/test-signup-final.html
2. Enter a **real email address you can access**
3. Click "Test Signup"
4. Check your email inbox (and spam folder!)
5. Click the confirmation link

### Test 2: Using the Main Site

1. Go to www.souvenirpickers.com
2. Click **SIGN UP**
3. Enter your details with a **real email**
4. Click **CREATE ACCOUNT**
5. Check your email for confirmation
6. Click the link to confirm
7. You should be logged in!

---

## Step 7: Verify Email Was Sent

Check Supabase logs to verify emails are being sent:

1. Go to **Logs** → **Auth Logs** in Supabase Dashboard
2. Look for entries like "email sent" or "confirmation email"
3. If you see errors, they'll appear here

---

## Alternative: Disable Email Confirmation (Quick Fix)

If you want users to sign up immediately without email confirmation:

1. Go to **Authentication** → **Providers** → **Email**
2. **Disable** "Enable email confirmations" ❌
3. Click **Save**

Users can now sign up instantly without needing to confirm their email.

---

## Troubleshooting

### Issue: Emails still not being sent

**Possible causes:**
1. SMTP credentials incorrect
2. Resend account not verified
3. Email domain not verified in Resend
4. Rate limit exceeded

**Solutions:**
1. Double-check SMTP settings
2. Verify your Resend account
3. Add and verify your domain in Resend
4. Wait 60 seconds between tests

### Issue: Emails going to spam

**Solutions:**
1. Verify your domain in Resend
2. Add SPF, DKIM, DMARC records to your DNS
3. Use a verified sender email
4. Ask users to check spam folder

### Issue: Confirmation link doesn't work

**Possible causes:**
1. Redirect URLs not configured
2. Wrong Site URL
3. Link expired (links expire after 24 hours)

**Solutions:**
1. Add all redirect URLs (see Step 3)
2. Set correct Site URL
3. Request new confirmation email

---

## Enhanced Email Templates (Optional)

For a better user experience, you can use these enhanced templates:

### Enhanced Confirm Signup Template

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Confirm Your Email</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f4f4; padding: 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px; font-weight: bold;">Welcome to SouvenirPickers! 🎉</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Confirm Your Email Address</h2>

              <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
                Thanks for signing up! We're excited to have you on board.
                Please confirm your email address to get started.
              </p>

              <table cellpadding="0" cellspacing="0" style="margin: 30px 0;">
                <tr>
                  <td style="border-radius: 6px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
                    <a href="{{ .ConfirmationURL }}" style="display: inline-block; padding: 16px 32px; color: #ffffff; text-decoration: none; font-weight: bold; font-size: 16px;">
                      Confirm Email Address
                    </a>
                  </td>
                </tr>
              </table>

              <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
                Or copy and paste this URL into your browser:
              </p>
              <p style="color: #667eea; font-size: 12px; word-break: break-all; margin: 10px 0;">
                {{ .ConfirmationURL }}
              </p>

              <hr style="border: none; border-top: 1px solid #eeeeee; margin: 30px 0;">

              <p style="color: #999999; font-size: 12px; line-height: 1.6; margin: 0;">
                This link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
              <p style="color: #999999; font-size: 12px; margin: 0;">
                © 2024 SouvenirPickers. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## Summary

1. ✅ Copy default templates into Supabase Dashboard
2. ✅ Configure redirect URLs
3. ✅ Set up SMTP with Resend
4. ✅ Enable email confirmation
5. ✅ Test with real email
6. ✅ Verify emails are being sent

**Once configured, your signup flow will work properly with email confirmation!**
