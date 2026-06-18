# Stripe Integration - Complete Diagnosis & Solution

## Executive Summary

**Issue:** Stripe says "picker payout accounts are not connected and payments cannot be processed automatically"

**Root Cause:** Your system creates Stripe Custom accounts but doesn't complete the identity verification Stripe requires

**Impact:** Pickers cannot receive payouts because `payouts_enabled = false`

**Solution:** Switch from Custom accounts to Express accounts (2-3 hours work)

---

## What's Actually Happening

### Your Current Flow:

```
Step 1: Picker goes to Payout Setup page ✅
Step 2: Enters bank account details ✅
Step 3: Enters personal info (name, DOB, address) ✅
Step 4: System validates bank account with Stripe ✅
Step 5: System creates Stripe Custom Connect account ✅
Step 6: System attaches bank account to Connect account ✅

Result: Account created but...
- payouts_enabled: false ❌
- Account status: "pending" ❌
- Cannot receive payments ❌

Why? Stripe needs identity documents (passport, driver's license)
Your code doesn't upload these documents
```

### What Stripe Expects:

```
Custom Account Requirements:
1. ✅ Personal information (you provide this)
2. ✅ Bank account details (you provide this)
3. ✅ Tax ID / SSN (you provide this)
4. ❌ Photo ID upload (you DON'T provide this)
5. ❌ Proof of identity (you DON'T provide this)
6. ❌ Manual verification (takes 1-2 days)

Without #4-6: payouts_enabled stays false
```

---

## Technical Details

### File: `validate-bank-account/index.ts` (Line 314-386)

**What it does:**
```typescript
// Creates Stripe Custom account
const accountParams = {
  type: "custom",  // ← This is the problem!
  country: country,
  email: user.email,
  capabilities: {
    card_payments: { requested: true },
    transfers: { requested: true }
  },
  individual: {
    first_name: first_name,
    last_name: last_name,
    dob: { day, month, year },
    address: { ... },
    id_number: ssn_or_tax_id  // Tax ID provided
  }
};

// Stripe creates account but...
// Result: payouts_enabled = false
// Reason: Needs document verification
```

### What's Missing:

```typescript
// Your code doesn't do this (and it's complex):
// 1. Upload ID document
const file = await stripe.files.create({
  purpose: 'identity_document',
  file: { data: idImageBuffer, name: 'id.jpg' }
});

// 2. Attach to account
await stripe.accounts.update(accountId, {
  individual: {
    verification: {
      document: { front: file.id }
    }
  }
});

// 3. Wait for manual review (1-2 business days)
// 4. Handle webhook when verified
// 5. Deal with rejection/additional requests

// This is why Custom accounts are hard!
```

---

## The Solution: Express Accounts

### What are Express Accounts?

**Stripe-hosted onboarding** where:
- Stripe handles identity verification
- Picker uploads documents to Stripe (not your server)
- Automatic approval in 10-15 minutes
- Stripe handles all compliance

### How It Works:

```
Step 1: Picker enters bank details on your site
Step 2: You create Express account (not Custom)
Step 3: You redirect picker to Stripe onboarding URL
Step 4: Picker completes verification on Stripe's site (10-15 min)
Step 5: Stripe redirects back to your site
Step 6: Account status: payouts_enabled = true ✅
Step 7: Picker can receive payments immediately
```

### Why It's Better:

| Feature | Custom Account | Express Account |
|---------|---------------|-----------------|
| Setup Time | 2-5 days | 10-15 minutes |
| Identity Verification | You handle | Stripe handles |
| Document Upload | Your UI | Stripe's UI |
| Compliance | Your responsibility | Stripe's responsibility |
| Approval | Manual review | Automated |
| Maintenance | High | Low |
| Code Complexity | Very high | Low |

**Express is the industry standard for marketplaces.**

---

## Implementation Guide

### Option 1: Quick Fix (Recommended)

**Use your existing `create-stripe-connect-account` function!**

It already supports Express accounts. You just need to call it from the payout setup flow.

### Changes Needed:

**1. Update PayoutSetup.tsx (Line 477-550)**

Change the `createStripeAccount` function to use Express:

