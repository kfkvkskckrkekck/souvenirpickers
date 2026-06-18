# Password Reset Email Configuration Guide

## Current Status

The password reset system has been updated with improved error handling and diagnostics. However, to send emails, you need to configure SMTP settings in Supabase.

## Why Emails Aren't Being Sent

The password reset edge function requires SMTP (email server) credentials to send emails. Without these credentials, the function cannot deliver password reset emails to users.

## How to Configure SMTP in Supabase

### Step 1: Get Your SMTP Credentials

You'll need the following information from your email provider:

- **SMTP Host**: Your email server address (e.g., `mail.yourdomain.com`)
- **SMTP Port**: Usually `587` (STARTTLS) or `465` (SSL)
- **SMTP User**: Your email address (e.g., `noreply@souvenirpickers.com`)
- **SMTP Password**: Your email account password
- **SMTP From**: The sender email address (usually same as SMTP User)

#### Common Email Providers:

**Bluehost:**
- Host: `mail.yourdomain.com` (replace with your domain)
- Port: `587` or `465`
- User: Your full email address
- Password: Your email password

**Gmail:**
- Host: `smtp.gmail.com`
- Port: `587`
- User: Your Gmail address
- Password: App-specific password (not your regular password)
- Note: You must enable 2FA and generate an app password

**SendGrid:**
- Host: `smtp.sendgrid.net`
- Port: `587`
- User: `apikey`
- Password: Your SendGrid API key

### Step 2: Add SMTP Secrets to Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `bfqvzxczmvfteqbhgyvx`
3. Navigate to **Edge Functions** in the left sidebar
4. Find the **send-password-reset-email** function
5. Click on it to open the function details
6. Click on **Secrets** tab
7. Add the following secrets (click **Add Secret** for each):

   ```
   SMTP_HOST = mail.yourdomain.com
   SMTP_PORT = 587
   SMTP_USER = noreply@souvenirpickers.com
   SMTP_PASS = your_email_password
   SMTP_FROM = noreply@souvenirpickers.com
   ```

8. Save each secret

### Step 3: Test the Password Reset

After configuring SMTP, test the password reset functionality:

#### Option 1: Use the Diagnostic Tool
1. Open the test page: `/test-password-reset-live.html`
2. Enter an email address
3. Click "Send Password Reset Email"
4. The diagnostic will show you detailed results

#### Option 2: Use the Main App
1. Go to your app: https://souvenirpickers.com
2. Click "Forgot Password?"
3. Enter your email
4. Click "Send Reset Link"
5. Check your email for the password reset link

## Troubleshooting

### Email Not Received

1. **Check spam folder**: Password reset emails may be filtered as spam
2. **Verify SMTP credentials**: Make sure all credentials are correct
3. **Check edge function logs**:
   - Go to Supabase Dashboard > Edge Functions > send-password-reset-email
   - Click on **Logs** tab
   - Look for error messages
4. **Test SMTP connection**: Use the diagnostic tool at `/test-password-reset-live.html`

### Common Errors

**"SMTP configuration incomplete"**
- One or more SMTP secrets are missing
- Go to Edge Functions > Secrets and add the missing values

**"Authentication failed"**
- SMTP username or password is incorrect
- For Gmail, you need an app-specific password, not your regular password

**"Connection timeout"**
- SMTP host or port is incorrect
- Check with your email provider for the correct settings

**"535 Authentication Failed"**
- Password is incorrect
- For some providers, you need to enable "less secure app access"

### Alternative: Use Supabase's Built-in Email Service

If you don't want to set up SMTP, you can use Supabase's built-in email service:

1. Go to Supabase Dashboard > Authentication > Email Templates
2. Supabase will send emails automatically using their servers
3. Configure the email templates for password reset

However, using your own SMTP server gives you:
- Custom sender email address
- Better email deliverability
- Full control over email content
- Professional branded emails

## Testing Checklist

- [ ] SMTP secrets added to Supabase Edge Function
- [ ] Test password reset from diagnostic tool
- [ ] Test password reset from main app
- [ ] Verify email is received (check spam)
- [ ] Click reset link and successfully change password
- [ ] Verify can login with new password

## Support

If you continue to have issues:

1. Check the edge function logs in Supabase Dashboard
2. Use the diagnostic tool to get detailed error messages
3. Verify your SMTP credentials with your email provider
4. Consider using a dedicated email service like SendGrid or Mailgun for better deliverability

## Next Steps

Once SMTP is configured:
1. Test password reset thoroughly
2. Consider adding email templates for other notifications
3. Monitor email deliverability in your SMTP provider's dashboard
4. Set up SPF, DKIM, and DMARC records for your domain to improve email deliverability
