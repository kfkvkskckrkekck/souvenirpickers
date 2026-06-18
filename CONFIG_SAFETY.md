# Configuration Safety Guards

This project has multiple safeguards to prevent using the wrong Supabase project.

## Safeguards Implemented

### 1. Runtime Validation in Code

**File:** `src/lib/supabase.ts`

The Supabase client initialization now:
- ❌ **NO hardcoded fallback values** - will fail immediately if env vars are missing
- ✅ **Validates project ID** - checks that the URL contains the expected project ID `bfqvzxczmvfteqbhgyvx`
- ✅ **Clear error messages** - tells you exactly what's wrong and what's expected

If you try to use the wrong project, the app will crash immediately with a clear error message instead of silently using wrong credentials.

### 2. Build-Time Validation

**File:** `scripts/validate-config.js`

Automatically runs before every build (`prebuild` script) to:
- ✅ Check that `.env` file exists
- ✅ Verify required environment variables are set
- ✅ Detect the old/wrong project ID (`usgqobihywfaefrxgdqx`)
- ✅ Confirm the correct project ID is being used (`bfqvzxczmvfteqbhgyvx`)
- ✅ Validate the anon key format

**Run manually:**
```bash
npm run validate
```

### 3. No Hardcoded Fallbacks

All hardcoded Supabase URLs and keys have been removed from:
- ✅ `src/lib/supabase.ts` - main Supabase client
- ✅ `src/components/PayoutSetup.tsx` - edge function calls

## Expected Configuration

Your `.env` file should contain:

```env
VITE_SUPABASE_URL=https://bfqvzxczmvfteqbhgyvx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMyNDc2ODcsImV4cCI6MjA0ODgyMzY4N30.GzCdHjV_LKHFEWJkN_yYbvxhYFoROSz3w0qH3dEPyWo
VITE_STRIPE_PUBLIC_KEY=your_stripe_key_here
```

**Project ID:** `bfqvzxczmvfteqbhgyvx`

## What Happens if Config is Wrong

### During Build:
```bash
npm run build
```
Will run validation first and FAIL with a clear error message if:
- .env file is missing
- Environment variables are not set
- Wrong project ID is detected (e.g., old project `usgqobihywfaefrxgdqx`)

### During Runtime:
The app will crash immediately on load with an error message showing:
- What project ID was expected
- What URL was actually configured
- Instructions to fix the `.env` file

## Verification Checklist

Before deploying or making changes:

1. ✅ Run `npm run validate` to check configuration
2. ✅ Verify no hardcoded URLs in your code:
   ```bash
   grep -r "usgqobihywfaefrxgdqx" src/
   ```
   Should return nothing!
3. ✅ Check edge functions are deployed to correct project:
   - Dashboard: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx
4. ✅ Build succeeds: `npm run build`

## Emergency: Wrong Project Detected

If you discover the wrong project is being used:

1. **Stop immediately** - don't make any more changes
2. Update `.env` file with correct credentials
3. Run `npm run validate` to verify
4. Redeploy all edge functions to correct project
5. Run `npm run build` to rebuild with correct config

## Maintenance

When updating to a new Supabase project (intentionally):

1. Update `EXPECTED_PROJECT_ID` in `src/lib/supabase.ts`
2. Update `EXPECTED_PROJECT_ID` in `scripts/validate-config.js`
3. Update this documentation
4. Update all environment files
5. Redeploy all edge functions
