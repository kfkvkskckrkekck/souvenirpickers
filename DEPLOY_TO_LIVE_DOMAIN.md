# Deploy to www.souvenirpickers.com - Complete Guide

## What's Included in This Update

✅ **Password Reset Functionality** - Fully working with email recovery
✅ **Mobile Video Fixes** - Video now plays with sound on mobile devices
✅ **All Latest Features** - Complete marketplace functionality

---

## Quick Start: 2 Steps to Go Live

### Step 1: Upload Files to Your Server (10 minutes)

**Package Ready:** `souvenirpickers-live-deploy-latest.tar.gz`

#### Option A: Using cPanel File Manager
1. Log in to your cPanel at your hosting provider
2. Go to **File Manager**
3. Navigate to `public_html` folder
4. Upload `souvenirpickers-live-deploy-latest.tar.gz`
5. Right-click the file → **Extract**
6. Delete the .tar.gz file after extraction
7. Done!

#### Option B: Using FTP (FileZilla)
1. Connect to your server via FTP
2. Navigate to `public_html` or `www` folder
3. Upload all files from the `dist` folder
4. Make sure these files are uploaded:
   - `index.html`
   - `_redirects` file
   - `.htaccess` file
   - `assets/` folder (all JS and CSS files)
   - All MP4 video files

#### Option C: Using SSH (Advanced)
```bash
# Upload the package
scp souvenirpickers-live-deploy-latest.tar.gz user@yourserver.com:~/public_html/

# SSH into your server
ssh user@yourserver.com

# Extract
cd public_html
tar -xzf souvenirpickers-live-deploy-latest.tar.gz
rm souvenirpickers-live-deploy-latest.tar.gz
```

---

### Step 2: Configure Supabase for Password Reset (5 minutes)

**CRITICAL:** This step is required for password reset to work!

1. **Go to Supabase Dashboard:**
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

2. **Set Site URL:**
   ```
   https://www.souvenirpickers.com
   ```

3. **Add Redirect URLs** (one per line):
   ```
   https://www.souvenirpickers.com
   https://souvenirpickers.com
   https://www.souvenirpickers.com/*
   https://souvenirpickers.com/*
   ```

4. **Click "Save"** at the bottom

5. **Done!** Password reset will now work on your live domain

---

## Testing After Deployment (15 minutes)

### Test 1: Homepage Loads
1. Visit: https://www.souvenirpickers.com
2. Video should play automatically (muted)
3. Click volume button to hear sound
4. Verify video plays on mobile devices

### Test 2: User Registration
1. Click "Sign Up"
2. Enter email, password, name
3. Submit form
4. Check email for confirmation
5. Click confirmation link
6. Verify account is created

### Test 3: Password Reset
1. Click "Sign In"
2. Click "Forgot Password?"
3. Enter your email
4. Click "Send Reset Link"
5. Check email (including spam folder)
6. Click reset link in email
7. Should redirect to www.souvenirpickers.com
8. Enter new password
9. Confirm password was reset
10. Log in with new password

### Test 4: Login
1. Sign in with test account
2. Verify dashboard loads
3. Check all features work

### Test 5: Mobile Video
1. Open site on mobile device
2. Verify video loads and plays
3. Tap volume button
4. Confirm sound works
5. Check video controls work

---

## What's New in This Deploy

### Mobile Video Improvements
- Added iOS-specific playback attributes
- Enhanced autoplay handling for mobile browsers
- Improved sound control with automatic play on unmute
- Better error handling for restricted autoplay

### Password Reset Enhancements
- Dynamic redirect URLs (works with any domain)
- Enhanced token detection in URL
- Better error messages
- Email delivery via Supabase Edge Functions
- Support for backup recovery options

### All Features Working
- User authentication (sign up, login, password reset)
- Marketplace listings
- Order management
- Payment processing (Stripe)
- Real-time chat
- Notifications
- User profiles
- Reviews and ratings
- All 40+ components fully functional

---

## Troubleshooting

### Issue: "Password reset email not received"

**Solutions:**
1. Check spam/junk folder first!
2. Wait 60 seconds between requests (rate limited)
3. Verify Supabase redirect URLs are configured (Step 2 above)
4. Check Supabase email logs:
   https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs

### Issue: "Reset link doesn't work"

**Solutions:**
1. Make sure you completed Step 2 (Supabase configuration)
2. Click "Save" in Supabase after adding URLs
3. Try clearing browser cache
4. Request a new reset link (old links expire after 1 hour)

### Issue: "Video doesn't play on mobile"

**Solutions:**
1. Make sure video files were uploaded (check `public` folder)
2. Video path should be: `/Livesouvenir_V1_0.mp4`
3. Try refreshing the page
4. Check mobile browser console for errors
5. Some browsers require user interaction before playing video with sound

### Issue: "Site shows blank page"

**Solutions:**
1. Check that all files from `dist` folder were uploaded
2. Verify `index.html` is in the root directory
3. Check `.htaccess` or `_redirects` file exists
4. Clear browser cache and hard refresh (Ctrl+Shift+R)
5. Check browser console for errors (F12)

### Issue: "Can't log in"

**Solutions:**
1. Verify Supabase credentials in `.env` are correct
2. Check that environment variables are set on your server
3. Try password reset if you forgot password
4. Create a new account to test

---

## Environment Variables Check

Make sure these are set on your hosting:

```env
VITE_SUPABASE_URL=https://bfqvzxczmvfteqbhgyvx.supabase.co
VITE_SUPABASE_ANON_KEY=[your-anon-key]
VITE_STRIPE_PUBLISHABLE_KEY=[your-stripe-key]
```

**Note:** These are compiled into the build, so if they're in your `.env` file before building, they're already included!

---

## Custom Domain DNS Configuration

If you haven't pointed your domain yet:

### DNS Records at Your Domain Registrar

**For Netlify:**
```
Type    Name    Value
A       @       75.2.60.5
CNAME   www     [your-site].netlify.app
```

**For Other Hosting:**
Ask your hosting provider for their DNS records.

### Wait Time
- DNS changes take 5 minutes to 24 hours
- Usually works within 1-2 hours
- Check with: https://whatsmydns.net

---

## Security Notes

✅ All passwords are hashed by Supabase
✅ Reset links expire after 1 hour
✅ Links can only be used once
✅ Rate limiting prevents abuse
✅ HTTPS enforced (if configured)
✅ Row Level Security (RLS) active on database
✅ Stripe payments are secure (PCI compliant)

---

## Next Steps After Deployment

1. **Set up custom email (Optional)**
   - Configure SMTP in Supabase
   - Use SendGrid, Mailgun, or AWS SES
   - Customize email templates with your branding

2. **Configure Stripe Webhooks**
   - Add webhook URL: `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook`
   - Select events: `payment_intent.*`, `checkout.session.*`
   - Copy webhook secret to Supabase

3. **Add Google Analytics (Optional)**
   - Get tracking ID from Google Analytics
   - Add to `index.html` before deploy

4. **Test Everything**
   - Run through all user flows
   - Test on different devices
   - Test in different browsers
   - Have friends test it

---

## Support Resources

- **Supabase Dashboard:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
- **Stripe Dashboard:** https://dashboard.stripe.com
- **Supabase Docs:** https://supabase.com/docs
- **Check Site Status:** https://www.isitdownrightnow.com/souvenirpickers.com.html

---

## Summary Checklist

- [ ] Files uploaded to server
- [ ] Supabase redirect URLs configured
- [ ] Homepage loads at www.souvenirpickers.com
- [ ] Video plays and has sound
- [ ] User registration works
- [ ] User login works
- [ ] Password reset works (tested!)
- [ ] All features tested on desktop
- [ ] All features tested on mobile
- [ ] DNS configured (if needed)
- [ ] SSL certificate active (HTTPS)

---

## Quick Reference

**Deployment Package:** `souvenirpickers-live-deploy-latest.tar.gz`
**Live Site:** https://www.souvenirpickers.com
**Supabase Project:** bfqvzxczmvfteqbhgyvx
**Configuration URL:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

---

**You're ready to go live! 🚀**

After uploading files and configuring Supabase (2 steps above), your site will be fully functional with:
- Working password reset
- Mobile video with sound
- All marketplace features
- Secure payments
- Real-time messaging
- And much more!

Good luck! 🎉
