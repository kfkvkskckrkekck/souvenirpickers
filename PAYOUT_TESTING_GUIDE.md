# Payout System Testing Guide

## Overview
Complete guide to test the payout validation flow and verify pickers can receive real payouts.

## Testing Phases

### Phase 1: Bank Account Validation (Test Mode)

Test that bank account validation works correctly with Stripe's test mode.

#### Step 1: Setup Test Picker Account
1. Go to https://souvenirpickers.com
2. Sign up as a new picker (or use existing test account)
3. Navigate to Profile Settings
4. Scroll to "Payout Information" section

#### Step 2: Test Invalid Bank Account
Test that invalid accounts are properly rejected:

**Invalid Account Number:**
```
Bank Name: Test Bank
Account Holder: John Doe
Account Number: 000000000000 (invalid)
Routing Number: 110000000 (valid US routing)
SWIFT Code: BOFAUS3N
Country: US
Currency: USD
```

Expected result: Error message "Invalid account number" from Stripe

**Invalid Routing Number:**
```
Bank Name: Test Bank
Account Holder: John Doe
Account Number: 000123456789
Routing Number: 999999999 (invalid)
SWIFT Code: BOFAUS3N
Country: US
Currency: USD
```

Expected result: Error message "Invalid routing number" from Stripe

#### Step 3: Test Valid Test Account
Use Stripe's test bank account numbers:

**US Test Account:**
```
Bank Name: Test Bank
Account Holder: John Doe
Account Number: 000123456789
Routing Number: 110000000
SWIFT Code: BOFAUS3N
Country: US
Currency: USD
```

**Expected Results:**
- Button shows "Validating with Stripe..."
- After 2-3 seconds: "Bank account verified and saved successfully!"
- Shows: "Account Number (Verified): •••• 6789"
- Green badge: "Validated by Stripe"

**IBAN Test Account (European):**
```
Bank Name: Test Bank
Account Holder: John Doe
Account Number: DE89370400440532013000
Routing Number: (leave empty)
SWIFT Code: DEUTDEFF
Country: DE
Currency: EUR
```

#### Step 4: Verify Database Storage
Check the data was saved correctly:

1. Open browser console
2. Run:
```javascript
const { data, error } = await supabase
  .from('picker_payout_info')
  .select('*')
  .eq('picker_id', (await supabase.auth.getUser()).data.user.id)
  .single();
console.log('Payout info:', data);
```

Verify:
- `bank_account_last4` contains last 4 digits
- All other fields are saved correctly
- Account number is stored without spaces

---

## Phase 2: Stripe Connect Setup (Required for Real Payouts)

Pickers need Stripe Connect accounts to receive real money.

#### Step 1: Complete Identity Verification
After bank account is validated:

1. Click "Create Stripe Account" button
2. Edge function creates Stripe Connect account
3. System redirects to Stripe onboarding
4. Complete Stripe's onboarding process:
   - Verify identity (upload ID)
   - Confirm business details
   - Accept Stripe terms

#### Step 2: Test Mode Stripe Connect
For testing, you can use Stripe's test mode:

**Test SSN (US):** `000-00-0000`
**Test EIN (US Business):** `00-0000000`
**Test ID:** Use any test document

#### Step 3: Verify Account Status
After onboarding:

1. Check that "Payout Setup Complete" appears
2. Verify `payouts_enabled: true` in database
3. Check Stripe Dashboard for the connected account

---

## Phase 3: End-to-End Payout Test (Test Mode)

Test the complete payout flow with test transactions.

#### Prerequisites:
- Picker has validated bank account
- Picker has completed Stripe Connect
- Picker has an active listing

#### Step 1: Create Test Order
1. Sign in as a collector (different account)
2. Add picker's listing to cart
3. Complete checkout with test card: `4242 4242 4242 4242`
4. Order status: `pending`

