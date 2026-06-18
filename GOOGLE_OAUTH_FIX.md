# Google OAuth "Could Not Connect" Fix

You're seeing a blank screen with "could not connect" because the redirect URLs are not properly configured. Here's how to fix it:

## Step 1: Configure Supabase Redirect URLs

1. Go to your Supabase Dashboard: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx
2. Navigate to **Authentication** → **URL Configuration**
3. Add the following URLs:

### Site URL:
```
http://localhost:5173
```
(Change this to your production domain when deploying)

### Redirect URLs (Add ALL of these):
```
http://localhost:5173/**
http://localhost:5173
https://souvenirpickers.com/**
https://souvenirpickers.com
https://www.souvenirpickers.com/**
https://www.souvenirpickers.com
```

4. Click **Save**

## Step 2: Configure Google Cloud Console

1. Go to Google Cloud Console: https://console.cloud.google.com
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Click on your OAuth 2.0 Client ID
5. Under **Authorized redirect URIs**, add:

```
https://bfqvzxczmvfteqbhgyvx.supabase.co/auth/v1/callback
```

6. Click **Save**

## Step 3: Test Locally

1. Make sure you're running the app locally: `npm run dev`
2. Open http://localhost:5173
3. Click "Sign in with Google"
4. You should be redirected to Google's consent screen
5. After authorizing, you should be redirected back to your app

## Common Issues

### Issue: Still seeing blank screen
**Solution**:
- Clear your browser cache and cookies
- Try in incognito/private mode
- Check browser console for errors (F12)

### Issue: "Redirect URI mismatch" error
**Solution**:
- Make sure the callback URL in Google Cloud Console exactly matches: `https://bfqvzxczmvfteqbhgyvx.supabase.co/auth/v1/callback`
- No trailing slashes
- Exact project ID

### Issue: "Invalid redirect URL" after authentication
**Solution**:
- Make sure your Site URL in Supabase matches where you're running the app
- For local development: `http://localhost:5173`
- For production: `https://souvenirpickers.com`

## Important Notes

1. **Site URL** in Supabase should be where your app is hosted
2. **Redirect URLs** in Supabase should include wildcards (`/**`) to allow deep linking
3. **Authorized redirect URI** in Google should be the Supabase callback URL
4. Changes in Google Cloud Console can take a few minutes to propagate

## Testing Checklist

- [ ] Site URL set in Supabase
- [ ] Redirect URLs added in Supabase (with `/**`)
- [ ] Callback URL added in Google Cloud Console
- [ ] Browser cache cleared
- [ ] Tested in incognito mode
- [ ] Console shows no errors

## After Configuration

Once configured correctly:
1. Click "Sign in with Google"
2. See Google consent screen
3. Authorize the app
4. Redirected back to your app
5. If new user: see profile completion modal
6. If existing user: logged in immediately

If you still have issues after following these steps, check the browser console (F12) for specific error messages and share them for further troubleshooting.
