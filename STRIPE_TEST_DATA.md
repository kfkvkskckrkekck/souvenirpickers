# Stripe Test Data for Development

## Test Credit Cards

### Successful Payments:
```
Card Number: 4242 4242 4242 4242
Expiry: Any future date (e.g., 12/25)
CVC: Any 3 digits (e.g., 123)
ZIP: Any 5 digits (e.g., 12345)

Result: Payment succeeds
```

### Declined Payments:
```
Card Number: 4000 0000 0000 0002
Result: Payment declined (generic decline)

Card Number: 4000 0000 0000 9995
Result: Insufficient funds

Card Number: 4000 0000 0000 9987
Result: Lost card

Card Number: 4000 0000 0000 9979
Result: Stolen card
```

### 3D Secure Authentication:
```
Card Number: 4000 0025 0000 3155
Result: Requires authentication (test 3DS flow)
```

## Test Bank Accounts

### US Bank Accounts:
```
Account Number: 000123456789
Routing Number: 110000000
Account Holder: Test User
Country: US
Currency: USD

Result: Valid test account
```

### European IBANs:

#### Germany:
```
IBAN: DE89370400440532013000
BIC/SWIFT: COBADEFFXXX
Bank Name: Commerzbank
Country: DE
Currency: EUR

Result: Valid test IBAN
```

#### France:
```
IBAN: FR1420041010050500013M02606
BIC/SWIFT: BNPAFRPPXXX
Bank Name: BNP Paribas
Country: FR
Currency: EUR
```

#### United Kingdom:
```
IBAN: GB29NWBK60161331926819
BIC/SWIFT: NWBKGB2L
Bank Name: NatWest
Country: GB
Currency: GBP
```

#### Spain:
```
IBAN: ES9121000418450200051332
BIC/SWIFT: CAIXESBBXXX
Bank Name: CaixaBank
Country: ES
Currency: EUR
```

#### Italy:
```
IBAN: IT60X0542811101000000123456
BIC/SWIFT: BPMIITMMXXX
Bank Name: Banco Popolare
Country: IT
Currency: EUR
```

#### Netherlands:
```
IBAN: NL91ABNA0417164300
BIC/SWIFT: ABNANL2A
Bank Name: ABN AMRO
Country: NL
Currency: EUR
```

#### Romania (Your Target Market!):
```
IBAN: RO49AAAA1B31007593840000
BIC/SWIFT: BTRLRO22
Bank Name: Banca Transilvania
Country: RO
Currency: RON (or EUR for multi-currency)

IBAN: RO09BCYP0000001234567890
BIC/SWIFT: RNCBROBU
Bank Name: BCR (Banca Comercială Română)
Country: RO
Currency: RON
```

## Test Identity Information

### For Stripe Connect Onboarding:

#### United States:
```
First Name: Test
Last Name: User
Date of Birth: 01/01/1990
SSN: 000000000 (test SSN - will be accepted in test mode)
Address: 123 Test Street
City: San Francisco
State: CA
ZIP: 94111
Country: US
```

#### Romania:
```
First Name: Ion
Last Name: Popescu
Date of Birth: 01/01/1990
CNP: 1900101123456 (test CNP)
Address: Strada Test 123
City: București
Postal Code: 010101
Country: RO
```

#### Germany:
```
First Name: Hans
Last Name: Mueller
Date of Birth: 01/01/1990
Tax ID: 12345678901 (test)
Address: Teststraße 123
City: Berlin
Postal Code: 10115
Country: DE
```

#### United Kingdom:
```
First Name: John
Last Name: Smith
Date of Birth: 01/01/1990
National Insurance: AB123456C (test)
Address: 123 Test Road
City: London
Postal Code: SW1A 1AA
Country: GB
```

## Testing Express Account Onboarding

### When redirected to Stripe onboarding page:

1. **Email verification:**
   - Enter any email
   - Use test code: `000000`

2. **Phone verification:**
   - Enter any phone number
   - Use test code: `000000`

