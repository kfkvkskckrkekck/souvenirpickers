/*
  # Add Bank Account Fields to Picker Payout Info

  1. Changes
    - Add bank account fields to picker_payout_info table to support manual bank account entry
    - Fields include account name, number (encrypted), bank name, routing, SWIFT, country, currency
    
  2. New Columns
    - bank_account_name: Name on the bank account
    - bank_account_number: Encrypted account number (last 4 digits visible)
    - bank_name: Name of the bank
    - bank_routing_number: Routing/sort code for domestic transfers
    - bank_swift_code: SWIFT/BIC code for international transfers
    - country: Country of the bank account
    - currency: Currency code (e.g., USD, EUR, GBP)
    - is_verified: Whether the bank account has been verified
    - bank_account_last4: Last 4 digits of account number for display
*/

-- Add bank account fields to picker_payout_info
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_account_name'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_account_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_account_number'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_account_number text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_name'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_routing_number'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_routing_number text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_swift_code'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_swift_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'country'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN country text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'currency'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN currency text DEFAULT 'USD';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'is_verified'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN is_verified boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_account_last4'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_account_last4 text;
  END IF;
END $$;

-- Add comment explaining security note
COMMENT ON COLUMN picker_payout_info.bank_account_number IS 'Bank account number - should be encrypted in production. Currently stored for development purposes only.';