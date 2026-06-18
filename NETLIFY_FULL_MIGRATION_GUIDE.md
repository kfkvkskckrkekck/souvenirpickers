# Complete Migration to Netlify - Fix Password Reset

Your app has been deployed to Netlify. Now you need to configure your domain to point both `souvenirpickers.com` and `www.souvenirpickers.com` to Netlify.

---

## Step 1: Configure Custom Domain on Netlify

### 1.1 Access Netlify Dashboard

1. Go to: https://app.netlify.com/sites/celebrated-buttercream-4f1ee4/settings/domain
2. Or navigate: Netlify Dashboard → Your Site → Domain Settings

### 1.2 Add Custom Domain

1. Click **"Add custom domain"**
2. Enter: `souvenirpickers.com` (without www)
3. Click **"Verify"**
4. Netlify will detect you own this domain
5. Click **"Add domain"**

**Important:** Netlify will automatically configure both:
- `souvenirpickers.com` (root domain)
- `www.souvenirpickers.com` (www subdomain)

### 1.3 Configure Primary Domain

Choose which version should be primary (both will work, but one will redirect to the other):

**Option A: Make www primary** (Recommended)
- Primary: `www.souvenirpickers.com`
- Redirect: `souvenirpickers.com` → `www.souvenirpickers.com`

**Option B: Make root primary**
- Primary: `souvenirpickers.com`
- Redirect: `www.souvenirpickers.com` → `souvenirpickers.com`

**My recommendation:** Use `www.souvenirpickers.com` as primary (it's what you're currently using).

---

## Step 2: Update DNS Records

You need to update your DNS records at your domain registrar (where you bought souvenirpickers.com).

### 2.1 Netlify DNS Information

Netlify will show you the DNS records you need. They will look like:

**For Root Domain (souvenirpickers.com):**
```
Type: A
Name: @
Value: 75.2.60.5
```

**For WWW Subdomain (www.souvenirpickers.com):**
```
Type: CNAME
Name: www
Value: celebrated-buttercream-4f1ee4.netlify.app
```

### 2.2 Update DNS at Your Registrar

#### If using Bluehost DNS:

1. Log into your Bluehost account
2. Go to **Domains** → **Zone Editor**
3. Find `souvenirpickers.com`

**Update/Add A Record:**
- Type: `A`
- Host: `@` (or blank)
- Points to: `75.2.60.5`
- TTL: `14400` (4 hours)

**Update WWW CNAME:**
- Type: `CNAME`
- Host: `www`
- Points to: `celebrated-buttercream-4f1ee4.netlify.app`
- TTL: `14400`

