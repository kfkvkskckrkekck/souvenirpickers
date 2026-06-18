# Netlify Environment Variables Setup

## Issue
The "invalid API key" error on production (souvenirpickers.com) occurs because Netlify needs environment variables configured in its dashboard. The `.env` file is only used during local development.

## Solution: Configure Environment Variables in Netlify

1. **Go to Netlify Dashboard**
   - Visit: https://app.netlify.com/sites/souvenirpickers/configuration/env
   - Or navigate to: Site settings → Environment variables

2. **Add the following environment variables:**

   ```
   VITE_SUPABASE_URL
   Value: https://bfqvzxczmvfteqbhgyvx.supabase.co

   VITE_SUPABASE_ANON_KEY
   Value: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MTAxODIsImV4cCI6MjA3OTk4NjE4Mn0.2kgZ_VfgN42cs3B-40snDRgThCOVNIJ0BGQ_gdhbzy0

   VITE_STRIPE_PUBLISHABLE_KEY
   Value: pk_live_51SI5wQFlPbAiVNx2hO266AapZfZLrCQZZOShtSjw3X4U0A7VyzRgMSBEx81psE24t7rnAU4CQVQc3uFoEniyFe4g00HbtBusTH
   ```

3. **Click "Save" after adding each variable**

4. **Trigger a new deployment**
   - After saving environment variables, you need to redeploy for changes to take effect
   - Go to: Deploys → Trigger deploy → Deploy site
   - Or the deployment will happen automatically if you have auto-deploy enabled

## Important Notes

- ⚠️ **VITE_ prefix is required**: Vite only exposes environment variables that start with `VITE_` to the client-side code
- 🔒 **Security**: The anon key is safe to expose publicly (it's designed for client-side use)
- 🔄 **Redeploy required**: After adding/changing environment variables, you MUST redeploy the site

## Quick Access Link
https://app.netlify.com/sites/souvenirpickers/configuration/env

## What's Fixed
✅ Database schema is now complete with all tables and triggers
✅ Profile creation trigger handles both auto-confirm and email confirmation
✅ All RLS policies are properly configured
✅ Subscription system with 30-day trial is set up

## Testing After Setup
1. Go to https://souvenirpickers.com
2. Try signing up with a new account
3. It should now work without "invalid API key" errors
4. The profile should be created automatically in the database
