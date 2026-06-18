# Stripe Connect Required for Payouts

## Overview

Manual bank account entry has been **removed** from the platform. All pickers must now use **Stripe Connect** to receive payouts.

## Why This Change?

Manual bank details stored in the database cannot be used for automatic payouts. The payout processing functions require Stripe Connect accounts to:
- Transfer funds automatically
- Handle international payments
- Provide tax compliance
- Offer buyer/seller protection
- Enable instant payouts

## What Changed

### 1. PayoutSetup Component
- Removed the "Enter Bank Details Manually" option
- Now only shows "Connect with Stripe" button
- Simplified UI to single payout method

### 2. ProfileView Component
- Removed entire manual bank account form (IBAN, SWIFT, routing number, etc.)
- Only displays Stripe Connect account information
- Removed auto-fill logic for bank names from IBANs

### 3. Database Schema
The following fields in `picker_payout_info` are **deprecated** (but not removed to avoid data loss):
- `bank_name`
- `bank_account_number`
- `bank_account_name`
- `bank_routing_number`
- `bank_swift_code`
- `is_verified`

Only these fields are now actively used:
- `stripe_account_id` (required)
- `payouts_enabled` (set by Stripe)
- `account_status` (set by Stripe)
- `bank_account_last4` (set by Stripe)
- `country`
- `currency`

## For Pickers

When pickers click "Set Up Payout Account":
1. They're redirected to Stripe's onboarding flow
2. Stripe collects their bank details securely
3. Stripe verifies their identity and account
4. Once approved, `payouts_enabled` is set to true
5. Automatic payouts happen after order completion

## Payout Flow

```
Order Completed → 48-hour confirmation period →
Automatic Stripe Transfer → Funds in picker's bank (2-3 days)
```

The `process-picker-payout` edge function handles transfers via Stripe's API.

## Benefits

- **Automatic**: No manual processing needed
- **Secure**: Stripe handles all sensitive banking data
- **Global**: Supports 40+ countries
- **Compliant**: Tax forms (1099, etc.) handled by Stripe
- **Fast**: Payouts arrive in 2-3 business days
- **Transparent**: Full audit trail of all transfers

## Migration Notes

Existing pickers with manual bank details stored need to:
1. Go to Profile → Payout Account
2. Click "Connect with Stripe"
3. Complete Stripe onboarding

Their old manual bank details remain in the database but are not used for payouts.
