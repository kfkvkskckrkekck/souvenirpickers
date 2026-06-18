/*
  # Add Missing Columns to Payout Info Table

  1. Changes
    - Add `stripe_external_account_id` column to store Stripe's external account ID
    - Add `details_submitted` column to track if account details have been submitted to Stripe
    - Both columns are optional and used for Stripe integration tracking

  2. Security
    - No changes to RLS policies needed
*/

-- Add missing columns to picker_payout_info table
ALTER TABLE picker_payout_info 
ADD COLUMN IF NOT EXISTS stripe_external_account_id text,
ADD COLUMN IF NOT EXISTS details_submitted boolean DEFAULT false;

-- Add comment for clarity
COMMENT ON COLUMN picker_payout_info.stripe_external_account_id IS 'Stripe external bank account ID';
COMMENT ON COLUMN picker_payout_info.details_submitted IS 'Whether account details have been submitted to Stripe';
