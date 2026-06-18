# Stripe Integration Status Report

## Overview

This document analyzes the current Stripe integration for:
1. **Picker Monthly Subscriptions** (after 30-day trial)
2. **Collector-to-Picker Payments** (with 10% platform fee)

---

## 1. Picker Subscription System ✅

### Current Implementation

**Function:** `process-monthly-subscriptions`

**How It Works:**
1. Runs automatically (cron job scheduled)
2. Finds pickers whose trial ended (30 days) or payment is due
3. Charges €10.00/month from picker's saved payment card
4. Records payment in `picker_subscription_payments` table
5. Updates `next_payment_due` date to +30 days
6. Sends notification to picker

**Trial Period:**
- Currently set to **30 days** (see migration `20251205194744`)
- After 30 days, monthly billing begins automatically

### What's Working:
✅ Trial period tracking
✅ Automatic monthly billing
✅ Payment method storage
✅ Payment failure handling
✅ Notification system
✅ Subscription status management

### Payment Flow:
```
Day 0: Picker signs up → Trial begins
Day 30: Trial ends → First payment charged (€10)
Day 60: Second payment charged (€10)
Day 90: Third payment charged (€10)
... continues monthly
```

### Database Tables:
- `profiles.trial_end_date` - Tracks when trial ends
- `profiles.next_payment_due` - Tracks next payment date
- `profiles.subscription_status` - active/past_due/cancelled
- `picker_subscription_payments` - Payment history

---

## 2. Collector-to-Picker Payment System ⚠️

### Current Implementation

**Function:** `process-picker-payout`

**How It Works:**
1. Collector pays for order (100% held in escrow)
2. Picker ships item
3. Collector confirms delivery
4. System calculates: `platformFee = 10%`, `pickerAmount = 90%`
5. **Stripe Transfer** sends 90% to picker's Stripe Connect account

### Architecture:

```
Collector Payment Flow:
1. Collector pays €100 → Your Stripe Account (escrow)
2. €10 (10%) → Platform keeps
3. €90 (90%) → Stripe Transfer → Picker's Connect Account
```

### What's Implemented:
✅ Stripe Connect Express accounts for pickers
✅ Onboarding flow for pickers
✅ 10% platform fee calculation
✅ Stripe Transfers API
✅ Escrow system
✅ Payout tracking

### What Stripe Says "Further Integration Required"

Stripe is likely referring to **one of these**:

#### A. Application Fee Method (Recommended)
Instead of regular transfers, use **application fees**:

**Current (Transfers):**
```
Collector pays €100 → Your account
You transfer €90 → Picker account
```

**Better (Application Fees):**
```
Collector pays €100 → Automatically splits:
  - €90 → Picker account (instant)
  - €10 → Your account (fee)
```

**Benefits:**
- Stripe handles the split automatically
- Better for tax reporting
- Clearer audit trail
- Preferred by Stripe

#### B. Account Verification
Pickers need to complete:
- Identity verification
- Bank account connection
- Tax information (for EU: VAT)
- Terms of service acceptance

#### C. Webhooks Setup
You need to handle Stripe webhooks for:
- `account.updated` - When picker completes onboarding
- `transfer.created` - When payout is sent
- `transfer.failed` - When payout fails
- `payout.paid` - When money reaches picker's bank

---

## 3. What Needs To Be Done

### Priority 1: Switch to Destination Charges with Application Fees

**Why:** This is the proper way to handle marketplace payments in Stripe.

**Current Code (Line 87-106 in process-picker-payout):**
```typescript
// Current: Uses Transfers
const transferResponse = await fetch("https://api.stripe.com/v1/transfers", {
  method: "POST",
  body: new URLSearchParams({
    amount: netAmount.toString(),
    destination: pickerAccount.stripe_account_id,
  })
});
```

**Should Be:**
```typescript
// Better: Use Destination Charges with Application Fee
const paymentIntentResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
  method: "POST",
  body: new URLSearchParams({
    amount: grossAmount.toString(), // Full amount
    currency: "eur",
    application_fee_amount: platformFee.toString(), // 10% to platform
    transfer_data: {
      destination: pickerAccount.stripe_account_id, // 90% to picker
    }
  })
});
```

### Priority 2: Webhook Integration

Create webhook handler for:
- Account verification status
- Transfer events
- Payout events
- Dispute events

### Priority 3: Payout Status Dashboard

Pickers need to see:
- Pending payouts
- Completed payouts
- Failed payouts
- When money will reach their bank

---

## 4. Testing Checklist

### Subscription Testing:
- [ ] Create picker account
- [ ] Add payment card
- [ ] Wait 30 days OR manually trigger `process-monthly-subscriptions`
- [ ] Verify €10 charge appears
- [ ] Verify next payment date is set
- [ ] Verify notification sent

### Payment Testing:
- [ ] Create collector and picker accounts
- [ ] Picker connects Stripe account
- [ ] Collector places order and pays €100
- [ ] Picker ships item
- [ ] Collector confirms delivery
- [ ] Verify €90 transfer to picker
- [ ] Verify €10 kept by platform
- [ ] Check `picker_payouts` table

---

## 5. Current Issues

### Issue 1: Not Using Application Fees
**Problem:** Using Transfers instead of proper destination charges
**Impact:** Less efficient, worse tax reporting
**Solution:** Switch to destination charges with `application_fee_amount`

### Issue 2: Manual Payout Trigger
**Problem:** Payouts require manual function call after delivery confirmation
**Current:** Must call `process-picker-payout` edge function
**Solution:** Already have trigger in migration `20260219210628` - should work automatically

### Issue 3: No Webhook Handler
**Problem:** Not listening to Stripe events
**Impact:** Can't react to payout failures, disputes, etc.
**Solution:** Create `stripe-webhook` handler (already exists but may need updates)

---

## 6. Summary

### What Works Now:
✅ Picker subscriptions (€10/month after 30-day trial)
✅ Stripe Connect account creation
✅ Basic transfers to pickers
✅ 10% platform fee calculation

### What Needs Improvement:
⚠️ Switch from Transfers to Application Fees
⚠️ Complete webhook integration
⚠️ Add payout status tracking
⚠️ Improve error handling

### Risk Level:
**Medium** - System works but uses suboptimal Stripe integration pattern

---

## 7. Next Steps

1. **Immediate:** Test current system end-to-end
2. **Short-term:** Switch to application fees pattern
3. **Medium-term:** Complete webhook integration
4. **Long-term:** Add advanced features (instant payouts, multi-currency)

---

## 8. Code Locations

**Subscription System:**
- Function: `/supabase/functions/process-monthly-subscriptions/index.ts`
- Migration: `20251127133057_add_picker_subscription_payments.sql`
- Cron: `20251203180837_create_trial_ending_reminders.sql`

**Payout System:**
- Function: `/supabase/functions/process-picker-payout/index.ts`
- Migration: `20251127163349_create_picker_payout_info_table.sql`
- Trigger: `20260219210628_trigger_stripe_payout_on_delivery_confirmation.sql`

**Connect Setup:**
- Function: `/supabase/functions/create-stripe-connect-account/index.ts`
- Component: `/src/components/PayoutSetup.tsx`