#### Step 2: Simulate Order Fulfillment
1. Sign in as picker
2. Go to Orders > Accept order
3. Upload pickup video (optional)
4. Mark as shipped
5. Wait or update order status to `delivered`

#### Step 3: Collector Confirms Delivery
1. Sign in as collector
2. Go to Orders
3. Click "Confirm Delivery" on the order
4. Order status changes to `delivered`

#### Step 4: Trigger Escrow Release
The system should automatically release funds after 48 hours, but for testing:

1. Run the escrow release function manually:
```sql
-- In Supabase SQL Editor
SELECT process_escrow_releases();
```

Or call the edge function:
```javascript
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/process-escrow-releases`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    },
  }
);
```

#### Step 5: Verify Payout Created
Check that payout was created:

1. Query database:
```sql
SELECT * FROM picker_earnings
WHERE picker_id = 'YOUR_PICKER_ID'
ORDER BY created_at DESC
LIMIT 1;
```

2. Check Stripe Dashboard:
   - Go to Connect > Accounts
   - Find the picker's account
   - Check Transfers tab
   - Should see test transfer to bank account

Expected in test mode:
- Payout status: `paid` (instant in test mode)
- Amount: Order total minus platform fee (10%)

---

## Phase 4: Production Real Money Test

Test with real money in production mode.

### IMPORTANT: Use Small Amounts
Start with minimum test amounts ($0.50 - $5.00) to verify the flow works.

#### Prerequisites:
1. Stripe account in LIVE mode (not test mode)
2. Real bank account connected
3. Real identity verification completed
4. Platform has real Stripe secret key configured

#### Step 1: Real Bank Account Validation
1. Use your real bank account details
2. Stripe will validate routing/account format
3. Account is saved with last 4 digits

**Note:** In production, Stripe validates but doesn't transfer test amounts yet.

#### Step 2: Complete Real Stripe Connect
1. Create Stripe Connect account (production)
2. Upload real ID documents
3. Provide real business information
4. Wait for Stripe approval (can take 1-2 days)

#### Step 3: Create Small Test Order
1. Create real order with small amount ($1-$5)
2. Use real credit card (not test card)
3. Complete order fulfillment
4. Collector confirms delivery
5. Wait for 48-hour holding period

#### Step 4: Automatic Payout
After 48 hours:
- Cron job triggers `process_escrow_releases()`
- Transfer created to picker's Stripe account
- Stripe transfers to picker's bank (2-5 business days)

#### Step 5: Verify Real Bank Deposit
Check your actual bank account:
- 2-5 business days for ACH (US)
- 3-7 business days for international
- Look for deposit from "STRIPE" or "SOUVENIR PICKERS"

---

## Verification Checklist

### Bank Account Validation
- [ ] Invalid accounts are rejected with specific errors
- [ ] Valid test accounts pass validation
- [ ] Last 4 digits are displayed correctly
- [ ] "Validated by Stripe" badge appears
- [ ] Database stores account info correctly

### Stripe Connect
- [ ] Stripe account creation works
- [ ] Onboarding redirect works
- [ ] Identity verification completes
- [ ] Account status updates to active
- [ ] `payouts_enabled` becomes true

### Test Payouts
- [ ] Order payment holds in escrow
- [ ] Escrow releases after delivery confirmation
- [ ] Transfer appears in Stripe dashboard
- [ ] Picker earnings record created
- [ ] Platform fee calculated correctly (10%)

### Production Payouts
- [ ] Real bank account validates
- [ ] Real Stripe Connect approved
- [ ] Real payment processes
- [ ] Real transfer created
- [ ] Real bank deposit received

---

## Common Issues & Solutions

### Issue: "Invalid bank account details"
**Solution:**
- Verify IBAN/account number format
- Check routing number is correct
- Ensure country matches account number
- Try removing spaces from IBAN

### Issue: Bank account validates but no payouts
**Solution:**
- Verify Stripe Connect is completed
- Check `payouts_enabled` is true
- Confirm identity verification passed
- Check Stripe Dashboard for account status

### Issue: Transfer created but no bank deposit
**Solution:**
- Wait 2-5 business days for ACH
- Check bank account details are correct
- Verify routing number matches bank
- Check Stripe Dashboard for transfer status

### Issue: "Payouts not enabled"
**Solution:**
- Complete Stripe onboarding
- Verify identity documents
- Wait for Stripe approval
- Check email for Stripe requests

---

## Monitoring Production Payouts

### Database Queries

**Check pending payouts:**
```sql
SELECT
  pe.*,
  p.full_name as picker_name,
  p.email
