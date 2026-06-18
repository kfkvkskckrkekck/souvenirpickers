# Supabase Email Template Fix Guide

## Problem
Email template parsing errors in Supabase auth logs, preventing signup confirmation and password reset emails from being sent correctly.

## Solution: Configure Email Templates in Supabase Dashboard

### Step 1: Access Email Templates

1. Go to https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates
2. You'll see templates for:
   - Confirm signup
   - Magic Link
   - Change Email Address
   - Reset Password

### Step 2: Fix "Confirm Signup" Template

Replace the existing template with this **working** template:

```html
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Confirm your email</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      background-color: #f5f5f5;
    }
    .container {
      background: white;
      border-radius: 12px;
      overflow: hidden;
      margin: 20px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #2563eb 0%, #f97316 100%);
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: 700;
    }
    .content {
      padding: 40px 30px;
    }
    .button {
      display: inline-block;
      background: #2563eb;
      color: white !important;
      padding: 14px 32px;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      margin: 20px 0;
    }
    .button-container {
      text-align: center;
      margin: 30px 0;
    }
    .footer {
      background: #f8fafc;
      padding: 30px;
      text-align: center;
      color: #64748b;
      font-size: 14px;
    }
    .notice {
      background: #fef3c7;
      border-left: 4px solid #f59e0b;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #92400e;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 Welcome to SouvenirPickers!</h1>
    </div>
    <div class="content">
      <h2 style="color: #333; margin-bottom: 20px;">Confirm Your Email Address</h2>
      <p style="font-size: 16px; color: #555; margin-bottom: 20px;">
        Thank you for signing up! Click the button below to verify your email address and activate your account.
      </p>
      <div class="button-container">
        <a href="{{ .ConfirmationURL }}" class="button">Confirm Email Address</a>
      </div>
      <div class="notice">
        <p><strong>⚠️ Security Notice:</strong></p>
        <p>This link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.</p>
      </div>
      <p style="font-size: 14px; color: #666; margin-top: 30px;">
        If the button doesn't work, copy and paste this link into your browser:
        <br><br>
        <span style="font-size: 12px; color: #999; word-break: break-all;">{{ .ConfirmationURL }}</span>
      </p>
    </div>
    <div class="footer">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <p style="margin-top: 15px;">
        Need help? Contact us at support@souvenirpickers.com
      </p>
    </div>
  </div>
</body>
</html>
```

### Step 3: Fix "Reset Password" Template

Replace the password reset template with:

```html
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Reset Your Password</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      background-color: #f5f5f5;
    }
    .container {
      background: white;
      border-radius: 12px;
      overflow: hidden;
      margin: 20px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #f97316 0%, #dc2626 100%);
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: 700;
    }
    .content {
      padding: 40px 30px;
    }
    .button {
      display: inline-block;
      background: #f97316;
      color: white !important;
      padding: 14px 32px;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      margin: 20px 0;
    }
    .button-container {
      text-align: center;
      margin: 30px 0;
    }
    .footer {
      background: #f8fafc;
      padding: 30px;
      text-align: center;
      color: #64748b;
      font-size: 14px;
    }
    .notice {
      background: #fee2e2;
      border-left: 4px solid #ef4444;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #991b1b;
    }
    .info {
      background: #dbeafe;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #1e40af;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔒 Reset Your Password</h1>
    </div>
    <div class="content">
      <h2 style="color: #333; margin-bottom: 20px;">Password Reset Request</h2>
      <p style="font-size: 16px; color: #555; margin-bottom: 20px;">
        We received a request to reset your password. Click the button below to create a new password.
      </p>
      <div class="button-container">
        <a href="{{ .ConfirmationURL }}" class="button">Reset Password</a>
      </div>
      <div class="info">
        <strong>⏰ This link expires in 1 hour</strong>
      </div>
      <div class="notice">
        <p><strong>⚠️ Didn't request this?</strong></p>
        <p>If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
      </div>
      <p style="font-size: 14px; color: #666; margin-top: 30px;">
        If the button doesn't work, copy and paste this link into your browser:
        <br><br>
        <span style="font-size: 12px; color: #999; word-break: break-all;">{{ .ConfirmationURL }}</span>
      </p>
    </div>
    <div class="footer">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <p style="margin-top: 15px;">
        Need help? Contact us at support@souvenirpickers.com
      </p>
    </div>
  </div>
</body>
</html>
```