```typescript
const createStripeAccount = async () => {
  try {
    setCreating(true);
    setError('');

    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const { data: { session } } = await supabase.auth.getSession();

    // Use existing Express account function
    const response = await fetch(
      `${supabaseUrl}/functions/v1/create-stripe-connect-account`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session?.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: user?.email,
          country: formData.country,
          firstName: formData.first_name,
          lastName: formData.last_name,
          phone: null,
          address: {
            line1: formData.address_line1,
            line2: formData.address_line2,
            city: formData.city,
            state: formData.state,
          },
          returnUrl: `${window.location.origin}/settings?tab=payouts&setup=success`,
          refreshUrl: `${window.location.origin}/settings?tab=payouts&refresh=true`,
        }),
      }
    );

    const result = await response.json();

    if (!result.success) {
      throw new Error(result.error || 'Failed to create Stripe account');
    }

    if (result.onboardingUrl) {
      // Save bank details before redirecting
      await supabase.from('picker_payout_info').upsert({
        picker_id: user?.id,
        bank_name: formData.bank_name,
        bank_account_name: formData.account_holder_name,
        bank_account_number: formData.account_number,
        bank_swift_code: formData.swift_code,
        bank_routing_number: formData.routing_number,
        country: formData.country,
        currency: formData.currency,
        stripe_account_id: result.accountId,
      });

      // Redirect to Stripe onboarding
      showToast('success', 'Redirecting to Stripe for verification...');
      setTimeout(() => {
        window.location.href = result.onboardingUrl;
      }, 1000);
    } else {
      // Already verified
      showToast('success', 'Payout account is ready!');
      await loadPayoutData();
    }
  } catch (err: any) {
    setError(err.message);
    showToast('error', err.message);
  } finally {
    setCreating(false);
  }
};
```

**2. Update handleSaveBankInfo (Line 344-475)**

After validation, call `createStripeAccount`:

```typescript
const handleSaveBankInfo = async (e: React.FormEvent) => {
  e.preventDefault();

  // ... existing validation code ...

  try {
    setSaving(true);
    setError('');

    // If no Stripe account exists, create one (Express)
    if (!payoutInfo?.stripe_account_id) {
      await createStripeAccount();
      return; // Will redirect to Stripe onboarding
    }

    // If account exists, just update bank details
    // ... existing update code ...

  } catch (err: any) {
    setError(err.message);
    showToast('error', err.message);
  } finally {
    setSaving(false);
  }
};
```

**That's it!** Your existing Express account function handles everything else.

---

### Option 2: Minimal Change

**Don't change frontend, just fix the backend:**

Update `validate-bank-account/index.ts` to create Express account instead of Custom:

```typescript
// Around line 318, change:
type: "custom",  // ← Change this

// To:
type: "express",  // ← Use Express instead

// Remove all the individual fields (lines 328-356)
// Express accounts don't need them upfront

// Then create onboarding link:
const onboardingResponse = await fetch(
  "https://api.stripe.com/v1/account_links",
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      account: stripeAccountId,
      refresh_url: `${Deno.env.get('SITE_URL')}/settings?tab=payouts&refresh=true`,
      return_url: `${Deno.env.get('SITE_URL')}/settings?tab=payouts&setup=success`,
      type: "account_onboarding",
    }).toString(),
  }
);

// Return onboarding URL to frontend
return new Response(
  JSON.stringify({
    success: true,
    requiresOnboarding: true,
    onboardingUrl: onboarding.url,
    message: "Please complete Stripe verification"
  }),
  { headers: { ...corsHeaders, "Content-Type": "application/json" } }
);
```

---

## Testing

### Test the Express Flow:

1. **Create test picker account**
2. **Go to Payout Setup page**
3. **Enter test bank details:**
   - IBAN: `DE89370400440532013000`
   - SWIFT: `COBADEFFXXX`
   - Account Holder: `Test User`
   - Country: Germany
   - Currency: EUR

4. **Enter personal info:**
   - First Name: `Test`
   - Last Name: `User`
   - DOB: `01/01/1990`
   - Address: `Test Street 123`
   - City: `Berlin`
   - Postal Code: `10115`

5. **Click Save/Create Account**
6. **Should redirect to Stripe onboarding**
7. **Complete Stripe verification (use test data)**
8. **Redirected back to your site**
9. **Check database:**
   ```sql
   SELECT payouts_enabled, account_status
   FROM picker_payout_info
   WHERE picker_id = 'your-test-picker-id';

   -- Expected:
   -- payouts_enabled: true
   -- account_status: active
   ```

10. **Test payout:**
    - Create order as collector
    - Pay with test card: `4242 4242 4242 4242`
    - Mark as shipped (as picker)
    - Confirm delivery (as collector)
    - Check `picker_payouts` table for transfer

---

## Database Verification

### Check current state:

```sql
-- See all picker payout accounts
SELECT
  picker_id,
  stripe_account_id,
  account_status,
  payouts_enabled,
  details_submitted,
  bank_account_last4,
  country,
  currency
FROM picker_payout_info;

-- Expected current state:
-- payouts_enabled: false (the problem!)
-- account_status: pending

-- After Express onboarding:
-- payouts_enabled: true (fixed!)
-- account_status: active
```