3. **Identity verification:**
   - Upload any image file
   - Or use "Skip verification" in test mode

4. **Bank account:**
   - Use test IBANs from above
   - Or use Stripe's test mode bank accounts

5. **Business details:**
   - Any test data will work
   - All fields can use dummy values

## Testing Payment Flow

### Complete Collector-to-Picker Payment:

```javascript
// 1. Collector pays for order
Order Amount: €100.00
Test Card: 4242 4242 4242 4242

// 2. Expected escrow:
Gross Amount: 10000 cents (€100)
Status: held

// 3. After delivery confirmation:
Platform Fee: 1000 cents (€10)
Picker Receives: 9000 cents (€90)

// 4. Verify in database:
SELECT * FROM payment_escrow WHERE order_id = 'xxx';
SELECT * FROM picker_payouts WHERE order_id = 'xxx';
```

## Testing Subscription Flow

### Test Picker Monthly Subscription:

```javascript
// 1. Create picker account
User Type: picker
Trial End: Set to yesterday (for immediate testing)

// 2. Add test payment card
Card: 4242 4242 4242 4242
Expiry: 12/25
CVC: 123

// 3. Trigger subscription processing
Call: /functions/v1/process-monthly-subscriptions

// 4. Expected charge:
Amount: €10.00 (1000 cents)
Status: succeeded

// 5. Verify in database:
SELECT * FROM picker_subscription_payments;
```

## Webhook Testing

### Stripe CLI for local testing:

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to local
stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger account.updated
stripe trigger transfer.paid
```

### Manual webhook testing:

```bash
# Test webhook endpoint
curl -X POST https://your-project.supabase.co/functions/v1/stripe-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "payment_intent.succeeded",
    "data": {
      "object": {
        "id": "pi_test_123",
        "amount": 10000,
        "currency": "eur"
      }
    }
  }'
```

## Error Testing

### Test payment failures:

```
Card: 4000 0000 0000 0341 (Attach fails)
Card: 4000 0000 0000 0069 (Expired card)
Card: 4000 0000 0000 0127 (Incorrect CVC)
```

### Test bank account failures:

```
IBAN: XX1234567890 (Invalid country code)
IBAN: DE00000000000000000000 (Invalid checksum)
```

## Stripe Dashboard Test Mode

### Important URLs:

```
Dashboard: https://dashboard.stripe.com/test
Payments: https://dashboard.stripe.com/test/payments
Connect: https://dashboard.stripe.com/test/connect/accounts
Webhooks: https://dashboard.stripe.com/test/webhooks
Logs: https://dashboard.stripe.com/test/logs
```

### What to check:

1. **Payments tab:**
   - See all test payments
   - View payment details
   - Check metadata

2. **Connect tab:**
   - See created accounts
   - Check verification status
   - View transfers

3. **Webhooks tab:**
   - Add endpoint URL
   - See events sent
   - Retry failed webhooks

## Important Notes

### Test Mode vs Live Mode:

- **Test mode:** Use test_ keys (sk_test_...)
- **Live mode:** Use live_ keys (sk_live_...)
- **Never mix:** Test cards only work in test mode

### Test Data Limitations:

- Test cards never charge real money
- Test bank accounts are not validated
- Test IBANs may not follow real bank formats
- Identity documents are not actually verified

### Real Testing:

For final testing before launch:
1. Use real bank account (small amount)
2. Test with your own card
3. Verify money actually transfers
4. Check bank statements

## Quick Reference

### Test Subscription:
```
Picker Card: 4242 4242 4242 4242
Amount: €10.00/month
Test: Set trial_end_date to yesterday
```

### Test Payment:
```
Collector Card: 4242 4242 4242 4242
Order Amount: €100.00
Platform Fee: €10.00
Picker Gets: €90.00
```

### Test Payout:
```
Picker IBAN: DE89370400440532013000
SWIFT: COBADEFFXXX
Receives: €90.00 after delivery confirmation
```
