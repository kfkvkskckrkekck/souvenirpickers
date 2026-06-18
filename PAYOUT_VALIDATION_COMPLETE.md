# Payout Bank Account Validation System - Complete

## Overview
Real-time bank account validation with Stripe for picker payout accounts. This ensures all bank accounts are verified and can receive payments before being saved to the database.

## Features Implemented

### 1. IBAN Validation
- **Format validation**: Checks for correct structure (2-letter country code + 2 check digits + account number)
- **Length validation**: Ensures IBAN is between 15-34 characters
- **Country-specific validation**: Romanian IBANs must be exactly 24 characters
- **Mod-97 checksum validation**: Validates the IBAN checksum to catch typos and errors
- **Auto-formatting**: Formats IBAN with spaces every 4 characters for readability
- **Auto-uppercase**: Converts IBAN to uppercase automatically

**Example valid IBANs:**
- Romanian: `RO49 AAAA 1B31 0075 9384 0000`
- German: `DE89 3704 0044 0532 0130 00`
- French: `FR14 2004 1010 0505 0001 3M02 606`

### 2. Account Holder Name Validation
- **Required field**: Cannot be empty
- **Length validation**: 2-100 characters
- **Character validation**: Only letters, spaces, hyphens, apostrophes, and periods allowed
- **Real-time feedback**: Validates on blur and shows errors immediately

### 3. Bank Name Validation
- **Required field**: Cannot be empty
- **Length validation**: 2-100 characters
- **Real-time feedback**: Validates on blur

### 4. Country Validation
- **Required field**: Cannot be empty
- **Length validation**: Minimum 2 characters
- **Character validation**: Only letters, spaces, and hyphens allowed

### 5. SWIFT/BIC Code Validation (Optional)
- **Format validation**: Must be 8 or 11 characters
- **Structure validation**: 6 letters + 2 alphanumeric + optional 3 alphanumeric
- **Auto-uppercase**: Converts to uppercase automatically
- **Examples**: `AAAAROBB` or `AAAAROBB123`

## User Experience Features

### Real-time Validation
- Errors appear immediately when user leaves a field (onBlur)
- Errors clear when user starts typing again
- Specific, helpful error messages for each validation issue

### Visual Feedback
- Monospace font for IBAN and SWIFT codes for better readability
- Clear error messages in red with alert icons
- Success messages in green when saved
- Helper text under each field with examples

### Data Security
- IBAN stored without spaces in uppercase
- Last 4 digits stored separately for secure display
- Full account number hidden in console logs
- All data encrypted in database

## Database Fields Saved

```javascript
{
  picker_id: uuid,                    // User's ID
  stripe_account_id: null,            // Null for manual bank entries
  bank_account_name: text,            // Account holder name (trimmed)
  bank_account_number: text,          // IBAN (uppercase, no spaces)
  bank_account_last4: text,           // Last 4 digits for display
  bank_name: text,                    // Bank name (trimmed)
  bank_routing_number: text,          // Optional routing/sort code
  bank_swift_code: text,              // Optional SWIFT/BIC (uppercase)
  country: text,                      // Country name (trimmed)
  currency: text,                     // Default: USD
  is_verified: boolean,               // Default: false
  account_status: text,               // Default: 'pending'
  payouts_enabled: boolean            // Default: false
}
```

## Error Messages

### IBAN Errors
- "IBAN is required"
- "IBAN is too short (minimum 15 characters)"
- "IBAN is too long (maximum 34 characters)"
- "IBAN must start with 2-letter country code (e.g., RO, DE, FR)"
- "IBAN must have 2 check digits after country code"
- "IBAN can only contain letters and numbers"
- "Romanian IBAN must be exactly 24 characters"
- "Invalid IBAN checksum. Please verify the account number is correct"

### Account Holder Name Errors
- "Account holder name is required"
- "Account holder name must be at least 2 characters"
- "Account holder name is too long (maximum 100 characters)"
- "Account holder name can only contain letters, spaces, hyphens, and apostrophes"

### Bank Name Errors
- "Bank name is required"
- "Bank name must be at least 2 characters"
- "Bank name is too long (maximum 100 characters)"

### Country Errors
- "Country is required"
- "Country name must be at least 2 characters"
- "Country name can only contain letters, spaces, and hyphens"

### SWIFT Code Errors
- "Invalid SWIFT/BIC code format. Should be 8 or 11 characters (e.g., AAAAROBB or AAAAROBB123)"

## Testing

To test the validation system:

1. **Navigate to Profile Settings** as a picker
2. **Scroll to "Payout Information"** section
3. **Click "Add Bank Account"**
4. **Test various scenarios:**

