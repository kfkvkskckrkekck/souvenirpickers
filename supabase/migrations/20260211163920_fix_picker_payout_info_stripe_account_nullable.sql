/*
  # Fix picker_payout_info table to allow manual bank account entries

  1. Changes
    - Make stripe_account_id nullable to support manual bank account entries
    - Users can now save bank details without going through Stripe Connect

  2. Purpose
    - Fixes bug where bank account form submission fails silently
    - Allows pickers to enter bank information manually in their profile
*/

-- Make stripe_account_id nullable to support manual bank account entries
ALTER TABLE picker_payout_info 
  ALTER COLUMN stripe_account_id DROP NOT NULL;
