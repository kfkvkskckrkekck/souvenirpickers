# Deploy Auth Fix & Configure Email System

## The Problem & Solution

### What Was Wrong
1. Custom edge functions were bypassing Supabase's auth system
2. Supabase's built-in auth emails weren't configured with SMTP
3. Users were being auto-confirmed without email verification

### What's Fixed
1. ✅ Removed problematic edge functions
2. ✅ Using Supabase's built-in `resetPasswordForEmail()` method
3. ✅ Proper token validation in ResetPasswordView
4. ⚠️ **Still Need:** Configure SMTP in Supabase Dashboard

---

## 🚀 STEP 1: Deploy to Production (Netlify)

### Your deployment package is ready: `souvenirpickers-auth-fix-latest.tar.gz`

### Option A: Drag & Drop Deploy (Easiest)

1. Go to Netlify: https://app.netlify.com
2. Log in to your account
3. Find your site: souvenirpickers.com
4. Click on **"Deploys"** tab
5. Drag and drop the `dist` folder to the deploy area
6. Wait for deployment to complete (1-2 minutes)

### Option B: Netlify CLI Deploy

```bash
# If you have Netlify CLI installed
netlify deploy --prod --dir=dist
```

### Option C: Manual Upload

1. Extract the `souvenirpickers-auth-fix-latest.tar.gz` file
2. Upload the `dist` folder contents via Netlify dashboard
3. Make sure `_redirects` file is included in the dist folder

---

## 📧 STEP 2: Configure Supabase SMTP (CRITICAL!)

This is why emails aren't being sent - Supabase's built-in auth doesn't have SMTP configured!

### Go to Supabase Dashboard:
https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth

### Configure SMTP Settings:

1. Scroll down to **"SMTP Settings"** section
2. Click **"Enable Custom SMTP"**
3. Enter your Bluehost SMTP details:

```
SMTP Host: mail.souvenirpickers.com
SMTP Port: 587
SMTP User: support@souvenirpickers.com
SMTP Password: Laur197511$
Sender email: support@souvenirpickers.com
Sender name: SouvenirPickers
```

4. **IMPORTANT:** Select **"Enable TLS"** (not SSL)
5. Click **"Save"** button

### Test SMTP Configuration:

After saving, Supabase will show a **"Send test email"** button. Click it to verify!

---

## 🔒 STEP 3: Configure Auth Settings

### 3A: Email Confirmation (Recommended for Production)

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/providers

Find **"Email Provider"** and:
- ✅ **Enable "Confirm email"** toggle
- This requires users to verify their email before signing in
- More secure for production

### 3B: Redirect URLs (Already Configured)

These should already be set, but verify:
https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

**Site URL:**
```
https://www.souvenirpickers.com
```

**Redirect URLs:**
```
https://www.souvenirpickers.com/**
https://souvenirpickers.com/**
http://localhost:5173/**
```

### 3C: Email Templates

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates

Verify these templates are using correct variables:

**Confirm Signup Template:**
- Must include: `{{ .ConfirmationURL }}`

**Reset Password Template:**
- Must include: `{{ .ConfirmationURL }}`

**Magic Link Template:**
- Must include: `{{ .ConfirmationURL }}`

---

## ✅ STEP 4: Test the System

### Test 1: Password Reset
1. Go to https://www.souvenirpickers.com
2. Click "Sign In"
3. Click "Forgot Password?"
4. Enter your email
5. **Check your email** (including spam folder!)
6. Click the reset link
7. Enter new password

### Test 2: New User Signup
1. Go to https://www.souvenirpickers.com
2. Click "Sign Up"
3. Fill in details and submit
4. **Check your email for confirmation**
5. Click confirmation link
6. Try signing in

### Test 3: Magic Link
1. Go to https://www.souvenirpickers.com
2. Click "Sign In"
3. Click "Or sign in with a magic link instead"
4. Enter your email
5. **Check your email**
6. Click the magic link

---

## 🔍 Troubleshooting

### Issue: Still no emails received

**Check:**
1. ✅ SMTP settings saved in Supabase dashboard
2. ✅ Test email sent successfully from Supabase
3. ✅ Check spam/junk folder
4. ✅ Verify email address is correct
5. ✅ Wait 60 seconds between attempts (rate limiting)

**Verify in Supabase Logs:**
https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs

Look for:
- ✅ "email sent" messages (good!)
- ❌ "SMTP error" messages (bad - check credentials)
- ❌ "Rate limit exceeded" (wait 60 seconds)

### Issue: "API Error" during signup

This typically means:
1. SMTP not configured in Supabase dashboard
2. Email confirmation is enabled but emails can't be sent
3. SMTP credentials are incorrect

**Solution:**
- Configure SMTP in dashboard (Step 2)
- OR temporarily disable email confirmation for testing

### Issue: Emails going to spam

**Solutions:**
1. Add SPF record to your domain DNS:
   ```
   v=spf1 include:_spf.mx.cloudflare.net ~all
   ```
2. Add DKIM records (check with Bluehost)
3. Ask users to whitelist support@souvenirpickers.com

---

## 📦 Deployment Package Contents

The `souvenirpickers-auth-fix-latest.tar.gz` contains:
- ✅ Updated AuthForm component (using Supabase's built-in methods)
- ✅ Correct ResetPasswordView with token validation
- ✅ Removed problematic edge functions
- ✅ All latest production code

---

## 🎯 Quick Start Checklist

- [ ] Deploy `dist` folder to Netlify
- [ ] Configure SMTP in Supabase dashboard
- [ ] Send test email from Supabase
- [ ] Enable email confirmation toggle
- [ ] Test password reset flow
- [ ] Test new user signup flow
- [ ] Check Supabase auth logs
- [ ] Verify emails arriving (check spam!)

---

## 🆘 Still Having Issues?

### Check Supabase Auth Logs:
https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/auth-logs

### View Recent Users:
Check if users are being created but not confirmed:
```sql
SELECT email, email_confirmed_at, confirmed_at, created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;
```

### Contact Bluehost:
If SMTP still doesn't work, contact Bluehost support to verify:
- Port 587 is open for TLS connections
- Account support@souvenirpickers.com is active
- Password is correct
- No IP restrictions

---

## 📝 Important Notes

1. **SMTP Configuration is Critical:** Without it, NO auth emails will be sent
2. **Test SMTP First:** Use Supabase's test email button before testing signup
3. **Email Confirmation:** Can be temporarily disabled for testing
4. **Check Logs:** Supabase auth logs show exact error messages
5. **Spam Folder:** Always check spam when testing emails

---

**Your authentication system is now properly configured to use Supabase's built-in auth with secure token validation. Once SMTP is configured in the dashboard, all emails will work correctly!**
