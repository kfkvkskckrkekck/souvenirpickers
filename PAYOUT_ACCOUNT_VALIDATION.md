# Payout Account Validation System

## Overview
Implemented comprehensive validation and confirmation for bank account payout information with real-time feedback to ensure data integrity and prevent errors. The system validates IBANs from **88 countries and territories worldwide**.

## Features Implemented

### 1. Mandatory Field Validation

**Frontend (ProfileView.tsx)**
All fields marked as required with red asterisks:
- Account Holder Name (required)
- Bank Name (required)
- IBAN Account Number (required)
- SWIFT/BIC Code (required) - Previously optional, now mandatory
- Country (required)
- Currency (required) - Previously had default, now must be selected

**Validation Rules:**
- Account Holder Name: 2-100 characters, letters/spaces/hyphens/apostrophes only
- Bank Name: 2-100 characters, letters/spaces/hyphens/periods only
- IBAN: Country-specific length validation (15-34 characters) with mod-97 checksum
- SWIFT/BIC: 8 or 11 characters, format XXXXYYZZZ (6 letters + 2 alphanumeric + optional 3 alphanumeric)
- Country: 2+ characters, letters/spaces/hyphens only
- Currency: 3-character ISO code from dropdown

**Real-Time IBAN Validation:**
- Character counter shows length as you type
- Red text when incorrect length (too short, too long, or wrong for specific country)
- Green text when valid length
- Country-specific feedback (e.g., "26 characters (RO needs 24)" for Romanian accounts)
- Immediate validation on blur with specific error messages
- Tells you exactly how many characters are missing or extra
- Example errors:
  - "RO IBAN must be exactly 24 characters. You entered 26. Extra 2 character(s)."
  - "DE IBAN must be exactly 22 characters. You entered 20. Missing 2 character(s)."

### 2. Confirmation Dialog

Before saving, users must confirm all account details:
```
Please confirm your payout account details:

Account Holder: John Doe
Bank: Banca Transilvania
IBAN: RO49...0000
SWIFT/BIC: BTRLRO22
Country: Romania
Currency: RON

⚠️ Please double-check all details are correct.
Incorrect bank information may result in failed or delayed payouts.

Do you want to save this payout account?
```

Users can review and cancel if any information is incorrect.

### 3. Enhanced Success Message

After successful save, displays comprehensive confirmation:
```
✓ Bank account information saved successfully!

Account Details:
• Bank: Banca Transilvania
• Account: ****0000
• SWIFT: BTRLRO22
• Currency: RON

Your IBAN has been validated. Account status: Pending verification.
```

### 4. Database Constraints

**Migration: make_swift_code_required_in_payout_info**
- SWIFT code column made NOT NULL
- Check constraint: 8-11 characters length
- Check constraint: Proper SWIFT format validation

**Migration: make_all_payout_fields_required**
All critical fields made NOT NULL with validation:
- `bank_account_name`: NOT NULL, minimum 2 characters
- `bank_account_number`: NOT NULL, minimum 15 characters
- `bank_name`: NOT NULL, minimum 2 characters
- `bank_swift_code`: NOT NULL, 8-11 characters, proper format
- `country`: NOT NULL, minimum 2 characters
- `currency`: NOT NULL, exactly 3 characters

### 5. Real-time Validation

- Validation on blur for immediate feedback
- Error messages clear when user starts correcting
- Auto-fill from SWIFT code when available
- Auto-fill from IBAN country code

## Security Benefits

1. **Data Integrity**: All required fields enforced at both UI and database level
2. **User Confirmation**: Prevents accidental submission with wrong details
3. **Validation Feedback**: Clear error messages guide users to correct issues
4. **Database Constraints**: Ensures no incomplete records can be saved

## User Experience Improvements

1. **Clear Requirements**: Red asterisks indicate mandatory fields
2. **Helpful Hints**: Placeholder text and format examples
3. **Auto-fill Features**: Reduces manual entry and errors
4. **Confirmation Step**: Gives users confidence before saving
5. **Detailed Success Message**: Confirms exactly what was saved

## Technical Implementation

**Files Modified:**
- `src/components/ProfileView.tsx`: Frontend validation and UI
- `supabase/migrations/make_swift_code_required_in_payout_info.sql`: Database constraints for SWIFT
- `supabase/migrations/make_all_payout_fields_required.sql`: Database constraints for all fields

**Validation Flow:**
1. User fills form with all required fields
2. Real-time validation on blur
3. Form submission triggers comprehensive validation
4. Confirmation dialog displays all details for review
5. User confirms or cancels
6. If confirmed, data saved to database
7. Success message shows validated account details

