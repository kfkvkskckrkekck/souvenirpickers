# Supabase Redirect URLs Configuration

After your DNS is configured and pointing to Netlify, update these settings in Supabase.

---

## Access Supabase Configuration

**Direct Link:** https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration

**Or navigate manually:**
1. Go to https://supabase.com/dashboard
2. Select project: `bfqvzxczmvfteqbhgyvx`
3. Click **Authentication** (shield icon) in sidebar
4. Click **URL Configuration**

---

## Site URL

Set the **Site URL** to your primary domain:

```
https://www.souvenirpickers.com
```

(Or use `https://souvenirpickers.com` if you chose root as primary in Netlify)

---

## Redirect URLs

Add these URLs in the **Redirect URLs** section (paste all at once, one per line):

```
https://www.souvenirpickers.com
https://souvenirpickers.com
https://www.souvenirpickers.com/*
https://souvenirpickers.com/*
https://www.souvenirpickers.com/reset-password
https://souvenirpickers.com/reset-password
```

---

## Why These URLs?

- **Both domain versions** (www and root) are included so password reset works regardless of which URL the user uses
- **Wildcard paths** (`/*`) allow any route on your site
- **Specific reset-password paths** ensure the password reset page is explicitly allowed

---

## Save and Test

1. Click **"Save"** at the bottom
2. Wait 1-2 minutes for changes to take effect
3. Test password reset flow:
   - Go to your site
   - Click "Forgot Password?"
   - Enter your email
   - Check email for reset link
   - Click link and verify you're taken to the reset form

---

## Important Notes

- Update these URLs **after** DNS propagation is complete
- Test from an incognito/private window to avoid cache issues
- If password reset still doesn't work, clear browser cache and try again
- Check browser console (F12) for any error messages

---

## Screenshot Reference

Your configuration should look like this:

**Site URL:**
```
https://www.souvenirpickers.com
```

**Redirect URLs:** (list)
```
https://www.souvenirpickers.com
https://souvenirpickers.com
https://www.souvenirpickers.com/*
https://souvenirpickers.com/*
https://www.souvenirpickers.com/reset-password
https://souvenirpickers.com/reset-password
```

Click **Save** when done!