### Step 4: Fix "Magic Link" Template

Replace the magic link template with:

```html
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <title>Your Magic Link</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      background-color: #f5f5f5;
    }
    .container {
      background: white;
      border-radius: 12px;
      overflow: hidden;
      margin: 20px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #8b5cf6 0%, #3b82f6 100%);
      color: white;
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: 700;
    }
    .content {
      padding: 40px 30px;
    }
    .button {
      display: inline-block;
      background: #8b5cf6;
      color: white !important;
      padding: 14px 32px;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      margin: 20px 0;
    }
    .button-container {
      text-align: center;
      margin: 30px 0;
    }
    .footer {
      background: #f8fafc;
      padding: 30px;
      text-align: center;
      color: #64748b;
      font-size: 14px;
    }
    .notice {
      background: #fef3c7;
      border-left: 4px solid #f59e0b;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #92400e;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✨ Your Magic Link</h1>
    </div>
    <div class="content">
      <h2 style="color: #333; margin-bottom: 20px;">Sign In to SouvenirPickers</h2>
      <p style="font-size: 16px; color: #555; margin-bottom: 20px;">
        Click the button below to sign in to your account. No password needed!
      </p>
      <div class="button-container">
        <a href="{{ .ConfirmationURL }}" class="button">Sign In Now</a>
      </div>
      <div class="notice">
        <p><strong>⚠️ Security Notice:</strong></p>
        <p>This link will expire in 1 hour. If you didn't request this link, please ignore this email.</p>
      </div>
      <p style="font-size: 14px; color: #666; margin-top: 30px;">
        If the button doesn't work, copy and paste this link into your browser:
        <br><br>
        <span style="font-size: 12px; color: #999; word-break: break-all;">{{ .ConfirmationURL }}</span>
      </p>
    </div>
    <div class="footer">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <p style="margin-top: 15px;">
        Need help? Contact us at support@souvenirpickers.com
      </p>
    </div>
  </div>
</body>
</html>
```

## Important Template Variables

Supabase provides these template variables that MUST be used exactly as shown:

- `{{ .ConfirmationURL }}` - The action link (signup confirmation, password reset, magic link)
- `{{ .Token }}` - The raw token (rarely used)
- `{{ .TokenHash }}` - The hashed token (rarely used)
- `{{ .SiteURL }}` - Your site URL from Supabase settings

## Common Template Errors to Avoid

1. ❌ **Don't use:** `{.ConfirmationURL}` (single braces)
2. ❌ **Don't use:** `{{ .ConfirmationUrl }}` (wrong capitalization)
3. ❌ **Don't use:** Unescaped HTML characters in template variables
4. ❌ **Don't use:** JavaScript in email templates (most email clients block it)
5. ✅ **Always use:** `{{ .ConfirmationURL }}` (double braces, exact capitalization)

## Testing Email Templates

After updating the templates:

1. Save each template in Supabase Dashboard
2. Test signup: Create a new account and check if you receive the confirmation email
3. Test password reset: Click "Forgot Password" and verify you receive the reset email
4. Check spam folder if emails don't arrive
5. Monitor auth logs: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs

## Verification Checklist

- [ ] All templates use `{{ .ConfirmationURL }}` with correct syntax
- [ ] No parsing errors in auth logs
- [ ] Signup confirmation emails arrive
- [ ] Password reset emails arrive
- [ ] Magic link emails arrive (if using magic link login)
- [ ] Links in emails work correctly
- [ ] Emails display properly in Gmail, Outlook, Apple Mail

## Additional Configuration

### Email Rate Limiting
- Maximum 4 emails per hour per user (Supabase default)
- If you need more, configure in Authentication > Email Rate Limits

### SMTP Configuration
If custom SMTP is configured, ensure these secrets are set:
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM`

## Support

If issues persist after fixing templates:
1. Check Supabase auth logs for specific error messages
2. Verify SMTP configuration if using custom SMTP
3. Test with default Supabase templates first
4. Contact Supabase support if template parsing errors continue
