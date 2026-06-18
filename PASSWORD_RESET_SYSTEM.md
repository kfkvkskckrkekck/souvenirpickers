# Password Reset System Documentation

## Overview

This document describes the consolidated password reset system for SouvenirPickers.

## Active Function

### ✅ `send-password-reset` (PRIMARY)
**URL:** `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/send-password-reset`

**Purpose:** Complete password reset flow with email delivery

**Features:**
- Generates secure recovery link via Supabase Auth
- Sends beautiful branded HTML email via SMTP
- Proper CORS headers for browser requests
- Comprehensive error handling
- Link expires in 1 hour

**Usage:**
```typescript
const response = await fetch(`${supabaseUrl}/functions/v1/send-password-reset`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${supabaseKey}`,
  },
  body: JSON.stringify({
    email: 'user@example.com',
    redirectTo: 'https://souvenirpickers.com/reset-password',
  }),
});
```

**Frontend Integration:**
- Used in `src/components/AuthForm.tsx` (line 162)
- Triggered when user clicks "Forgot Password"
- Sends email with reset link to user

**User Flow:**
1. User clicks "Forgot Password" on login page
2. Frontend calls `send-password-reset`
3. User receives email with reset link
4. User clicks link and lands on `/reset-password`
5. `ResetPasswordView.tsx` validates token from URL
6. User enters new password
7. Frontend calls `supabase.auth.updateUser()` to complete reset

---

## Deprecated Functions

### ❌ `reset-user-password` (DO NOT USE)
**Why deprecated:** Insecure - directly updates password without token verification

**Security Issues:**
- Bypasses recovery link flow
- No time-limited token validation
- Could be exploited to reset any user's password
- Lists all users to find email match (inefficient)

### ❌ `generate-recovery-link` (DO NOT USE)
**Why deprecated:** Incomplete - generates link but doesn't send email

**Issues:**
- Returns link in API response (security risk)
- Requires separate email sending implementation
- Redundant with `send-password-reset`

### ❌ `reset-password` (DO NOT USE - RECENTLY DEPLOYED)
**Why deprecated:** Incomplete - missing email functionality and proper CORS

**Issues:**
- Uses outdated Deno import pattern
- Missing CORS headers (won't work from browser)
- Doesn't send email (just calls API endpoint)
- Redundant with `send-password-reset`

---

## Security Considerations

### Token-Based Recovery (Secure) ✅
The current system uses Supabase's built-in recovery token flow:
1. Recovery link contains time-limited JWT token
2. Token automatically expires after 1 hour
3. Token can only be used once
4. User must verify email ownership

### Direct Password Update (Insecure) ❌
Never implement direct password updates without token verification:
- No proof of email ownership
- No time limits
- Can be exploited by attackers

---

## SMTP Configuration

The system requires these environment variables (automatically configured in Supabase):
- `SMTP_HOST` - Email server hostname
- `SMTP_PORT` - Email server port (typically 587)
- `SMTP_USER` - SMTP username
- `SMTP_PASS` - SMTP password (secret)
- `SMTP_FROM` - Sender email address

---

## Testing

To test the password reset flow:

1. **Trigger Reset:**
   ```bash
   curl -X POST https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/send-password-reset \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -d '{"email":"test@example.com","redirectTo":"https://souvenirpickers.com/reset-password"}'
   ```

2. **Check Email:**
   - Verify email received
   - Check spam/junk folder
   - Confirm link format is correct

3. **Complete Reset:**
   - Click link in email
   - Verify redirect to `/reset-password`
   - Enter new password
   - Confirm successful reset

---

## Maintenance

### To Update Email Template:
1. Edit `generatePasswordResetHTML()` function in `send-password-reset/index.ts`
2. Redeploy function using Supabase tools
3. Test with real email to verify rendering

### To Change SMTP Provider:
1. Update SMTP secrets in Supabase dashboard
2. No code changes needed

### To Modify Link Expiry:
This is controlled by Supabase Auth settings, not the edge function.

---

## Troubleshooting

### Email Not Received
1. Check SMTP credentials are correct
2. Verify email isn't in spam folder
3. Check edge function logs for SMTP errors
4. Confirm SMTP server allows the sender address

### Invalid Token Error
1. Link may have expired (1 hour limit)
2. Link may have already been used
3. User should request new reset link

### CORS Errors
1. Verify `send-password-reset` has proper CORS headers
2. Check browser console for specific error
3. Ensure request includes proper Authorization header

---

## Summary

**Use:** `send-password-reset` for all password reset functionality

**Don't Use:** `reset-user-password`, `generate-recovery-link`, `reset-password`

The system is now consolidated to a single, secure, well-tested edge function that handles the complete password reset flow.
