/*
  # Add Currency Field to Payment Escrow

  ## Changes
  - Adds `currency` column to `payment_escrow` table
  - Defaults to 'eur' for existing records
  - Ensures all escrow records track their currency
  
  ## Purpose
  Fixes critical currency mismatch issue where payments were created in EUR
  but payouts were being sent in USD. Now currency is tracked throughout
  the entire payment flow from collector payment to picker payout.
*/

-- Add currency column to payment_escrow table
ALTER TABLE payment_escrow 
ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'eur';

-- Add check constraint to ensure valid currency codes (only if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'valid_currency' 
    AND conrelid = 'payment_escrow'::regclass
  ) THEN
    ALTER TABLE payment_escrow
    ADD CONSTRAINT valid_currency 
    CHECK (currency IN ('eur', 'usd', 'gbp'));
  END IF;
END $$;

-- Create index for currency queries
CREATE INDEX IF NOT EXISTS idx_payment_escrow_currency 
ON payment_escrow(currency);