## Testing Recommendations

1. Try to save with empty fields - should show validation errors
2. Enter incomplete IBAN (e.g., RO02 INGB 0000 9999 1046 736 = 26 chars instead of 24) - should see red character count and error on blur
3. Enter IBAN from different countries to test length validation
4. Enter invalid SWIFT code - should reject
5. Fill valid data - should show confirmation dialog
6. Cancel confirmation - should not save
7. Confirm - should save and show success message with account details
8. Try to save directly to database with NULL values - should be rejected by constraints

## Country-Specific IBAN Lengths Supported

The system validates IBANs for **88 countries and territories** with their exact required lengths:

### European Union & EEA (32 countries)
Austria (AT): 20 | Belgium (BE): 16 | Bulgaria (BG): 22 | Croatia (HR): 21 | Cyprus (CY): 28 | Czech Republic (CZ): 24 | Denmark (DK): 18 | Estonia (EE): 20 | Finland (FI): 18 | France (FR): 27 | Germany (DE): 22 | Greece (GR): 27 | Hungary (HU): 28 | Ireland (IE): 22 | Italy (IT): 27 | Latvia (LV): 21 | Lithuania (LT): 20 | Luxembourg (LU): 20 | Malta (MT): 31 | Netherlands (NL): 18 | Poland (PL): 28 | Portugal (PT): 25 | Romania (RO): 24 | Slovakia (SK): 24 | Slovenia (SI): 19 | Spain (ES): 24 | Sweden (SE): 24 | United Kingdom (GB): 22 | Iceland (IS): 26 | Liechtenstein (LI): 21 | Norway (NO): 15 | Switzerland (CH): 21

### Middle East (13 countries)
UAE (AE): 23 | Bahrain (BH): 22 | Israel (IL): 23 | Iraq (IQ): 23 | Jordan (JO): 30 | Kuwait (KW): 30 | Lebanon (LB): 28 | Oman (OM): 23 | Palestine (PS): 29 | Qatar (QA): 29 | Saudi Arabia (SA): 24 | Turkey (TR): 26 | Yemen (YE): 30

### Africa (20 countries)
Algeria (DZ): 26 | Angola (AO): 25 | Benin (BJ): 28 | Burkina Faso (BF): 28 | Burundi (BI): 16 | Cameroon (CM): 27 | Cape Verde (CV): 25 | Congo (CG): 27 | Ivory Coast (CI): 28 | Djibouti (DJ): 27 | Egypt (EG): 29 | Gabon (GA): 27 | Guinea-Bissau (GW): 25 | Iran (IR): 26 | Morocco (MA): 28 | Madagascar (MG): 27 | Mali (ML): 28 | Mozambique (MZ): 25 | Niger (NE): 28 | Senegal (SN): 28 | Tunisia (TN): 24

### Latin America & Caribbean (5 countries)
Brazil (BR): 29 | Costa Rica (CR): 22 | Guatemala (GT): 28 | El Salvador (SV): 28 | British Virgin Islands (VG): 24

### Central Asia & Caucasus (14 countries)
Azerbaijan (AZ): 28 | Belarus (BY): 28 | Georgia (GE): 22 | Kazakhstan (KZ): 20 | Moldova (MD): 24 | Mauritania (MR): 27 | Mauritius (MU): 30 | North Macedonia (MK): 19 | Pakistan (PK): 24 | Serbia (RS): 22 | Seychelles (SC): 31 | Ukraine (UA): 29 | Vatican City (VA): 22 | Kosovo (XK): 20

### Additional Territories (14)
Andorra (AD): 24 | Albania (AL): 28 | Bosnia and Herzegovina (BA): 20 | Dominican Republic (DO): 28 | Faroe Islands (FO): 18 | Gibraltar (GI): 23 | Greenland (GL): 18 | Saint Lucia (LC): 32 | Monaco (MC): 27 | Montenegro (ME): 22 | San Marino (SM): 27 | Sao Tome and Principe (ST): 25 | East Timor (TL): 23

### How It Works
When you enter an IBAN, the system:
1. Extracts the 2-letter country code
2. Looks up the expected length for that country
3. Compares your entered length with the expected length
4. Shows immediate feedback:
   - Green text if correct length
   - Red text if wrong length
   - Displays country code and expected length (e.g., "RO needs 24")
5. On blur, validates the complete IBAN including checksum
6. Shows detailed error message if invalid