FROM picker_earnings pe
JOIN profiles p ON pe.picker_id = p.id
WHERE pe.status = 'pending'
ORDER BY pe.created_at DESC;
```

**Check failed payouts:**
```sql
SELECT
  pe.*,
  p.full_name as picker_name,
  p.email
FROM picker_earnings pe
JOIN profiles p ON pe.picker_id = p.id
WHERE pe.status = 'failed'
ORDER BY pe.created_at DESC;
```

**Check total payouts to picker:**
```sql
SELECT
  picker_id,
  COUNT(*) as total_payouts,
  SUM(amount) as total_earned,
  SUM(platform_fee) as total_fees
FROM picker_earnings
WHERE status = 'paid'
GROUP BY picker_id;
```

### Stripe Dashboard Monitoring

1. **Connect > Accounts**
   - View all connected picker accounts
   - Check verification status
   - Monitor payout settings

2. **Connect > Transfers**
   - See all transfers to pickers
   - Check transfer status
   - View failure reasons

3. **Balance > Payouts**
   - Monitor platform balance
   - Check scheduled payouts
   - View payout history

---

## Test Accounts Reference

### Stripe Test Cards
- **Success:** `4242 4242 4242 4242`
- **Decline:** `4000 0000 0000 0002`
- **Insufficient funds:** `4000 0000 0000 9995`

### Stripe Test Bank Accounts (US)
- **Success:** `000123456789` with routing `110000000`
- **Instant verification:** `000111111116` with routing `110000000`
- **Failed verification:** `000111111113` with routing `110000000`

### Stripe Test IBANs
- **Germany:** `DE89370400440532013000`
- **France:** `FR1420041010050500013M02606`
- **UK:** `GB82WEST12345698765432`

---

## Next Steps

1. **Start with Test Mode:**
   - Test bank validation with invalid accounts
   - Test bank validation with valid test accounts
   - Complete test Stripe Connect
   - Process test order and verify payout

2. **Move to Small Production Test:**
   - Use real bank account
   - Complete real Stripe Connect
   - Create $1-$5 test order
   - Verify real bank deposit

3. **Enable for All Pickers:**
   - Monitor first few payouts closely
   - Check for any failed transfers
   - Respond to picker questions quickly
   - Document any issues encountered

4. **Ongoing Monitoring:**
   - Weekly check of failed payouts
   - Monthly reconciliation with Stripe
   - Regular review of picker feedback
   - Track average payout time

---

## Support Resources

### For Pickers
- **Bank Account Help:** Verify account/routing number with bank
- **Stripe Connect Help:** contact Stripe support directly
- **Payout Timing:** 48 hours hold + 2-5 days bank transfer
- **Failed Payouts:** Check bank details, contact support

### For Platform Admin
- **Stripe Dashboard:** https://dashboard.stripe.com
- **Stripe API Logs:** Dashboard > Developers > Logs
- **Connect Onboarding:** Dashboard > Connect > Accounts
- **Transfer History:** Dashboard > Connect > Transfers

### Documentation
- **Stripe Connect:** https://stripe.com/docs/connect
- **Bank Accounts:** https://stripe.com/docs/connect/bank-accounts
- **Payouts:** https://stripe.com/docs/connect/payouts
- **Testing:** https://stripe.com/docs/connect/testing