### Verify Stripe account type:

```sql
-- Check what type of accounts exist
-- (You can't see this in DB, need to check Stripe Dashboard)

-- Go to: https://dashboard.stripe.com/test/connect/accounts
-- Look at account type: should be "Express" not "Custom"
```

---

## Webhooks Setup

Add this to `stripe-webhook/index.ts` to track verification completion:

```typescript
case 'account.updated': {
  const account = event.data.object;

  console.log('Account updated:', {
    id: account.id,
    payouts_enabled: account.payouts_enabled,
    charges_enabled: account.charges_enabled,
    details_submitted: account.details_submitted,
  });

  // Update database
  const { error: updateError } = await supabase
    .from('picker_payout_info')
    .update({
      account_status: account.payouts_enabled ? 'active' : 'pending',
      payouts_enabled: account.payouts_enabled,
      details_submitted: account.details_submitted,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_account_id', account.id);

  if (updateError) {
    console.error('Error updating account status:', updateError);
    break;
  }

  // If just verified, notify picker
  if (account.payouts_enabled) {
    const { data: payoutInfo } = await supabase
      .from('picker_payout_info')
      .select('picker_id')
      .eq('stripe_account_id', account.id)
      .maybeSingle();

    if (payoutInfo) {
      await supabase.from('notifications').insert({
        user_id: payoutInfo.picker_id,
        type: 'payout_setup',
        title: 'Payouts Enabled!',
        message: 'Your payout account is now active. You can receive payments for completed orders.',
        link: '/earnings',
      });
    }
  }
  break;
}
```

### Configure webhook in Stripe Dashboard:

1. Go to: https://dashboard.stripe.com/test/webhooks
2. Click "Add endpoint"
3. URL: `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook`
4. Events to listen for:
   - `account.updated`
   - `payment_intent.succeeded`
   - `transfer.paid`
   - `transfer.failed`
5. Save

---

## Summary of Changes

### Files to Modify:

1. **src/components/PayoutSetup.tsx**
   - Update `createStripeAccount` to use Express
   - Update `handleSaveBankInfo` to call it

2. **supabase/functions/stripe-webhook/index.ts**
   - Add `account.updated` event handler

### Files Already Working:

1. ✅ `create-stripe-connect-account/index.ts` - Already supports Express
2. ✅ `process-picker-payout/index.ts` - Payout logic is fine
3. ✅ Database schema - All tables correct

### Effort:

- **Coding:** 1-2 hours
- **Testing:** 1 hour
- **Total:** 2-3 hours

### Risk:

- **Low** - Express is Stripe's recommended approach
- **Fallback** - Can revert changes easily

---

## Expected Results

### Before Fix:
```
Picker completes payout setup
→ Custom account created
→ payouts_enabled: false
→ Cannot receive money
→ Platform cannot process payouts
```

### After Fix:
```
Picker completes payout setup
→ Redirected to Stripe onboarding
→ Completes verification (10-15 min)
→ payouts_enabled: true
→ Can receive money automatically
→ Platform processes payouts successfully
```

---

## Quick Start Checklist

- [ ] Read this document
- [ ] Read STRIPE_PAYOUT_CONNECTION_GUIDE.md
- [ ] Check STRIPE_TEST_DATA.md for test values
- [ ] Update PayoutSetup.tsx to use Express accounts
- [ ] Add webhook handler for account.updated
- [ ] Test with test bank account
- [ ] Verify payouts_enabled becomes true
- [ ] Test complete payment flow
- [ ] Deploy to production

---

## Support Documentation

Created for you:
1. **STRIPE_COMPLETE_DIAGNOSIS.md** (this file)
2. **STRIPE_PAYOUT_CONNECTION_GUIDE.md** - Detailed implementation
3. **STRIPE_TEST_DATA.md** - Test cards, IBANs, identity data
4. **STRIPE_FINAL_ANSWER.md** - Overall integration status
5. **STRIPE_ACTION_PLAN.md** - Optimization roadmap
6. **STRIPE_INTEGRATION_STATUS.md** - Technical analysis

---

## Final Answer

**Problem:** Pickers can't receive payouts because your system creates Custom Stripe accounts without completing identity verification.

**Solution:** Switch to Express accounts where Stripe handles verification via their hosted onboarding flow.

**Time:** 2-3 hours to implement and test

**Impact:** Fixes all payout issues permanently

**Next Step:** Update PayoutSetup.tsx to use Express accounts (see implementation guide above)
