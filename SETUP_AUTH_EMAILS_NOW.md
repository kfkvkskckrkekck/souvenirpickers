# Setup Supabase Auth Email Templates

## The Issue
Supabase auth emails (signup confirmation, password reset) are not properly configured. These templates MUST be set up in your Supabase Dashboard - they cannot be configured via code.

## Quick Fix (5 Minutes)

### Step 1: Configure SMTP Settings
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/settings/auth
2. Scroll to **SMTP Settings**
3. Enable **Enable Custom SMTP**
4. Enter these settings:
   ```
   Sender Name: SouvenirPickers
   Sender Email: support@souvenirpickers.com
   Host: mail.souvenirpickers.com
   Port: 587
   Username: support@souvenirpickers.com
   Password: Laur197511$
   ```
5. Click **Save**

### Step 2: Configure Email Templates
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/auth/templates
2. You'll see 4 templates to configure:
   - **Confirm signup**
   - **Reset password**
   - **Magic Link**
   - **Change Email Address**

### Step 3: Update Each Template

#### Template 1: Confirm Signup
Copy this into the **HTML Body** field:

```html
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); color: white; padding: 40px; text-align: center; border-radius: 12px 12px 0 0;">
    <h1 style="margin: 0; font-size: 28px;">Welcome to SouvenirPickers!</h1>
    <p style="margin-top: 10px; font-size: 16px;">Let's get you started</p>
  </div>

  <div style="padding: 40px; background: white;">
    <p>Thanks for signing up! Please confirm your email address to activate your account:</p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: #2563eb; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600;">Confirm Email Address</a>
    </div>

    <p style="font-size: 14px; color: #64748b;">If the button doesn't work, copy this link:<br>
    <span style="font-size: 12px; word-break: break-all;">{{ .ConfirmationURL }}</span></p>
  </div>

  <div style="background: #f8fafc; padding: 20px; text-align: center; font-size: 13px; color: #64748b; border-radius: 0 0 12px 12px;">
    <p><strong>SouvenirPickers</strong><br>Connecting Collectors with Local Pickers</p>
  </div>
</body>
</html>
```

#### Template 2: Reset Password
Copy this into the **HTML Body** field:

```html
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); color: white; padding: 40px; text-align: center; border-radius: 12px 12px 0 0;">
    <h1 style="margin: 0; font-size: 28px;">Reset Your Password</h1>
  </div>

  <div style="padding: 40px; background: white;">
    <p>We received a request to reset your password. Click the button below to create a new password:</p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: #2563eb; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600;">Reset Password</a>
    </div>

    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; margin: 20px 0; border-radius: 4px;">
      <p style="margin: 0; font-size: 14px; color: #92400e;"><strong>Security Note:</strong> This link expires in 1 hour. If you didn't request this, please ignore this email.</p>
    </div>

    <p style="font-size: 14px; color: #64748b;">If the button doesn't work, copy this link:<br>
    <span style="font-size: 12px; word-break: break-all;">{{ .ConfirmationURL }}</span></p>
  </div>

  <div style="background: #f8fafc; padding: 20px; text-align: center; font-size: 13px; color: #64748b; border-radius: 0 0 12px 12px;">
    <p><strong>SouvenirPickers</strong><br>Connecting Collectors with Local Pickers</p>
  </div>
</body>
</html>
```

#### Template 3: Magic Link
Copy this into the **HTML Body** field:

```html
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); color: white; padding: 40px; text-align: center; border-radius: 12px 12px 0 0;">
    <h1 style="margin: 0; font-size: 28px;">Sign In to SouvenirPickers</h1>
  </div>

  <div style="padding: 40px; background: white;">
    <p>Click the button below to sign in to your account:</p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: #2563eb; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600;">Sign In Now</a>
    </div>

    <p style="font-size: 14px; color: #64748b;">If the button doesn't work, copy this link:<br>
    <span style="font-size: 12px; word-break: break-all;">{{ .ConfirmationURL }}</span></p>
  </div>

  <div style="background: #f8fafc; padding: 20px; text-align: center; font-size: 13px; color: #64748b; border-radius: 0 0 12px 12px;">
    <p><strong>SouvenirPickers</strong><br>Connecting Collectors with Local Pickers</p>
  </div>
</body>
</html>
```

#### Template 4: Change Email
Copy this into the **HTML Body** field:

```html
<html>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%); color: white; padding: 40px; text-align: center; border-radius: 12px 12px 0 0;">
    <h1 style="margin: 0; font-size: 28px;">Confirm Email Change</h1>
  </div>

  <div style="padding: 40px; background: white;">
    <p>You requested to change your email address. Click the button below to confirm:</p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{ .ConfirmationURL }}" style="display: inline-block; background: #2563eb; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600;">Confirm Email Change</a>
    </div>

    <p style="font-size: 14px; color: #64748b;">If the button doesn't work, copy this link:<br>
    <span style="font-size: 12px; word-break: break-all;">{{ .ConfirmationURL }}</span></p>
  </div>

  <div style="background: #f8fafc; padding: 20px; text-align: center; font-size: 13px; color: #64748b; border-radius: 0 0 12px 12px;">
    <p><strong>SouvenirPickers</strong><br>Connecting Collectors with Local Pickers</p>
  </div>
</body>
</html>
```

### Step 4: Configure Redirect URLs
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration
2. Add these **Redirect URLs**:
   ```
   https://souvenirpickers.com/auth/callback
   https://souvenirpickers.com/reset-password
   http://localhost:5173/auth/callback
   http://localhost:5173/reset-password
   ```

### Step 5: Test
1. Open: http://localhost:5173/test-email-templates.html
2. Test each email type
3. Check your inbox (and spam folder)

## Important Notes

- These templates use Supabase's built-in variables like `{{ .ConfirmationURL }}`
- DO NOT modify these variable names
- The templates must be set in the Dashboard - they cannot be set via migrations
- SMTP must be configured for emails to send

## Troubleshooting

**Emails not sending?**
1. Verify SMTP credentials in Supabase Dashboard
2. Check that port 587 is open
3. Verify sender email is authorized with BlueHost
4. Check Supabase logs for errors

**Still having issues?**
Contact Supabase support or check the SMTP connection using the test functions in this project.
