# 🚀 Deploy Now - Simple 3-Step Guide

## Your app is built and ready to deploy!

---

## 🎯 FASTEST: Netlify Drag & Drop (2 minutes)

### Step 1: Go to Netlify
Open: **https://app.netlify.com/drop**

### Step 2: Drag & Drop
Drag your entire **`dist/`** folder onto the page

### Step 3: Done!
Get your live URL like: `https://your-site.netlify.app`

**Optional:** Add custom domain `souvenirpickers.com` in Netlify settings

---

## 🏠 OR: Upload to Bluehost

### Step 1: Login to cPanel
Go to your Bluehost cPanel

### Step 2: File Manager
Open **File Manager** → Navigate to **`public_html/`**

### Step 3: Upload Everything
Upload ALL files from your **`dist/`** folder

### Step 4: Visit Site
Go to `https://souvenirpickers.com` - done!

---

## ⚙️ IMPORTANT: After Deploying

### Add Your Domain to Supabase (Required!)

1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

2. In **Redirect URLs** section, click **Add URL** and add these one by one:
   ```
   https://souvenirpickers.com/*
   https://souvenirpickers.com/reset-password
   https://www.souvenirpickers.com/*
   ```

3. Set **Site URL** to: `https://souvenirpickers.com`

4. Click **Save**

---

## ✅ Test Your Site (Must Do!)

### Test 1: Sign Up
1. Go to your site
2. Click "Sign Up"
3. Create account
4. **Expected:** Immediately logged in ✅

### Test 2: Sign In
1. Log out
2. Click "Sign In"
3. Enter email/password
4. **Expected:** Successfully logged in ✅

### Test 3: Password Reset
1. Log out
2. Click "Forgot Password?"
3. Enter your email
4. Check your inbox (from support@souvenirpickers.com)
5. Click reset link
6. Enter new password
7. **Expected:** Password changed, can log in ✅

---

## 🐛 Troubleshooting

**"Invalid Redirect URL" error?**
→ Add your domain to Supabase (see above)

**Email not received?**
→ Check spam folder
→ Email comes from: support@souvenirpickers.com

**Can't log in?**
→ Make sure you created an account first
→ Password must be at least 6 characters

**Site blank or errors?**
→ Press F12 to see console errors
→ Check Supabase logs

---

## 📊 What's Already Configured

✅ Supabase database (live and ready)
✅ Email sending (support@souvenirpickers.com)
✅ Stripe payments (live mode)
✅ All security (RLS policies)
✅ Production build optimized

---

## 🎉 That's It!

Just:
1. **Upload** the `dist/` folder
2. **Configure** Supabase redirect URLs
3. **Test** the 3 auth flows

Your marketplace is ready for users!

---

## 📞 Need Help?

- View browser console (F12) for errors
- Check Supabase dashboard for logs
- All authentication uses Supabase built-in features
- Email system is fully automated
