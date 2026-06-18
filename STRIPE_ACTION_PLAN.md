# Stripe Integration - Complete Action Plan

## Executive Summary

**Current Status:** Your Stripe integration is **functional but needs optimization**

**What Works:**
✅ Picker subscriptions (€10/month after 30-day trial)
✅ Basic payment transfers to pickers with 10% platform fee
✅ Stripe Connect account creation for pickers

**What Stripe Means by "Further Integration Required":**
Stripe is telling you to use **proper marketplace payment patterns** instead of simple transfers.

---

## The Problem Explained Simply

### Current Method (Suboptimal):
```
Step 1: Collector pays €100 → Goes to YOUR Stripe account
Step 2: You manually transfer €90 → Picker's Stripe account
Step 3: You keep €10

Issues:
- Two separate transactions
- Tax reporting is messy
- Higher fees
- More complexity
```

### Correct Method (What Stripe Wants):
```
Step 1: Collector pays €100 → Stripe automatically splits:
  - €90 goes directly to Picker's account
  - €10 goes to YOUR account (as application fee)

Benefits:
- One transaction
- Clean tax reporting
- Lower fees
- Stripe's recommended approach
```

---

## Required Changes

### Change 1: Update Payment Collection

**File:** `/supabase/functions/create-payment-intent/index.ts`

**Current code needs to add:**
```typescript
// Add these parameters when creating payment intent:
application_fee_amount: platformFee,  // Your 10% fee
transfer_data: {
  destination: pickerStripeAccountId,  // Picker gets 90%
}
```

This tells Stripe: "Take €100 from collector, give €90 to picker, give €10 to us"

### Change 2: Remove Separate Transfer Function

**File:** `/supabase/functions/process-picker-payout/index.ts`

**What to do:** This function becomes unnecessary because Stripe handles the split automatically when payment is made.

**Keep the function for:** Recording the payout in your database, but remove the actual transfer call.

### Change 3: Update Webhook Handler

**File:** `/supabase/functions/stripe-webhook/index.ts`

**Add handling for:**
- `account.updated` - Track when pickers complete onboarding
- `transfer.paid` - Know when pickers receive money
- `transfer.failed` - Handle payout failures
- `payout.paid` - When money reaches picker's bank account

---

## Step-by-Step Migration Plan

### Phase 1: Testing (Do This First)
1. Test current subscription system
2. Test current payment flow
3. Document what works and what doesn't

### Phase 2: Switch to Application Fees
1. Update `create-payment-intent` function
2. Test with Stripe test mode
3. Verify 90/10 split works correctly

### Phase 3: Simplify Payout Flow
1. Update `process-picker-payout` to just record in database
2. Remove the manual transfer call
3. Test end-to-end flow

### Phase 4: Complete Webhook Integration
1. Add all webhook event handlers
2. Set up webhook endpoint in Stripe dashboard
3. Test all scenarios (success, failure, disputes)

---

## Technical Details

### Stripe Connect Account Types

**You're using:** Express Accounts ✅ (Correct choice)

**Why Express:**
- Fast onboarding (10 minutes)
- Stripe handles compliance
- Good for marketplaces
- Pickers don't need Stripe expertise

### Payment Flow Architecture

**Destination Charges with Application Fees:**
```
┌─────────────┐
│  Collector  │ Pays €100
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│   Your Platform     │ Receives €100
│  (Stripe Account)   │
└──────┬──────────────┘
       │
       ├─────► €10 (Application Fee) → YOUR ACCOUNT
       │
       └─────► €90 (Transfer) → PICKER ACCOUNT
```

### Required Stripe Capabilities

Your pickers need:
- `transfers` capability ✅ (Already requesting this)
- `card_payments` capability ✅ (Already requesting this)

---

## Configuration Checklist

### In Stripe Dashboard:

1. **Connect Settings:**
   - [ ] Enable Express accounts
   - [ ] Set branding (logo, colors)
   - [ ] Configure payout schedule

