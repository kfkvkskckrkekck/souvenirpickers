# 📧 Configure Supabase Email - Complete Setup Guide

## Your SMTP Credentials (From .env)

You already have Bluehost SMTP configured! Here are your credentials:

```
Host: mail.souvenirpickers.com
Port: 587
Username: support@souvenirpickers.com
Password: Laur197511$
From Email: support@souvenirpickers.com
```

---

## Step-by-Step Configuration

### 1. Configure SMTP in Supabase Dashboard

1. Go to [Supabase Settings](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth)

2. Click **Settings** (gear icon) → **Authentication**

3. Scroll down to **"SMTP Settings"**

4. Click **"Enable Custom SMTP"**

5. Enter these exact values:

   ```
   Sender email: support@souvenirpickers.com
   Sender name: SouvenirPickers

   Host: mail.souvenirpickers.com
   Port number: 587
   Username: support@souvenirpickers.com
   Password: Laur197511$

   Minimum interval between emails (seconds): 60
   ```

6. Click **Save**

---

### 2. Configure Email Templates

1. In Supabase Dashboard, go to **Authentication** → **Email Templates**

2. Update each template (see EMAIL_TEMPLATES_RESTORATION.md for full templates)

**Quick templates to copy:**

#### Confirm Signup
**Subject:** `Confirm Your Signup - SouvenirPickers`

**Body:**
```html
<h2>Welcome to SouvenirPickers! 🎉</h2>

<p>Thanks for signing up! Please confirm your email address to get started.</p>

<p><a href="{{ .ConfirmationURL }}" style="display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">Confirm Email Address</a></p>

<p>Or copy and paste this link into your browser:</p>
<p style="word-break: break-all; color: #667eea;">{{ .ConfirmationURL }}</p>

<hr>

<p style="color: #999; font-size: 12px;">This link expires in 24 hours. If you didn't create an account, please ignore this email.</p>
```

#### Reset Password
**Subject:** `Reset Your Password - SouvenirPickers`

**Body:**
```html
<h2>Reset Your Password</h2>

<p>We received a request to reset your password. Click the button below to create a new password:</p>

<p><a href="{{ .ConfirmationURL }}" style="display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">Reset Password</a></p>

<p>Or copy and paste this link into your browser:</p>
<p style="word-break: break-all; color: #667eea;">{{ .ConfirmationURL }}</p>

<hr>

<p style="color: #999; font-size: 12px;">If you didn't request a password reset, please ignore this email. This link expires in 1 hour.</p>
```

#### Magic Link
**Subject:** `Your Magic Link - SouvenirPickers`

**Body:**
```html
<h2>Your Magic Link</h2>

<p>Click the button below to sign in to your account:</p>

<p><a href="{{ .ConfirmationURL }}" style="display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">Sign In</a></p>

<p>Or copy and paste this link into your browser:</p>
<p style="word-break: break-all; color: #667eea;">{{ .ConfirmationURL }}</p>

<hr>

<p style="color: #999; font-size: 12px;">This link expires in 1 hour and can only be used once.</p>
```

---

### 3. Configure Redirect URLs

1. In Supabase Dashboard, go to **Authentication** → **URL Configuration**

2. Set **Site URL** to:
   ```
   https://www.souvenirpickers.com
   ```

3. Under **Redirect URLs**, add these URLs (one per line):
   ```
   https://www.souvenirpickers.com/*
   https://souvenirpickers.com/*
   http://localhost:5173/*
   ```

4. Click **Save**

---

### 4. Enable Email Confirmation

1. Go to **Authentication** → **Providers**

2. Click **Email**

3. Make sure these are enabled:
   - ✅ **Enable email provider**
   - ✅ **Enable email confirmations** (turn this ON)
   - ✅ **Secure email change**

4. Click **Save**

---

### 5. Test Email Sending

#### Test 1: Quick SMTP Test

Create a test to verify SMTP works:

1. Go to your site: www.souvenirpickers.com
2. Try to sign up with a **real email you can access**
3. Check your inbox (and spam folder)
4. You should receive a confirmation email

#### Test 2: Using Diagnostic Tool

