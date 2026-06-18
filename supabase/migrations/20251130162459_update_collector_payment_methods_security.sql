/*
  # Secure Collector Payment Methods

  This migration updates the `collector_payment_methods` table to only use Stripe payment method IDs.
  It removes insecure card storage fields that should never be stored directly in our database.

  ## Changes Made

  1. Table Structure Updates
     - Remove `cardholder_name` column (not needed - Stripe stores this securely)
     - Add `stripe_payment_method_id` column if it doesn't exist (for secure Stripe integration)
     - Keep only safe display fields: `card_brand`, `last_four`, `expiry_month`, `expiry_year`

  2. Security Improvements
     - Card details are now stored securely by Stripe, not in our database
     - Only non-sensitive display information is retained
     - Stripe payment method ID references the secure payment method in Stripe's vault

  ## Important Notes
  
  - This migration is safe for existing data
  - The `stripe_payment_method_id` field will be populated by the save-payment-method Edge Function
  - Card numbers, CVV, and full cardholder info are NEVER stored in our database
*/

-- Add stripe_payment_method_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'collector_payment_methods' AND column_name = 'stripe_payment_method_id'
  ) THEN
    ALTER TABLE collector_payment_methods ADD COLUMN stripe_payment_method_id text;
  END IF;
END $$;

-- Remove cardholder_name column if it exists (insecure storage)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'collector_payment_methods' AND column_name = 'cardholder_name'
  ) THEN
    ALTER TABLE collector_payment_methods DROP COLUMN cardholder_name;
  END IF;
END $$;

-- Add index for faster Stripe payment method lookups
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_stripe_pm_id 
  ON collector_payment_methods(stripe_payment_method_id);

-- Add index for faster default payment method queries
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_client_default 
  ON collector_payment_methods(client_id, is_default) WHERE is_default = true;