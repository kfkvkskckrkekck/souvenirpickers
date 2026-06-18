/*
  # Make SWIFT Code Required in Payout Info

  1. Changes
    - Make `bank_swift_code` column NOT NULL in `picker_payout_info` table
    - This ensures all payout accounts have a valid SWIFT/BIC code for international transfers
  
  2. Security
    - No changes to RLS policies
    - Existing policies remain in effect
*/

-- First, update any existing records that might have NULL SWIFT codes
-- (In production, this would need to be handled more carefully)
UPDATE picker_payout_info
SET bank_swift_code = 'PENDING'
WHERE bank_swift_code IS NULL;

-- Now make the column NOT NULL
ALTER TABLE picker_payout_info
ALTER COLUMN bank_swift_code SET NOT NULL;

-- Add a check constraint to ensure it's not just an empty string
ALTER TABLE picker_payout_info
ADD CONSTRAINT bank_swift_code_not_empty 
CHECK (length(trim(bank_swift_code)) >= 8 AND length(trim(bank_swift_code)) <= 11);

-- Add a check constraint to ensure proper SWIFT format
ALTER TABLE picker_payout_info
ADD CONSTRAINT bank_swift_code_format 
CHECK (bank_swift_code ~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$');
