/*
  # Make All Critical Payout Fields Required

  1. Changes
    - Make `bank_account_name` NOT NULL
    - Make `bank_account_number` NOT NULL
    - Make `bank_name` NOT NULL
    - Make `country` NOT NULL
    - Make `currency` NOT NULL
    - Add check constraints to ensure fields are not empty strings
  
  2. Security
    - Ensures data integrity for payout information
    - Prevents incomplete payout records
*/

-- First, ensure any existing records have default values
UPDATE picker_payout_info
SET 
  bank_account_name = COALESCE(bank_account_name, 'PENDING'),
  bank_account_number = COALESCE(bank_account_number, 'PENDING'),
  bank_name = COALESCE(bank_name, 'PENDING'),
  country = COALESCE(country, 'PENDING'),
  currency = COALESCE(currency, 'USD')
WHERE 
  bank_account_name IS NULL 
  OR bank_account_number IS NULL 
  OR bank_name IS NULL 
  OR country IS NULL 
  OR currency IS NULL;

-- Make columns NOT NULL
ALTER TABLE picker_payout_info
ALTER COLUMN bank_account_name SET NOT NULL;

ALTER TABLE picker_payout_info
ALTER COLUMN bank_account_number SET NOT NULL;

ALTER TABLE picker_payout_info
ALTER COLUMN bank_name SET NOT NULL;

ALTER TABLE picker_payout_info
ALTER COLUMN country SET NOT NULL;

ALTER TABLE picker_payout_info
ALTER COLUMN currency SET NOT NULL;

-- Add check constraints to ensure fields are not empty
ALTER TABLE picker_payout_info
ADD CONSTRAINT bank_account_name_not_empty 
CHECK (length(trim(bank_account_name)) >= 2);

ALTER TABLE picker_payout_info
ADD CONSTRAINT bank_account_number_not_empty 
CHECK (length(trim(bank_account_number)) >= 15);

ALTER TABLE picker_payout_info
ADD CONSTRAINT bank_name_not_empty 
CHECK (length(trim(bank_name)) >= 2);

ALTER TABLE picker_payout_info
ADD CONSTRAINT country_not_empty 
CHECK (length(trim(country)) >= 2);

ALTER TABLE picker_payout_info
ADD CONSTRAINT currency_not_empty 
CHECK (length(trim(currency)) = 3);
