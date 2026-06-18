# 🚀 Production Deployment Guide

## ✅ Pre-Deployment Checklist (COMPLETED)

- ✅ Production build created successfully
- ✅ Environment variables configured for production
- ✅ Supabase database ready
- ✅ Email templates configured in Supabase
- ✅ Stripe LIVE keys configured
- ✅ SMTP configured with Bluehost
- ✅ Deployment package created

## 📦 Deployment Package

**File:** `souvenirpickers-production-deploy.tar.gz` (276KB)

## 🌐 Deploy to Netlify (Recommended - Fastest)

### Option 1: Drag & Drop (Easiest)

1. Extract the deployment package:
   ```bash
   tar -xzf souvenirpickers-production-deploy.tar.gz -C deploy-folder
   ```

2. Go to https://app.netlify.com/drop

3. Drag and drop the `deploy-folder` or `dist/` directory

4. Netlify will give you a URL like: `https://random-name.netlify.app`

5. Configure custom domain:
   - In Netlify Dashboard → Domain Settings
   - Add custom domain: `souvenirpickers.com`
   - Follow DNS instructions

### Option 2: Netlify CLI

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login to Netlify
netlify login

# Deploy
netlify deploy --prod --dir=dist
```

## 🏠 Deploy to Bluehost

1. **Connect via FTP or File Manager:**
   - Host: ftp.souvenirpickers.com
   - Username: Your Bluehost username
   - Connect using FileZilla or cPanel File Manager

2. **Upload files:**
   - Extract `souvenirpickers-production-deploy.tar.gz`
   - Upload all files to `public_html/` directory
   - Make sure `index.html` is in the root

3. **Verify `.htaccess` is present** (for React Router support)

## 🔧 Post-Deployment Configuration

### 1. Update Supabase Redirect URLs

Add your production domain to Supabase:

1. Go to https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

2. Add these URLs to **Redirect URLs**:
   ```
   https://souvenirpickers.com/*
   https://souvenirpickers.com/reset-password*
   https://www.souvenirpickers.com/*
   https://www.souvenirpickers.com/reset-password*
   ```

3. Set **Site URL** to:
   ```
   https://souvenirpickers.com
   ```

### 2. Verify Email Templates

Your email templates are already configured in Supabase with:
- **Password Reset URL:** `https://souvenirpickers.com/reset-password`
- **Site URL:** `https://souvenirpickers.com`

## 🧪 Testing Authentication Flows

Once deployed, test all authentication features:

### Test 1: Sign Up Flow

1. Go to `https://souvenirpickers.com`

2. Click "Sign Up" or create new account

3. Fill in:
   - Email: Use a real email you can access
   - Password: At least 6 characters
   - Full Name
   - Select role (Picker or Collector)

4. Click "Sign Up"

5. **Expected Result:**
   - Should redirect to app immediately
   - No confirmation email needed (disabled)
   - You should be logged in

### Test 2: Sign In Flow

1. Go to `https://souvenirpickers.com`

2. If logged in, log out first

3. Click "Sign In"

4. Enter your email and password

5. Click "Sign In"

6. **Expected Result:**
   - Should log in successfully
   - Redirect to dashboard
   - Profile data should load

### Test 3: Password Reset Flow

1. Go to `https://souvenirpickers.com`

2. Click "Forgot Password?"

3. Enter your email address

4. Click "Send Reset Link"

5. **Expected Result:**
   - Should show success message
   - Email sent from support@souvenirpickers.com
   - Email arrives within 1-2 minutes

6. Check your email inbox

7. Click the reset link in the email

8. **Expected Result:**
   - Opens `https://souvenirpickers.com/reset-password`
   - Shows password reset form
   - Access token present in URL

9. Enter new password (twice)

10. Click "Reset Password"

11. **Expected Result:**
    - Password updated successfully
    - Can now log in with new password

## 🐛 Troubleshooting

### Issue: "Invalid login credentials"
- **Solution:** Make sure the email and password are correct
- Check if account exists in Supabase Auth dashboard

### Issue: "Email not sent"
- **Solution:** Check SMTP configuration in Supabase
- Verify SMTP secrets are set correctly
- Check email spam folder

### Issue: "Redirect URL not allowed"
- **Solution:** Add production domain to Supabase Redirect URLs
- Make sure wildcard patterns are included

### Issue: "Cannot access after signup"
- **Solution:** Check browser console for errors
- Verify Supabase URL and Anon Key are correct
- Check RLS policies in database

## 📊 Monitor After Deployment

1. **Check Supabase Logs:**
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/explorer

2. **Check Edge Function Logs:**
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/functions

3. **Monitor Auth Activity:**
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/users

## ✅ Success Checklist

After deployment, verify:

- [ ] Site loads at https://souvenirpickers.com
- [ ] Can create new account
- [ ] Can sign in with credentials
- [ ] Can log out
- [ ] Can request password reset
- [ ] Receive password reset email
- [ ] Can reset password using email link
- [ ] Can log in with new password
- [ ] Profile data saves correctly
- [ ] No console errors

## 🎉 You're Live!

Once all tests pass, your marketplace is live and ready for users!

## 📞 Need Help?

If you encounter any issues:
1. Check browser console (F12) for errors
2. Check Supabase logs
3. Verify all redirect URLs are configured
4. Test email delivery in spam folder
