# How to Test the Payout System

## Quick Start Guide

### Option 1: Use the Diagnostic Tool (Easiest)

1. Go to: **https://souvenirpickers.com/test-payout-system.html**
2. Sign in with a picker account
3. Click through the test buttons:
   - **Test Valid Account** - Tests with Stripe test account
   - **Test Invalid Account** - Verifies validation rejects bad data
   - **Check Payout Info** - Shows your saved payout details
   - **Run Full Diagnostic** - Complete system health check

This will test the entire validation flow without entering production data.

**Note:** After deployment, wait a few minutes for Netlify to deploy, then access the URL above.

### Option 2: Manual Testing on Live Site

1. **Sign up as a picker** at https://souvenirpickers.com
2. **Go to Profile Settings** > Payout Information
3. **Test with Stripe's test accounts:**

**Valid US Test Account:**
```
Bank Name: Test Bank
Account Holder: John Doe
Account Number: 000123456789
Routing Number: 110000000
SWIFT Code: BOFAUS3N
Country: US
Currency: USD
```

**Expected Result:**
- Shows "Validating with Stripe..." for 2-3 seconds
- Success message: "Bank account verified and saved successfully!"
- Displays: "Account Number (Verified): •••• 6789"
- Green badge: "Validated by Stripe"

**Invalid Test Account:**
```
Account Number: 000000000000 (all zeros = invalid)
```

**Expected Result:**
- Error message: "Invalid account number"
- Account is NOT saved to database

### Option 3: Database Verification

1. **Open Supabase SQL Editor**
2. **Run the verification script:**

```bash
# Copy the SQL script
cat verify-payout-setup.sql
```

3. **Key queries to run:**

```sql
-- See all validated accounts
SELECT
  p.full_name,
  ppi.bank_name,
  ppi.bank_account_last4,
  ppi.created_at
FROM profiles p
JOIN picker_payout_info ppi ON ppi.picker_id = p.id
WHERE ppi.bank_account_last4 IS NOT NULL;

-- Check pending payouts
SELECT * FROM picker_earnings WHERE status = 'pending';
```

## Testing Real Money Flow (Production)

### Phase 1: Small Test Transaction

1. **Setup:**
   - Use real bank account
   - Complete Stripe Connect with real ID
   - Wait for Stripe approval (1-2 days)

2. **Create Test Order:**
   - Make $5 test purchase as collector
   - Picker fulfills order
   - Collector confirms delivery

3. **Wait for Payout:**
   - 48 hours after delivery confirmation
   - System automatically releases escrow
   - Transfer appears in Stripe Dashboard
   - Bank deposit arrives in 2-5 business days

4. **Verify:**
   - Check `picker_earnings` table for status
   - Check Stripe Dashboard > Transfers
   - Check bank account for deposit

### Phase 2: Monitor Production

**Check these regularly:**
- Failed payouts: `SELECT * FROM picker_earnings WHERE status = 'failed'`
- Pending orders: Check orders ready for escrow release
- Stripe Dashboard: Monitor transfer activity

## What Success Looks Like

### Validation Success
- Button changes to "Validating with Stripe..."
- Success toast appears after 2-3 seconds
- Last 4 digits displayed: "•••• 1234"
- Green "Validated by Stripe" badge visible
- Database has `bank_account_last4` populated

### Payout Success
- Order status: `delivered`
- After 48 hours: `picker_earnings` record created
- Status: `paid`
- Stripe transfer ID present
- Bank deposit received within 2-5 days

## Common Issues

### "Invalid bank account details"
- Check IBAN format (must start with country code)
- Verify routing number (US only, must be 9 digits)
- Remove spaces from account number
- Match country to account number format

### "Bank account validates but no payouts"
- Complete Stripe Connect onboarding
- Verify identity documents approved
- Check `stripe_account_id` is set in profile
- Ensure order is marked as delivered

### "Transfer created but no deposit"
- Wait 2-5 business days for ACH
- Check bank account details are correct
- Verify routing number matches bank
- Check Stripe Dashboard for transfer status

## Testing Checklist

### Test Mode
- [ ] Invalid account is rejected
- [ ] Valid test account passes
- [ ] Last 4 digits displayed
- [ ] Data saved to database
- [ ] Stripe badge appears

### Production Setup
- [ ] Real bank account validates
- [ ] Stripe Connect onboarding completes
- [ ] Identity verification passes
- [ ] Account status shows active

### End-to-End
- [ ] Test order created
- [ ] Order fulfilled
- [ ] Delivery confirmed
- [ ] Escrow releases after 48 hours
- [ ] Transfer appears in Stripe
- [ ] Bank deposit received

## Resources

### Testing Tools
- **Diagnostic Page:** `/test-payout-system.html`
- **SQL Verification:** `verify-payout-setup.sql`
- **Full Guide:** `PAYOUT_TESTING_GUIDE.md`

### Stripe Resources
- **Test Cards:** https://stripe.com/docs/testing
- **Test Bank Accounts:** https://stripe.com/docs/connect/testing
- **Dashboard:** https://dashboard.stripe.com

### Documentation
- **Validation Flow:** `PAYOUT_VALIDATION_COMPLETE.md`
- **Complete Testing:** `PAYOUT_TESTING_GUIDE.md`

## Support

If you encounter issues:
1. Check the diagnostic tool results
2. Review database verification queries
3. Check Stripe Dashboard logs
4. Verify edge function deployment
5. Contact support with error details