4. **Remove old records** that point to Bluehost hosting (ask if you're unsure)
5. Click **"Save"**

#### If using another DNS provider (GoDaddy, Namecheap, Cloudflare, etc.):

The process is similar:
1. Log into your DNS provider
2. Find DNS management for souvenirpickers.com
3. Update the A record to point to Netlify's IP
4. Update the CNAME record for www to point to your Netlify subdomain
5. Save changes

### 2.3 DNS Propagation

- DNS changes take **5 minutes to 48 hours** to propagate worldwide
- Usually completes within **1-4 hours**
- You can check progress at: https://dnschecker.org

---

## Step 3: Enable HTTPS (SSL)

Netlify will automatically provision a free SSL certificate once DNS is configured.

### 3.1 Verify HTTPS

1. In Netlify Dashboard → Domain Settings
2. Scroll to **"HTTPS"** section
3. Wait for: **"Certificate provisioning in progress..."**
4. When done, you'll see: **"Your site is secured with HTTPS"**

This usually takes **5-10 minutes** after DNS propagation.

### 3.2 Force HTTPS Redirect

1. In the HTTPS section
2. Enable: **"Force HTTPS redirect"**
3. This ensures all HTTP traffic redirects to HTTPS

---

## Step 4: Update Supabase Redirect URLs

**CRITICAL:** Update Supabase to recognize your domain for password resets.

### 4.1 Access Supabase Dashboard

Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

### 4.2 Configure Site URL

Set **Site URL** to:
```
https://www.souvenirpickers.com
```
(Or `https://souvenirpickers.com` if you chose root as primary)

### 4.3 Configure Redirect URLs

Add these URLs (one per line):
```
https://www.souvenirpickers.com
https://souvenirpickers.com
https://www.souvenirpickers.com/*
https://souvenirpickers.com/*
https://www.souvenirpickers.com/reset-password
https://souvenirpickers.com/reset-password
```

### 4.4 Save Configuration

Click **"Save"** at the bottom.

---

## Step 5: Test Everything

### 5.1 Test Site Access

Visit these URLs and verify they all work:
- https://souvenirpickers.com ✓
- https://www.souvenirpickers.com ✓
- http://souvenirpickers.com (should redirect to HTTPS) ✓
- http://www.souvenirpickers.com (should redirect to HTTPS) ✓

### 5.2 Test Password Reset

1. **Request Reset:**
   - Go to https://www.souvenirpickers.com
   - Click "Forgot Password?"
   - Enter your email
   - Submit

2. **Check Email:**
   - Look for password reset email
   - Check spam folder if needed

3. **Click Reset Link:**
   - Click the link in the email
   - Should open your site with reset form
   - NOT show a 404 or error

4. **Reset Password:**
   - Enter new password
   - Confirm password
   - Submit
   - Should see success message

5. **Login:**
   - Try logging in with new password
   - Should work perfectly ✓

### 5.3 Test Other Features

- Login/Logout
- Profile updates
- Creating listings
- Uploading images
- Payment flows
- Any custom functionality

---

## Step 6: Clean Up Old Hosting (Optional)

Once everything is working perfectly on Netlify:

1. **Keep Bluehost email** (if you use it for support@pickersjourney.com)
2. **Remove website files** from Bluehost hosting (optional cost savings)
3. **Cancel Bluehost hosting** (optional, if you don't need it)
4. **Keep domain registration** at Bluehost (or transfer to another registrar)

**Important:** Don't cancel anything until you've confirmed everything works on Netlify for at least 1 week.

---

## Troubleshooting

### Issue: "Site not found" after DNS update

**Solutions:**
- DNS is still propagating (wait up to 24 hours)
- Verify DNS records are correct using `nslookup souvenirpickers.com`
- Clear browser cache and DNS cache
- Try incognito/private browsing
- Try a different device or network

### Issue: HTTPS not working

**Solutions:**
- Wait for certificate provisioning (can take 10-30 minutes after DNS propagates)
- Check Domain Settings in Netlify for certificate status
- Verify DNS records point to Netlify
- Contact Netlify support if stuck after 24 hours

### Issue: Password reset still not working

**Solutions:**
1. Verify Supabase redirect URLs are saved correctly
2. Check browser console (F12) for errors
3. Test with incognito/private window
4. Verify the reset email contains correct domain link
5. Check Supabase auth logs for errors

### Issue: Old site still showing

**Solutions:**
- Clear browser cache (Ctrl+Shift+Delete)
- Clear DNS cache: `ipconfig /flushdns` (Windows) or `sudo dscacheutil -flushcache` (Mac)
- Use incognito window
- Check from different device/network
- Verify DNS has propagated: https://dnschecker.org

---

## Migration Checklist

- [ ] Custom domain added in Netlify
- [ ] Primary domain configured (www vs root)
- [ ] DNS A record updated for root domain
- [ ] DNS CNAME record updated for www subdomain
- [ ] DNS propagation complete (check dnschecker.org)
- [ ] HTTPS certificate provisioned
- [ ] Force HTTPS enabled
- [ ] Supabase Site URL updated
- [ ] Supabase Redirect URLs updated
- [ ] Tested site access (all URLs)
- [ ] Tested password reset flow
- [ ] Tested login/logout
- [ ] Tested core features
- [ ] Monitored for 1 week before canceling old hosting

---

## Quick Reference

**Netlify Site:** https://app.netlify.com/sites/celebrated-buttercream-4f1ee4

**Supabase Config:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

**DNS Check:** https://dnschecker.org

**Netlify Status:** https://www.netlifystatus.com

---

## Benefits of Full Netlify Hosting

✅ **Password reset works reliably** on both domains
✅ **Single source of truth** - no split hosting confusion
✅ **Automatic HTTPS** with free SSL certificates
✅ **Global CDN** - faster load times worldwide
✅ **Automatic deployments** from git (if you set it up)
✅ **Instant rollbacks** if something breaks
✅ **Better caching** and performance
✅ **Built-in SPA routing** with _redirects file
✅ **Easier maintenance** - one platform for everything
✅ **No more Bluehost hosting costs** (keep domain registration only)

---

## Support

If you need help:

1. **DNS Issues:** Check with your domain registrar support
2. **Netlify Issues:** support@netlify.com or community forum
3. **Supabase Issues:** Check auth logs in dashboard
4. **Password Reset:** Test with browser console open (F12) to see errors

---

## Summary

Your app is now deployed to Netlify. Follow the steps above to:

1. Add custom domain in Netlify
2. Update DNS records
3. Enable HTTPS
4. Update Supabase URLs
5. Test everything thoroughly

**Once DNS propagates and you update Supabase settings, password reset will work perfectly on both domains!**
