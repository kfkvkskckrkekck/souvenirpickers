# Domain Migration Checklist for LiveSouvenir

## Your New Domain Setup

**Current Status:** Development (localhost)
**Target:** Production domain (e.g., livesouvenir.com)

---

## ✅ Pre-Migration Checklist

### 1. Supabase Authentication Settings

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

#### **A. Site URL Configuration**
Update the Site URL to your production domain:
```
https://yourdomain.com
```

#### **B. Redirect URLs (CRITICAL)**
Add ALL of these redirect URLs:

```
https://yourdomain.com
https://yourdomain.com/
https://yourdomain.com/#/
https://yourdomain.com/#type=recovery
https://yourdomain.com/#recovery
```

**Why multiple URLs?**
- Password reset links use `#type=recovery`
- Email confirmations use base URL
- Magic links use base URL
- Different flows use slightly different redirect patterns

#### **C. Additional Allowed Redirect URLs**
If you use www subdomain, add these too:
```
https://www.yourdomain.com
https://www.yourdomain.com/
https://www.yourdomain.com/#/
https://www.yourdomain.com/#type=recovery
```

---

### 2. Email Templates Configuration

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates

**Update these templates to use your domain:**

#### **Confirm Signup Template**
- Update the confirmation link to point to your domain
- Default: `{{ .ConfirmationURL }}`
- Should redirect to: `https://yourdomain.com`

#### **Reset Password Template**
- Update the reset link to point to your domain
- Default: `{{ .ConfirmationURL }}`
- Should redirect to: `https://yourdomain.com/#type=recovery`

#### **Magic Link Template**
- Update the magic link to point to your domain
- Default: `{{ .ConfirmationURL }}`
- Should redirect to: `https://yourdomain.com`

---

### 3. SMTP Email Configuration (REQUIRED for emails to work)

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth

**Option A: Use Supabase Email Service (Easiest)**
- Scroll to "SMTP Settings"
- Make sure "Enable Custom SMTP" is **OFF**
- Supabase will use their built-in email service

**Option B: Custom SMTP Provider (Recommended for Production)**

Choose one of these providers:

**Gmail SMTP (Quick Test)**
```
SMTP Host: smtp.gmail.com
SMTP Port: 587
SMTP User: your-email@gmail.com
SMTP Password: [App Password - not your regular password]
Sender Email: your-email@gmail.com
Sender Name: LiveSouvenir
```
Note: You need to enable "Less secure app access" or use App Passwords in Gmail settings.

**SendGrid (Recommended)**
```
SMTP Host: smtp.sendgrid.net
SMTP Port: 587
SMTP User: apikey
SMTP Password: [Your SendGrid API Key]
Sender Email: noreply@yourdomain.com
Sender Name: LiveSouvenir
```

**Mailgun**
```
SMTP Host: smtp.mailgun.org
SMTP Port: 587
SMTP User: [Your Mailgun SMTP Username]
SMTP Password: [Your Mailgun SMTP Password]
Sender Email: noreply@yourdomain.com
Sender Name: LiveSouvenir
```

**AWS SES**
```
SMTP Host: email-smtp.[region].amazonaws.com
SMTP Port: 587
SMTP User: [Your AWS SES SMTP Username]
SMTP Password: [Your AWS SES SMTP Password]
Sender Email: noreply@yourdomain.com
Sender Name: LiveSouvenir
```

---

### 4. Environment Variables (Optional)

Your `.env` file should stay the same because:
- ✅ Supabase URL doesn't change
- ✅ Supabase anon key doesn't change
- ✅ Code uses `window.location.origin` (dynamic, no hardcoding)

**No changes needed to `.env` file!**

---

### 5. DNS & SSL Configuration

Before deploying, ensure:

✅ **Domain DNS is configured** pointing to your hosting provider
✅ **SSL certificate is active** (HTTPS required for Supabase auth)
✅ **www and non-www both work** (or redirect properly)

**Test your SSL:**
```bash
curl -I https://yourdomain.com
```
Should return `200 OK` with SSL certificate info.

---

### 6. Deployment Steps

1. **Deploy your application** to your hosting provider
2. **Wait for DNS propagation** (can take up to 48 hours, usually 5-15 minutes)
3. **Verify HTTPS is working** - visit `https://yourdomain.com`
4. **Test authentication flows:**
   - Sign up new account
   - Confirm email
   - Sign in
   - Forgot password
   - Password reset
   - Magic link sign in

---

## 🧪 Testing After Migration

### Test Signup Flow
1. Go to `https://yourdomain.com`
2. Click "Sign Up"
3. Enter email and password
4. Check email for confirmation link
5. Click confirmation link
6. Should redirect to `https://yourdomain.com` and auto-login

### Test Password Reset Flow
1. Go to `https://yourdomain.com`
2. Click "Forgot Password"
3. Enter email address
4. Check email for reset link (CHECK SPAM!)
5. Click reset link
6. Should redirect to `https://yourdomain.com/#type=recovery`
7. Enter new password
8. Should redirect to login page

### Test Magic Link Flow
1. Go to `https://yourdomain.com`
2. Click "Sign in with magic link"
3. Enter email
4. Check email for magic link
5. Click magic link
6. Should redirect to `https://yourdomain.com` and auto-login

---

## 🚨 Common Issues & Solutions

### Issue: "Invalid Redirect URL" Error
**Solution:** Make sure ALL redirect URLs are added in Supabase dashboard (see Step 1B)

### Issue: Email Not Received
**Solutions:**
1. Check spam/junk folder
2. Verify SMTP is configured in Supabase dashboard
3. Check Supabase logs: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/edge-logs
4. Test SMTP credentials directly

### Issue: "Invalid Access Token" After Clicking Email Link
**Solution:**
1. Verify Site URL is set correctly in Supabase
2. Make sure redirect URL in email matches exactly what's in Supabase settings
3. Check that SSL/HTTPS is working properly

### Issue: Stuck on "Verifying reset link..."
**Solution:**
1. Check browser console (F12) for errors
2. Verify the URL has `access_token` and `refresh_token` in the hash
3. Check Supabase redirect URLs include the hash fragment version

---

## 📋 Quick Reference

### Supabase Dashboard Links
- **URL Configuration:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration
- **Email Templates:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates
- **SMTP Settings:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/auth
- **Logs (for debugging):** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/edge-logs

### Your Code is Already Ready! ✅
Your authentication code is already domain-agnostic:
- Uses `window.location.origin` for redirects
- Dynamically constructs URLs
- Handles tokens from URL hash automatically
- No hardcoded domains in code

**The only changes needed are in the Supabase dashboard!**

---

## 🎯 Summary: What to Do

1. ✅ Update Supabase Site URL to your production domain
2. ✅ Add all redirect URLs in Supabase dashboard
3. ✅ Configure SMTP email provider
4. ✅ Update email templates to use your domain
5. ✅ Deploy your app with SSL/HTTPS
6. ✅ Test all authentication flows

**Time Required:** 15-30 minutes (excluding DNS propagation)

---

## Need Help?

If you encounter issues:
1. Check Supabase logs
2. Check browser console (F12)
3. Verify all URLs match exactly
4. Test SMTP email delivery
5. Contact Supabase support if emails still don't work
