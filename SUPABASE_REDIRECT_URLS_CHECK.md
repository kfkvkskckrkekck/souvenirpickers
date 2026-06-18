# Supabase Redirect URLs Configuration

## Critical: Verify These Settings in Supabase Dashboard

Since SMTP is configured, the 400/401 errors are likely due to **redirect URL** configuration issues.

### Go to Supabase Dashboard

URL: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

### Required Configuration

#### 1. Site URL
Set this to your production domain:
```
https://souvenirpickers.com
```

#### 2. Redirect URLs (Add ALL of these)
Add these exact URLs to the **Redirect URLs** list:

```
https://souvenirpickers.com
https://souvenirpickers.com/
https://souvenirpickers.com/**
http://localhost:5173
http://localhost:5173/**
```

The `**` wildcard allows all paths under the domain.

### Why This Is Needed

- When users click email confirmation links, Supabase redirects them back to your site
- When users reset passwords, Supabase redirects them to your password reset page
- When users use magic links, Supabase redirects them to your app
- If the redirect URL is not in the whitelist, Supabase returns a 400/401 error

### How to Add Redirect URLs

1. Go to: **Project Settings → Authentication → URL Configuration**
2. Under **Redirect URLs**, click **Add URL**
3. Add each URL listed above, one at a time
4. Save changes

### Current Configuration in Code

Your app uses these redirect patterns:
- Sign up: `${window.location.origin}` (your current domain)
- Password reset: Handled by edge function with proper redirect
- Magic link: Handled by edge function with proper redirect

### Common Issues

**Error: "Email link is invalid or has expired"**
- Cause: Redirect URL not whitelisted
- Solution: Add all redirect URLs above

**Error: 400/401 when signing up**
- Cause: Site URL or redirect URLs not set
- Solution: Configure Site URL and Redirect URLs

**Error: "Cannot confirm email"**
- Cause: Email confirmation enabled but redirect fails
- Solution: Add redirect URLs and verify SMTP

### After Configuration

1. Try signing up with a test email
2. Check your email for confirmation
3. Click the confirmation link
4. Verify you're redirected properly to your site

### Testing Checklist

- [ ] Site URL is set to `https://souvenirpickers.com`
- [ ] All redirect URLs are added (including wildcards)
- [ ] SMTP settings are configured
- [ ] Test sign-up works
- [ ] Test email confirmation works
- [ ] Test password reset works
- [ ] Test magic link works

### If Still Getting Errors

Check Supabase logs:
1. Go to: **Project → Logs → Auth Logs**
2. Look for failed authentication attempts
3. Check the error messages for specific issues

The logs will show exactly what's failing (SMTP errors, redirect errors, etc.)
