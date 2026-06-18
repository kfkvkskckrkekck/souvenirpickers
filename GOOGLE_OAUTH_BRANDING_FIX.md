# Fix Google OAuth Branding - Show "souvenirpickers.com" Instead of Supabase URL

## Issue
When users sign in with Google, the OAuth consent screen shows the Supabase project URL instead of your actual domain (souvenirpickers.com).

## Solution - Update Site URL in Supabase

### Step 1: Update Site URL in Supabase Dashboard

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx

2. Navigate to **Authentication** → **URL Configuration**

3. Update the following settings:

   **Site URL:**
   ```
   https://souvenirpickers.com
   ```

   **Redirect URLs:** (Add these if not already present)
   ```
   https://souvenirpickers.com
   https://souvenirpickers.com/**
   https://souvenirpickers.com/auth/callback
   ```

4. Click **Save** to apply changes

### Step 2: Update Google Cloud Console (If Needed)

If you set up Google OAuth in Google Cloud Console, you also need to update it there:

1. Go to Google Cloud Console: https://console.cloud.google.com

2. Select your project

3. Navigate to **APIs & Services** → **Credentials**

4. Click on your OAuth 2.0 Client ID

5. Under **Authorized JavaScript origins**, add:
   ```
   https://souvenirpickers.com
   ```

6. Under **Authorized redirect URIs**, make sure you have:
   ```
   https://bfqvzxczmvfteqbhgyvx.supabase.co/auth/v1/callback
   ```

7. Click **Save**

### Step 3: Update OAuth Consent Screen Branding

To show your brand name instead of the project name:

1. In Google Cloud Console, go to **APIs & Services** → **OAuth consent screen**

2. Update these fields:
   - **App name:** Souvenir Pickers
   - **User support email:** Your support email
   - **Application home page:** https://souvenirpickers.com
   - **Application privacy policy link:** https://souvenirpickers.com/privacy-policy
   - **Application terms of service link:** https://souvenirpickers.com/terms-of-service

3. Under **Authorized domains**, add:
   ```
   souvenirpickers.com
   ```

4. Click **Save and Continue**

### Step 4: Add App Logo (Optional but Recommended)

1. Still in the OAuth consent screen settings

2. Upload your app logo (120x120 pixels minimum)

3. This will show your brand logo instead of a generic icon

## What This Fixes

✅ Google OAuth consent screen will now show "Souvenir Pickers" as the app name
✅ The domain shown will be "souvenirpickers.com" instead of the Supabase URL
✅ Users will see your brand logo (if uploaded)
✅ More professional appearance and builds trust

## Important Notes

- Changes to the OAuth consent screen may take a few minutes to propagate
- Test the login flow after making changes
- Make sure all redirect URLs match exactly (including https://)
- If your app is in testing mode, only test users can sign in

## Testing

After making these changes:

1. Go to https://souvenirpickers.com
2. Click "Sign in with Google"
3. You should now see:
   - "Souvenir Pickers" as the app name
   - Your domain (souvenirpickers.com) mentioned
   - Your app logo (if uploaded)

## Current Configuration

- **Live Site:** https://souvenirpickers.com
- **Supabase Project:** bfqvzxczmvfteqbhgyvx
- **Supabase URL:** https://bfqvzxczmvfteqbhgyvx.supabase.co
