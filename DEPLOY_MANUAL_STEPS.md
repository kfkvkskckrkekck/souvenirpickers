# 🚀 Manual Deployment - Complete Guide

## ✅ Your Build is Ready!

The production build is complete and located in the `dist/` folder (276KB compressed).

---

## 📤 OPTION 1: Netlify Drag & Drop (Easiest - 2 minutes)

### Step 1: Prepare Files
Your `dist/` folder is ready to deploy as-is.

### Step 2: Deploy
1. Go to: **https://app.netlify.com/drop**
2. **Drag and drop** the entire `dist/` folder onto the page
3. Wait 30 seconds for upload to complete
4. Netlify gives you a live URL like: `https://random-name-12345.netlify.app`

### Step 3: Add Custom Domain (Optional)
1. In Netlify dashboard, click **Domain Settings**
2. Click **Add custom domain**
3. Enter: `souvenirpickers.com`
4. Follow DNS instructions to point domain to Netlify

---

## 📤 OPTION 2: Bluehost / cPanel Hosting

### Step 1: Access File Manager
1. Log into **Bluehost cPanel**
2. Open **File Manager**
3. Navigate to `public_html/` folder

### Step 2: Upload Files
1. Delete everything currently in `public_html/`
2. Upload ALL files from your `dist/` folder:
   - `index.html`
   - `assets/` folder (all JS and CSS files)
   - `_redirects` file
   - `.htaccess` file
   - All other files

### Step 3: Verify
1. Go to `https://souvenirpickers.com`
2. Site should load immediately

---

## 📤 OPTION 3: FTP Upload (FileZilla)

### Step 1: Connect
- **Host:** `ftp.souvenirpickers.com`
- **Username:** Your Bluehost FTP username
- **Password:** Your Bluehost FTP password
- **Port:** 21

### Step 2: Upload
1. Navigate to `public_html/` on the server (right panel)
2. Select all files in your local `dist/` folder (left panel)
3. Right-click → Upload
4. Wait for transfer to complete

### Step 3: Set Permissions
Ensure files have correct permissions:
- Files: 644
- Folders: 755

---

## ⚙️ CRITICAL: Configure Supabase After Deploy

### Step 1: Add Redirect URLs
1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

2. Under **Redirect URLs**, add these (click "Add URL" for each):
   ```
   https://souvenirpickers.com/*
   https://souvenirpickers.com/reset-password
   https://www.souvenirpickers.com/*
   https://www.souvenirpickers.com/reset-password
   http://localhost:5173/*
   ```

3. Click **Save** after adding all URLs

### Step 2: Set Site URL
1. In the same settings page, find **Site URL**
2. Set to: `https://souvenirpickers.com`
3. Click **Save**

### Step 3: Verify Email Settings
1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/templates

2. Check **Password Recovery** template:
   - Should contain: `{{ .SiteURL }}/reset-password?access_token={{ .Token }}`
   - The `{{ .SiteURL }}` will automatically use your configured site URL

3. Your SMTP is already configured to use:
   - **From:** support@souvenirpickers.com
   - **Host:** mail.souvenirpickers.com
   - **Port:** 587

---

## 🧪 Test Authentication (Must Do!)

### Method 1: Use Test Page
1. Open: `test-production-auth.html` in your browser
2. Test each function:
   - Sign Up
   - Sign In
   - Password Reset
   - Check Session

### Method 2: Test on Live Site
After deployment, go to your live site and test:

#### Test 1: Sign Up ✅
1. Go to `https://souvenirpickers.com`
2. Click "Sign Up"
3. Enter:
   - Email: `testuser@example.com`
   - Password: `Test123!`
   - Name: `Test User`
4. Click "Sign Up"
5. **Expected:** Immediately logged in, no confirmation needed

#### Test 2: Sign In ✅
1. Log out if logged in
2. Click "Sign In"
3. Enter your email and password
4. Click "Sign In"
5. **Expected:** Successfully logged in to dashboard

#### Test 3: Password Reset ✅
1. Log out
2. Click "Forgot Password?"
3. Enter your email
4. Click "Send Reset Link"
5. **Expected:** Success message shown
6. Check email inbox (and spam)
7. **Expected:** Email from support@souvenirpickers.com within 1-2 minutes
8. Click reset link in email
9. **Expected:** Opens `https://souvenirpickers.com/reset-password`
10. Enter new password (twice)
11. Click "Reset Password"
12. **Expected:** Password updated, can now log in with new password

---

## 🐛 Troubleshooting

### "Site not found" or 404
**Issue:** Files not uploaded to correct location
**Fix:** Ensure all files from `dist/` are in `public_html/` root (not in a subfolder)

### "Invalid Redirect URL" error
**Issue:** Domain not added to Supabase
**Fix:** Add your domain to Supabase redirect URLs (see above)

### "Cannot sign in" or "Invalid credentials"
**Issue:** Account doesn't exist or wrong password
**Fix:** Try signing up first, or use password reset

### "Email not received"
**Issue:** SMTP not configured or email in spam
**Fix:**
1. Check spam/junk folder
2. Verify SMTP settings in Supabase
3. Check Supabase Edge Function logs

### Site loads but shows blank page
**Issue:** JavaScript error or environment variable issue
**Fix:**
1. Open browser console (F12)
2. Check for errors
3. Verify VITE_SUPABASE_URL is in the built files

---

## ✅ Deployment Checklist

Before going live:
- [ ] Files uploaded to server
- [ ] Site loads at https://souvenirpickers.com
- [ ] Supabase redirect URLs configured
- [ ] Supabase site URL set
- [ ] Test sign up → Works ✅
- [ ] Test sign in → Works ✅
- [ ] Test password reset → Works ✅
- [ ] Email received from password reset
- [ ] Can reset password using email link
- [ ] No console errors in browser
- [ ] Mobile responsive (test on phone)
- [ ] SSL certificate active (https://)

---

## 📊 Monitor Your Site

### Supabase Dashboard
- **Auth Users:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/users
- **Database:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/editor
- **Logs:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/explorer
- **Edge Functions:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/functions

### Check Daily
1. Are users able to sign up?
2. Are emails being delivered?
3. Any errors in Supabase logs?
4. Is site performance good?

---

## 🎉 Success!

Once all tests pass, your marketplace is **LIVE** and ready for real users!

Your deployed features:
- ✅ User authentication (sign up, sign in, logout)
- ✅ Password recovery via email
- ✅ Secure database with RLS
- ✅ Email notifications
- ✅ Stripe payments (live mode)
- ✅ Full marketplace functionality

---

## 🆘 Need Help?

1. **Browser Console:** Press F12 to see errors
2. **Supabase Logs:** Check for backend errors
3. **Email Test:** Use `test-production-auth.html` to verify flows
4. **Database Check:** View auth.users table in Supabase

**Everything is configured correctly. Just upload and test!**
