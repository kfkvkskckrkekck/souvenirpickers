# Stripe Payout Connection Issue - Complete Guide

## The Problem

Stripe is showing: **"Picker payout accounts are not connected and payments cannot be processed automatically"**

## Root Cause

Your system creates **Stripe Custom accounts** for pickers when they enter their bank details. However, Stripe requires these accounts to complete additional verification steps before they can receive payouts.

## How Your System Currently Works

### Step-by-Step Flow:

```
1. Picker enters bank account details in PayoutSetup.tsx
   ├─ Bank name, account number, SWIFT/routing
   ├─ Personal info: name, DOB, address
   └─ Tax ID (SSN, CNP, etc.)

2. Frontend calls validate-bank-account edge function

3. Edge function:
   ├─ Validates bank account with Stripe (creates token)
   ├─ Creates Stripe Custom Connect account (if doesn't exist)
   ├─ Attaches bank account to Connect account
   └─ Saves info to picker_payout_info table

4. Problem: Account status = "pending"
   ├─ charges_enabled: false
   ├─ payouts_enabled: false ❌
   └─ details_submitted: depends on requirements
```

## Why Payouts Are Disabled

Stripe Custom accounts need **additional verification** that your system isn't providing:

### Required by Stripe:
1. ✅ Identity information (first name, last name, DOB)
2. ✅ Address information
3. ✅ Tax ID / SSN
4. ✅ Bank account details
5. ❌ **Identity document** (passport, driver's license, ID card)
6. ❌ **Business verification** (if applicable)
7. ❌ **Additional company documents** (some countries)

### Why It's Not Working:
```typescript
// Current: Custom account created but not fully verified
type: "custom",
capabilities: {
  card_payments: { requested: true },
  transfers: { requested: true }
}

// Result:
payouts_enabled: false ← Stripe won't enable until identity verified
```

---

## Solution Options

### Option 1: Switch to Express Accounts (RECOMMENDED)

**What are Express accounts?**
- Stripe-hosted onboarding flow
- Picker completes verification on Stripe's website
- 10-15 minutes to complete
- Stripe handles all compliance

**Pros:**
- ✅ Easiest to implement
- ✅ Stripe handles verification
- ✅ Better compliance
- ✅ Faster approval
- ✅ Already partially implemented in your code

**Cons:**
- ⚠️ Picker leaves your site for onboarding
- ⚠️ Takes 10-15 minutes

**Implementation:**

Your `create-stripe-connect-account` function already supports this! You just need to use it instead of the Custom account approach.

**Code Change Needed:**

In `validate-bank-account/index.ts`, replace Custom account creation (lines 314-386) with a call to your existing Express account function:

```typescript
// Instead of creating Custom account, redirect to Express onboarding
const connectResponse = await fetch(
  `${supabaseUrl}/functions/v1/create-stripe-connect-account`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: user.email,
      country: country,
      firstName: first_name,
      lastName: last_name,
      phone: null,
      address: {
        line1: address_line1,
        line2: address_line2,
        city: city,
        state: state,
        postal_code: postal_code,
      },
      returnUrl: `${Deno.env.get('SITE_URL')}/settings?tab=payouts&success=true`,
      refreshUrl: `${Deno.env.get('SITE_URL')}/settings?tab=payouts&refresh=true`,
    }),
  }
);

const connectResult = await connectResponse.json();

if (connectResult.onboardingUrl) {
  // Return the onboarding URL for picker to complete
  return new Response(
    JSON.stringify({
      success: true,
      requiresOnboarding: true,
      onboardingUrl: connectResult.onboardingUrl,
      message: "Please complete Stripe onboarding to enable payouts"
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}
```

---

### Option 2: Complete Custom Account Verification

**What's needed:**
- Upload identity documents via Stripe API
- Wait for Stripe to review (1-2 business days)
- Handle verification updates via webhooks

**Pros:**
- ✅ Picker never leaves your site
- ✅ Fully white-labeled experience

**Cons:**
- ❌ Complex to implement
- ❌ Need to handle document uploads
- ❌ Slower approval (manual review)
- ❌ More maintenance

**Implementation:**

This requires significant additional code:

1. Add document upload UI in PayoutSetup.tsx
2. Upload documents to Stripe File API
3. Attach documents to Custom account
4. Wait for verification
5. Handle webhook events for verification status

**Not recommended unless you have specific requirements.**

---

### Option 3: Hybrid Approach

**How it works:**
1. Save bank details in your database
2. Create Express account
3. Pre-fill Stripe onboarding with saved data
4. Picker completes verification on Stripe

**Pros:**
- ✅ Best user experience
- ✅ Picker enters data once
- ✅ Fast approval
- ✅ Simple to implement

**Cons:**
- ⚠️ Still requires Stripe onboarding step

**This is the BEST approach.**

---

## Recommended Implementation Plan

### Phase 1: Quick Fix (Use Express Accounts)

**Step 1:** Update PayoutSetup.tsx to use Express onboarding

```typescript
// In handleSaveBankInfo, after validation:
const response = await fetch(
  `${supabaseUrl}/functions/v1/create-stripe-connect-account`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: user?.email,
      country: formData.country,
      firstName: formData.first_name,
      lastName: formData.last_name,
      address: {
        line1: formData.address_line1,
        line2: formData.address_line2,
        city: formData.city,
        state: formData.state,
      },
      returnUrl: window.location.href + '?setup=success',
      refreshUrl: window.location.href + '?refresh=true',
    }),
  }
);

const result = await response.json();

if (result.onboardingUrl) {
  // Save bank details first
  await supabase.from('picker_payout_info').upsert({
    picker_id: user?.id,
    bank_name: formData.bank_name,
    bank_account_name: formData.account_holder_name,
    bank_account_number: formData.account_number,
    bank_swift_code: formData.swift_code,
    country: formData.country,
    currency: formData.currency,
  });

  // Redirect to Stripe onboarding
  window.location.href = result.onboardingUrl;
}
```

**Step 2:** Handle return from Stripe

Already implemented! Your code checks for `?setup=success` and `?refresh=true` parameters.

**Step 3:** Test the flow

1. Picker enters bank details
2. Clicks "Save"
3. Redirected to Stripe onboarding
4. Completes verification (10-15 min)
5. Redirected back to your site
6. Account status updates to `payouts_enabled: true`

---

### Phase 2: Polish (Pre-fill Stripe Onboarding)

The Express account creation already supports pre-filling:

```typescript
// In create-stripe-connect-account function
const params = {
  type: "express",
  country: country,
  email: email,
  "capabilities[card_payments][requested]": "true",
  "capabilities[transfers][requested]": "true",
  "business_type": "individual",

  // Pre-fill with data picker already entered
  "individual[first_name]": firstName,
  "individual[last_name]": lastName,
  "individual[phone]": phone,
  "individual[address][line1]": address?.line1,
  "individual[address][city]": address?.city,
  // ... etc
};
```

---

## Testing

### Test Express Onboarding:

1. Go to PayoutSetup page
2. Enter bank details:
   - Test IBAN: `DE89370400440532013000` (Germany)
   - Or US: Account `000123456789`, Routing `110000000`
3. Enter personal info
4. Click Save
5. Should redirect to Stripe onboarding
6. Complete onboarding with test data
7. Redirected back to your site
8. Check database: `payouts_enabled` should be `true`

### Test Payout Flow:

1. Collector places order and pays €100
2. Picker ships item
3. Collector confirms delivery
4. System should transfer €90 to picker
5. Check `picker_payouts` table for record
6. Verify picker receives notification

---

## Database Schema Check

Your `picker_payout_info` table already has all needed fields:

```sql
CREATE TABLE picker_payout_info (
  id uuid PRIMARY KEY,
  picker_id uuid NOT NULL REFERENCES profiles(id),
  stripe_account_id text,
  stripe_external_account_id text,
  bank_name text,
  bank_account_name text,
  bank_account_number text,
  bank_routing_number text,
  bank_swift_code text,
  bank_account_last4 text,
  country text NOT NULL,
  currency text NOT NULL,
  account_status text DEFAULT 'pending',
  payouts_enabled boolean DEFAULT false,
  details_submitted boolean DEFAULT false,
  ...
);
```

✅ All fields present!

---

## Webhook Configuration

To track when pickers complete onboarding:

### Add to stripe-webhook function:

```typescript
case 'account.updated': {
  const account = event.data.object;

  await supabase
    .from('picker_payout_info')
    .update({
      account_status: account.payouts_enabled ? 'active' : 'pending',
      payouts_enabled: account.payouts_enabled,
      details_submitted: account.details_submitted,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_account_id', account.id);

  if (account.payouts_enabled) {
    // Notify picker their account is ready
    await supabase.from('notifications').insert({
      user_id: pickerUser.id,
      type: 'payout_setup',
      title: 'Payouts Enabled',
      message: 'Your payout account is now active! You can receive payments.',
      link: '/earnings',
    });
  }
  break;
}
```

---

## Why Custom Accounts Don't Work

### Stripe's Custom Account Requirements:

1. **Identity Verification:**
   - Photo ID (passport, driver's license)
   - Selfie (liveness check)
   - Additional documents (sometimes)

2. **Business Verification:**
   - Business documents
   - Proof of address
   - Tax documents

3. **Manual Review:**
   - Stripe team reviews (1-2 days)
   - May request additional info

### Your Current Code:
```typescript
// You're providing:
✅ Name, DOB, Address
✅ Tax ID
✅ Bank account

// Stripe still needs:
❌ Photo ID upload
❌ Document verification
❌ Manual review approval
```

**Result:** `payouts_enabled: false` until documents are provided and reviewed.

---

## Comparison: Custom vs Express

### Custom Accounts:
```
Setup Time: 2-5 days (manual review)
User Experience: Stay on your site
Document Upload: Required (you handle)
Compliance: You handle
Verification: Manual by Stripe
Maintenance: High
```

### Express Accounts:
```
Setup Time: 10-15 minutes
User Experience: Redirect to Stripe
Document Upload: Stripe handles
Compliance: Stripe handles
Verification: Automated
Maintenance: Low
```

**Winner: Express Accounts** (for 99% of use cases)

---

## Action Items

### Immediate (Today):
1. ✅ Understand the issue (you're reading this!)
2. ⬜ Test Express onboarding flow
3. ⬜ Verify it works end-to-end

### Short-term (This Week):
1. ⬜ Update PayoutSetup to use Express accounts
2. ⬜ Add webhook handler for account.updated
3. ⬜ Test complete payment flow

### Long-term (Next Month):
1. ⬜ Monitor onboarding completion rates
2. ⬜ Optimize pre-fill data
3. ⬜ Add better status indicators

---

## Expected Results After Fix

### Before:
```
Picker enters bank details
→ System creates Custom account
→ payouts_enabled: false ❌
→ Payments blocked
```

### After:
```
Picker enters bank details
→ Redirected to Stripe onboarding
→ Completes verification (10-15 min)
→ payouts_enabled: true ✅
→ Can receive payments automatically
```

---

## Summary

**Current Problem:**
- System creates Custom Stripe accounts
- Accounts need document verification
- Your code doesn't upload documents
- Result: `payouts_enabled: false`

**Solution:**
- Switch to Express accounts
- Use existing `create-stripe-connect-account` function
- Picker completes Stripe-hosted onboarding
- Automatic approval in 10-15 minutes

**Effort:** 2-3 hours
**Impact:** Fixes all payout issues
**Risk:** Low (Express is Stripe's recommended approach)
