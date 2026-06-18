/*
  # Add Fee Tracking to Picker Payouts Table

  1. Changes
    - Add `gross_amount` column - Original escrow amount before platform fee
    - Add `platform_fee` column - 10% platform fee deducted
    - Add `net_amount` column - Actual amount transferred to picker
    - Add `stripe_transfer_id` column - Stripe transfer ID (different from payout ID)
    - Add `processed_at` column - When the transfer was completed
    - Update the status values to include 'completed'

  2. Purpose
    - Track platform fee deductions transparently
    - Show both gross and net amounts for accounting
    - Support both Stripe transfers and payouts
    - Maintain complete audit trail of money flow

  3. Notes
    - `stripe_payout_id` is for Stripe payouts to bank accounts
    - `stripe_transfer_id` is for Stripe transfers to Connect accounts  
    - Both can coexist for different payout methods
*/

-- Add fee tracking columns to picker_payouts table
DO $$
BEGIN
  -- Add gross_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'gross_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN gross_amount numeric CHECK (gross_amount > 0);
  END IF;

  -- Add platform_fee column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'platform_fee'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN platform_fee numeric DEFAULT 0 CHECK (platform_fee >= 0);
  END IF;

  -- Add net_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'net_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN net_amount numeric CHECK (net_amount > 0);
  END IF;

  -- Add stripe_transfer_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'stripe_transfer_id'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN stripe_transfer_id text UNIQUE;
  END IF;

  -- Add processed_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'processed_at'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN processed_at timestamptz;
  END IF;
END $$;

-- Update status constraint to include 'completed'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'picker_payouts' AND constraint_name = 'picker_payouts_status_check'
  ) THEN
    ALTER TABLE picker_payouts DROP CONSTRAINT picker_payouts_status_check;
  END IF;
END $$;

ALTER TABLE picker_payouts ADD CONSTRAINT picker_payouts_status_check
  CHECK (status IN ('pending', 'in_transit', 'paid', 'failed', 'cancelled', 'completed'));

-- Create index on stripe_transfer_id for webhook lookups
CREATE INDEX IF NOT EXISTS idx_picker_payouts_stripe_transfer_id 
  ON picker_payouts(stripe_transfer_id);

-- Create a helpful view for picker earnings with fees
CREATE OR REPLACE VIEW picker_earnings_with_fees AS
SELECT
  picker_id,
  COUNT(*) as total_transactions,
  SUM(COALESCE(gross_amount, amount)) as total_gross_earned,
  SUM(COALESCE(platform_fee, 0)) as total_fees_paid,
  SUM(COALESCE(net_amount, amount)) as total_net_received,
  MIN(created_at) as first_payout_at,
  MAX(COALESCE(processed_at, paid_at)) as last_payout_at
FROM picker_payouts
WHERE status IN ('completed', 'paid', 'in_transit')
GROUP BY picker_id;

-- Grant access to the view
GRANT SELECT ON picker_earnings_with_fees TO authenticated;

-- Update existing records to set net_amount equal to amount where null
UPDATE picker_payouts
SET net_amount = amount
WHERE net_amount IS NULL AND amount IS NOT NULL;

-- Update existing records to set gross_amount equal to amount where null
UPDATE picker_payouts
SET gross_amount = amount
WHERE gross_amount IS NULL AND amount IS NOT NULL;
