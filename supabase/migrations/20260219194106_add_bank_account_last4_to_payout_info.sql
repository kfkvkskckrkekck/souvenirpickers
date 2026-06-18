/*
  # Add Bank Account Last 4 Digits to Payout Info

  1. Changes
    - Add `bank_account_last4` column to `picker_payout_info` table
    - This stores the last 4 digits returned by Stripe after bank account validation
    - Helps users confirm which account is saved without exposing full account number

  2. Security
    - Last 4 digits are safe to display
    - Column is nullable since existing records won't have this
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payout_info' AND column_name = 'bank_account_last4'
  ) THEN
    ALTER TABLE picker_payout_info ADD COLUMN bank_account_last4 text;
  END IF;
END $$;