1. Open: https://souvenirpickers.com/test-signup-final.html
2. Enter a **real email address**
3. Click "Test Signup"
4. Check for "Email confirmation required" message
5. Check your email inbox

#### Test 3: Password Reset Test

1. Go to www.souvenirpickers.com
2. Click "Forgot Password?"
3. Enter your email
4. Check if you receive the password reset email

---

### 6. Verify in Supabase Logs

1. Go to **Logs** → **Auth Logs** in Supabase Dashboard

2. Look for entries like:
   - "email sent successfully"
   - "confirmation email sent"
   - Any SMTP errors will show here

3. Filter by "email" to see email-related logs

---

## Troubleshooting

### Issue: "SMTP connection failed"

**Solution:**
- Verify SMTP credentials are correct
- Port 587 should use STARTTLS
- Try Port 465 with SSL if 587 doesn't work

### Issue: Emails not arriving

**Check:**
1. Spam folder (most common issue!)
2. Email address is correct
3. Supabase logs for errors
4. SMTP quota (Bluehost may have sending limits)

**Solution:**
- Check Supabase logs for errors
- Verify email isn't blacklisted
- Check Bluehost email sending limits
- Wait 60 seconds between test emails (rate limit)

### Issue: "Invalid login" or "Authentication failed"

**Solution:**
- Double-check password (Laur197511$)
- Verify username is full email (support@souvenirpickers.com)
- Check if email account is active in Bluehost cPanel

### Issue: Emails going to spam

**Solution:**
1. Add SPF record to DNS:
   ```
   v=spf1 a mx include:mail.souvenirpickers.com ~all
   ```

2. Add DKIM record (get from Bluehost cPanel)

3. Add DMARC record:
   ```
   v=DMARC1; p=none; rua=mailto:support@souvenirpickers.com
   ```

---

## Alternative: Test SMTP Connection First

Before configuring Supabase, test your SMTP credentials:

### Using Edge Function

I can create an edge function to test SMTP:

```typescript
// Test SMTP connection
const response = await fetch('https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/test-smtp', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    to: 'your-email@example.com'
  })
});
```

Would you like me to create this test function?

---

## Production Checklist

Before going live, verify:

- [ ] SMTP configured in Supabase
- [ ] Email templates updated with branding
- [ ] Redirect URLs configured correctly
- [ ] Email confirmation enabled
- [ ] Tested signup flow with real email
- [ ] Tested password reset flow
- [ ] Tested magic link flow
- [ ] Checked spam folder delivery
- [ ] Verified SPF/DKIM/DMARC records (optional but recommended)
- [ ] Set appropriate rate limits

---

## Quick Reference

### Your Current Setup

```
Frontend: https://www.souvenirpickers.com
Supabase Project: bfqvzxczmvfteqbhgyvx
SMTP Host: mail.souvenirpickers.com
SMTP Port: 587
SMTP User: support@souvenirpickers.com
Email From: support@souvenirpickers.com
```

### Important Links

- [Supabase Dashboard](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx)
- [Auth Settings](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth)
- [Email Templates](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates)
- [Auth Logs](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs)

---

## What Happens After Configuration

1. **User signs up** → Account created but not confirmed
2. **Supabase sends email** → Using your Bluehost SMTP
3. **User receives email** → With confirmation link
4. **User clicks link** → Email confirmed
5. **User is logged in** → Full access to app

---

## Next Steps

1. **Configure SMTP now** (5 minutes)
2. **Update email templates** (10 minutes)
3. **Test with real email** (2 minutes)
4. **Verify in logs** (1 minute)
5. **Go live!** ✅

**Total setup time: ~20 minutes**

---

## Need Help?

If you encounter issues:

1. Check Supabase Auth Logs first
2. Test SMTP credentials in email client
3. Verify email account works in Bluehost cPanel
4. Check for typos in configuration
5. Contact Bluehost support if SMTP isn't working

---

## Summary

✅ You have all the SMTP credentials you need
✅ Just copy them into Supabase Dashboard
✅ Update email templates
✅ Enable email confirmation
✅ Test and you're done!

**The setup is straightforward - just follow the steps above and you'll have working email confirmations in minutes!**
