-- Create Picker Payout Information Table
-- 
-- 1. New Tables
--    - picker_payout_info
--      - id (uuid, primary key)
--      - picker_id (uuid, foreign key to profiles)
--      - bank_account_name (text) - Name on the bank account
--      - bank_account_number (text) - Bank account number
--      - bank_name (text) - Name of the bank
--      - bank_routing_number (text) - Routing/sort code
--      - bank_swift_code (text) - SWIFT/BIC code for international transfers
--      - country (text) - Country of the bank account
--      - currency (text) - Payout currency (USD, EUR, GBP, etc.)
--      - is_verified (boolean) - Whether the account has been verified
--      - created_at (timestamptz)
--      - updated_at (timestamptz)
-- 
-- 2. Security
--    - Enable RLS on picker_payout_info table
--    - Add policies for pickers to manage their own payout information

CREATE TABLE IF NOT EXISTS picker_payout_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  bank_account_name text NOT NULL,
  bank_account_number text NOT NULL,
  bank_name text NOT NULL,
  bank_routing_number text DEFAULT '',
  bank_swift_code text DEFAULT '',
  country text NOT NULL,
  currency text DEFAULT 'USD',
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE picker_payout_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pickers can view own payout info"
  ON picker_payout_info
  FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

CREATE POLICY "Pickers can insert own payout info"
  ON picker_payout_info
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can update own payout info"
  ON picker_payout_info
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can delete own payout info"
  ON picker_payout_info
  FOR DELETE
  TO authenticated
  USING (auth.uid() = picker_id);

CREATE INDEX IF NOT EXISTS idx_picker_payout_info_picker_id ON picker_payout_info(picker_id);
