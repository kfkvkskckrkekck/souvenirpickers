/*
  # Clean Up Custom Account Columns for Express Migration

  1. Changes
    - Drop all bank account columns no longer needed for Stripe Express
    - Express accounts manage bank details on Stripe's side
    - Keep only stripe_account_id and is_verified columns

  2. Columns Removed
    - bank_account_name
    - bank_account_number
    - bank_routing_number
    - bank_swift_code
    - bank_account_last4
    - stripe_external_account_id
    - details_submitted
    - country
    - currency

  3. Columns Kept
    - id
    - picker_id
    - stripe_account_id
    - is_verified
    - created_at
    - updated_at
*/

-- Drop old Custom account columns
ALTER TABLE picker_payout_info
  DROP COLUMN IF EXISTS bank_account_name,
  DROP COLUMN IF EXISTS bank_account_number,
  DROP COLUMN IF EXISTS bank_routing_number,
  DROP COLUMN IF EXISTS bank_swift_code,
  DROP COLUMN IF EXISTS bank_account_last4,
  DROP COLUMN IF EXISTS stripe_external_account_id,
  DROP COLUMN IF EXISTS details_submitted,
  DROP COLUMN IF EXISTS country,
  DROP COLUMN IF EXISTS currency;

-- Ensure required columns exist and are properly typed
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' 
    AND column_name = 'stripe_account_id'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN stripe_account_id TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' 
    AND column_name = 'is_verified'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

-- Create index for fast lookup by stripe_account_id
CREATE INDEX IF NOT EXISTS idx_payout_info_stripe_account
  ON picker_payout_info(stripe_account_id);

-- Create index for fast lookup by picker_id
CREATE INDEX IF NOT EXISTS idx_payout_info_picker_id
  ON picker_payout_info(picker_id);