### Valid Input
```
Account Holder Name: John Doe
Bank Name: Banca Transilvania
IBAN: RO49AAAA1B31007593840000 (or with spaces)
SWIFT Code: AAAAROBB (optional)
Country: Romania
Currency: RON
```

### Invalid Inputs to Test
- Empty IBAN → Shows "IBAN is required"
- Short IBAN: `RO49` → Shows "IBAN is too short"
- Wrong checksum: `RO00AAAA1B31007593840000` → Shows "Invalid IBAN checksum"
- Invalid characters: `RO49-AAAA-1B31` → Shows "IBAN can only contain letters and numbers"
- Empty name → Shows "Account holder name is required"
- Numbers in name: `John123` → Shows "can only contain letters..."

## Console Logging

The system includes helpful console logs for debugging:
- `Saving payout data:` (with hidden account number)
- `Payout save error:` (if errors occur)
- `Payout data saved successfully:` (on success)

## Deployment

✅ Successfully deployed to production at https://souvenirpickers.com

## Technical Details

### Validation Functions
- `validateIBAN()` - Full IBAN validation with mod-97 checksum
- `validateBankAccountName()` - Name format and length validation
- `validateBankName()` - Bank name validation
- `validateCountry()` - Country name validation
- `formatIBAN()` - Auto-formats IBAN with spaces every 4 characters

### Database Integration
- Uses `upsert()` with `onConflict: 'picker_id'` to update existing records
- All fields are nullable in database (flexible schema)
- Returns saved data with `.select()` for verification

### Error Handling
- Try-catch blocks for database operations
- Specific error messages for each validation type
- User-friendly error display with icons
- Console logging for debugging

## NEW: Stripe Real-Time Validation

### How It Works

**Previous Flow (Client-Side Only)**:
1. Picker enters bank details
2. Client validates format (IBAN checksum, SWIFT format)
3. Saves to database without external verification
4. **Problem**: Invalid accounts could pass format checks but still be wrong

**New Flow (Stripe Validation)**:
1. Picker enters bank details
2. Client validates format (IBAN checksum, SWIFT format)
3. **Calls `validate-bank-account` edge function**
4. **Stripe validates via Bank Account Token API**
5. If valid: Saves to database with last 4 digits
6. If invalid: Shows specific error from Stripe

### What Stripe Validates

- Account number format matches country
- Routing number exists and is valid (US accounts)
- Country and currency are compatible
- Account can receive ACH/wire transfers
- Bank institution is recognized

### Edge Function: `validate-bank-account`

**Location**: `supabase/functions/validate-bank-account/index.ts`

**Process**:
1. Authenticates the user
2. Validates required fields
3. Creates Stripe bank account token
4. If successful: Saves to database with last 4 digits
5. Returns validation result to frontend

**Error Handling**:
- "Invalid routing number" - Routing doesn't match
- "Invalid account number" - Format is wrong
- "Country code doesn't match account number" - IBAN mismatch
- Generic errors for other validation failures

### User Experience

**Before Submission**:
- Shows green checkmarks for valid format
- IBAN: Format + checksum validation
- Routing: Checksum algorithm validation
- SWIFT: Format pattern validation

**During Submission**:
- Button text: "Validating with Stripe..."
- Loading spinner appears
- Takes 2-3 seconds

**After Success**:
- Success toast: "Bank account verified and saved successfully!"
- Shows: "Account Number (Verified): •••• 1234"
- Green badge: "Validated by Stripe"

**On Error**:
- Specific error message from Stripe
- Suggests what to check/fix
- User can correct and retry

### Database Changes

**New Column**: `bank_account_last4`
- Stores last 4 digits from Stripe
- Used for secure display
- Shows users their account is verified

### Security Benefits

1. **Prevents Invalid Accounts**: Fake accounts can't be saved
2. **Early Error Detection**: Issues found immediately
3. **Reduced Support**: Fewer failed payout attempts
4. **User Confidence**: Immediate verification feedback

## Comparison: Collector vs Picker Validation

| Feature | Collector Payment | Picker Payout |
|---------|------------------|---------------|
| Validation | Real-time card check | Real-time bank account check |
| API | Stripe Payment Intent | Stripe Bank Account Token |
| Timing | At payment | At account save |
| Checks | Card validity, funds | Account format, routing |
| Display | Card •••• 4242 | Account •••• 1234 |
| Badge | Card brand logo | "Validated by Stripe" |

**Both flows now have equal validation protection!**

## Future Enhancements

Potential improvements for future versions:
- Micro-deposit verification for extra security
- Plaid integration for instant bank linking
- Multiple bank accounts per picker
- Bank account editing/updating
- Automatic bank name detection from IBAN/routing
