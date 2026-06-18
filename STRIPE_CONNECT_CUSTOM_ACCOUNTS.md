# Stripe Connect Custom Accounts - Direct Bank Linking

## Overview

Your platform now uses **Stripe Custom Connect accounts** - the same approach used by Uber, DoorDash, and similar marketplaces. Pickers simply enter their bank details in your app, and they're ready to receive payments. No Stripe redirects required.

## How It Works

### For Pickers

1. Go to Payout Setup in their dashboard
2. Fill in their bank account details:
   - Bank name
   - Account holder name
   - Account number (IBAN for international)
   - Routing number (US) or SWIFT code (international)
   - Personal info for verification (name, DOB, address, optional tax ID)
3. Click Save
4. Done! They can now receive payments

### Behind the Scenes

When a picker saves their bank info:

1. **Creates Custom Connect Account**: System creates a Stripe Custom Connect account with their details
2. **Links Bank Account**: Attaches their bank account to the Connect account
3. **Ready for Payouts**: Account is immediately active and can receive transfers

### Automatic Payouts

When a collector confirms delivery:

1. **Escrow Release**: System releases funds from escrow
2. **Commission Calculation**:
   - Gross amount (what collector paid)
   - Platform fee: 10%
   - Net amount: 90% goes to picker
3. **Stripe Transfer**: Creates transfer to picker's Connect account
4. **Bank Deposit**: Stripe deposits to picker's bank within 2-7 business days

## Technical Details

### Edge Functions

**`link-bank-to-stripe`**
- Creates Custom Connect accounts
- Links bank accounts using Stripe tokens
- Handles international accounts (IBAN, SWIFT)
- Stores verification details

**`process-picker-payout`**
- Processes automatic payouts when goods are confirmed
- Deducts 10% platform commission
- Creates Stripe transfers to Connect accounts
- Records all transactions in `picker_payouts` table

### Account Type: Custom vs Express

**Why Custom Accounts?**

- **No user redirects**: Everything happens in your app
- **Full control**: You handle the verification and user experience
- **Simpler flow**: Just enter bank details and go
- **Like Uber/DoorDash**: Industry-standard approach

**Express Accounts (what you had before)**
- Required redirecting users to Stripe
- Stripe handles onboarding
- More verification requirements upfront
- Caused "Restricted" status issues

## Commission Structure

```
Collector pays: $100.00
Platform keeps: $10.00 (10%)
Picker receives: $90.00 (90%)
```

All commission calculations happen in `process-picker-payout`:
```typescript
const platformFeePercent = 0.10;
const platformFee = Math.round(grossAmount * platformFeePercent);
const netAmount = grossAmount - platformFee;
```

## Database Tables

**`picker_payout_info`**
- Stores Stripe Connect account IDs
- Bank account last 4 digits
- Account status and payout eligibility

**`picker_payouts`**
- Records all payout transactions
- Tracks gross amount, fees, and net amounts
- Links to orders and escrow records

**`payment_escrow`**
- Holds funds until delivery confirmation
- Releases to picker after confirmation
- Tracks release status and timestamps

## Testing

To test the flow:

1. **Create Test Picker Account**: Sign up as a picker
2. **Add Bank Info**: Use Stripe test bank accounts:
   - US: Account `000123456789`, Routing `110000000`
   - EU: IBAN `DE89370400440532013000`
3. **Create Test Order**: Have a collector order from the picker
4. **Process Payment**: Collector pays (use test card `4242424242424242`)
5. **Confirm Delivery**: Collector confirms goods received
6. **Check Payout**: View in Earnings page and Stripe dashboard

## Stripe Dashboard

View all payouts in your Stripe dashboard:
- **Connect > Accounts**: See all picker Custom accounts
- **Balance > Transfers**: See all payouts to pickers
- **Reports**: Download transaction reports

## Key Differences from Other Marketplaces

**What's the Same:**
- Direct bank account collection in-app
- No user redirects to payment processor
- Automatic payouts after completion
- Platform commission deduction

**What's Different:**
- Some platforms use ACH direct (not Stripe)
- Some verify gradually (instant approval, verify later)
- Your platform: Collects verification info upfront for compliance

## Security & Compliance

- Uses Stripe Custom accounts (PCI-compliant)
- Collects required identity info for regulations
- Bank details never stored in your database (only in Stripe)
- All transfers are logged and auditable
- Platform retains commission automatically

## Next Steps

Your system is now configured for direct bank linking. To go live:

1. Switch Stripe from test mode to live mode
2. Update `STRIPE_SECRET_KEY` with live key
3. Test with real bank account in test mode first
4. Deploy and monitor first few payouts
5. Set up automatic payout schedules if desired

The platform is ready for real transactions.
