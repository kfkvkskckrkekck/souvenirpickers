/*
  # Migrate from Stripe Custom to Express Accounts

  1. Changes
    - Remove old bank account fields no longer needed for Express accounts
    - Keep stripe_account_id and is_verified columns (required for Express)
    - Add index for fast stripe_account_id lookups
    - Clean up legacy columns from Custom account implementation

  2. Notes
    - Stripe Express handles all bank details on their hosted page
    - We only need to track stripe_account_id and verification status
    - All sensitive bank data (account numbers, routing, SWIFT) removed
*/

-- Clean up old columns no longer needed for Express
ALTER TABLE picker_payout_info
  DROP COLUMN IF EXISTS bank_name,
  DROP COLUMN IF EXISTS account_holder_name,
  DROP COLUMN IF EXISTS account_number,
  DROP COLUMN IF EXISTS routing_number,
  DROP COLUMN IF EXISTS swift_code,
  DROP COLUMN IF EXISTS bank_country,
  DROP COLUMN IF EXISTS bank_address,
  DROP COLUMN IF EXISTS last_4_digits,
  DROP COLUMN IF EXISTS payouts_enabled,
  DROP COLUMN IF EXISTS account_status;

-- Make sure required columns exist
ALTER TABLE picker_payout_info
  ADD COLUMN IF NOT EXISTS stripe_account_id TEXT,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_payout_info_stripe_account
  ON picker_payout_info(stripe_account_id);

-- Add comment explaining the new Express model
COMMENT ON TABLE picker_payout_info IS 'Stores Stripe Express account IDs for pickers. All bank details are managed by Stripe directly.';
