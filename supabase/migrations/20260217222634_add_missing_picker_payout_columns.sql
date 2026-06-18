/*
  # Add Missing Columns to picker_payout_info
  
  1. Changes
    - Add stripe_account_id column for Stripe Connect integration
    - Add account_status column to track verification status
    - Add payouts_enabled column to control payout permissions
    
  2. Purpose
    - Fixes database error when saving payout information
    - These columns are required by the frontend code
*/

-- Add stripe_account_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'stripe_account_id'
  ) THEN
    ALTER TABLE picker_payout_info 
    ADD COLUMN stripe_account_id text;
  END IF;
END $$;

-- Add account_status column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'account_status'
  ) THEN
    ALTER TABLE picker_payout_info 
    ADD COLUMN account_status text DEFAULT 'pending';
  END IF;
END $$;

-- Add payouts_enabled column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'picker_payout_info' AND column_name = 'payouts_enabled'
  ) THEN
    ALTER TABLE picker_payout_info 
    ADD COLUMN payouts_enabled boolean DEFAULT false;
  END IF;
END $$;

-- Add helpful comments
COMMENT ON COLUMN picker_payout_info.stripe_account_id IS 'Stripe Connect account ID for automated payouts';
COMMENT ON COLUMN picker_payout_info.account_status IS 'Status of the payout account: pending, verified, suspended';
COMMENT ON COLUMN picker_payout_info.payouts_enabled IS 'Whether payouts are enabled for this account';