2. **Webhook Configuration:**
   - [ ] Create webhook endpoint
   - [ ] URL: `https://your-project.supabase.co/functions/v1/stripe-webhook`
   - [ ] Events to listen for:
     - `payment_intent.succeeded`
     - `payment_intent.payment_failed`
     - `account.updated`
     - `transfer.paid`
     - `transfer.failed`
     - `payout.paid`

3. **API Keys:**
   - [ ] Get Stripe Secret Key (already have)
   - [ ] Get Stripe Webhook Secret
   - [ ] Add to Supabase Edge Function secrets

### In Supabase:

1. **Edge Function Secrets:**
   ```bash
   STRIPE_SECRET_KEY=sk_live_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   ```

2. **Database Setup:**
   - [x] Already have all necessary tables
   - [x] Escrow system configured
   - [x] Payout tracking tables exist

---

## Testing Guide

### Test Subscription Flow:

1. Create picker account in TEST mode
2. Add test payment card: `4242 4242 4242 4242`
3. Manually set trial_end_date to yesterday
4. Call `process-monthly-subscriptions` function
5. Verify €10 charge appears
6. Check `picker_subscription_payments` table

### Test Payment Flow:

1. Create picker and collector accounts
2. Picker connects Stripe Connect account (test mode)
3. Collector places order
4. Collector pays with test card: `4242 4242 4242 4242`
5. Check payment splits:
   - €90 to picker Connect account
   - €10 to your platform account
6. Picker marks as shipped
7. Collector confirms delivery
8. Verify escrow released
9. Check `picker_payouts` table

### Test Cards:

```
Success: 4242 4242 4242 4242
Decline: 4000 0000 0000 0002
Requires Auth: 4000 0025 0000 3155
```

---

## Risk Assessment

### Current System Risk: **MEDIUM**

**Why Medium:**
- ✅ Payments work
- ✅ Money reaches pickers
- ⚠️ Using suboptimal pattern
- ⚠️ May have higher fees
- ⚠️ Harder to audit

**After Fixes:** **LOW**

---

## Cost Analysis

### Current Approach (Transfers):
```
Collector pays €100
├─ Stripe fee: ~€2.50 (2.5%)
├─ Transfer fee: ~€0.25
└─ Total cost: €2.75

You keep: €10 - €2.75 = €7.25 (7.25% effective)
Picker gets: €90
```

### Recommended Approach (Application Fees):
```
Collector pays €100
├─ Stripe fee: ~€2.50 (2.5%)
└─ Total cost: €2.50

You keep: €10 - €2.50 = €7.50 (7.5% effective)
Picker gets: €90
```

**Savings:** €0.25 per transaction + cleaner accounting

---

## Quick Start: What To Do Right Now

### Option 1: Keep Current System (Lower Risk)
**Action:** Do nothing, system works
**Downside:** Slightly higher fees, Stripe warning persists
**Timeline:** 0 days

### Option 2: Optimize Now (Recommended)
**Action:** Switch to application fees
**Benefit:** Proper Stripe integration, lower fees
**Timeline:** 2-3 days development + testing

### Option 3: Comprehensive Update (Best Long-Term)
**Action:** Full optimization + webhooks + monitoring
**Benefit:** Production-ready, enterprise-grade
**Timeline:** 1 week development + testing

---

## Support & Resources

### Stripe Documentation:
- [Connect Platform Payments](https://stripe.com/docs/connect/charges)
- [Application Fees](https://stripe.com/docs/connect/destination-charges)
- [Express Accounts](https://stripe.com/docs/connect/express-accounts)

### Your Current Code:
- Subscription: `supabase/functions/process-monthly-subscriptions/`
- Payments: `supabase/functions/create-payment-intent/`
- Payouts: `supabase/functions/process-picker-payout/`
- Connect: `supabase/functions/create-stripe-connect-account/`
- Webhooks: `supabase/functions/stripe-webhook/`

---

## Conclusion

**Your system works!** Stripe's message about "further integration required" is a recommendation, not a blocker.

**Immediate Action:** Test everything in test mode to confirm it works

**Next Step:** Decide if you want to optimize to application fees pattern (recommended but not urgent)

**Long-term:** Complete webhook integration for production robustness
