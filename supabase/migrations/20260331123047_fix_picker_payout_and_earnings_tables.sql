/*
  # Fix Picker Payout System
  
  1. Updates
    - Add missing columns to `picker_payout_info` table
    - Create `picker_earnings` table to track earnings
    - Create `picker_payouts` table to track payout history
    
  2. Security
    - Enable RLS on new tables
    - Add policies for pickers to view their own data
*/

-- Add missing columns to picker_payout_info
ALTER TABLE picker_payout_info 
ADD COLUMN IF NOT EXISTS details_submitted boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS bank_account_name text,
ADD COLUMN IF NOT EXISTS bank_account_number text,
ADD COLUMN IF NOT EXISTS bank_account_last4 text,
ADD COLUMN IF NOT EXISTS bank_swift_code text,
ADD COLUMN IF NOT EXISTS country text DEFAULT 'US',
ADD COLUMN IF NOT EXISTS currency text DEFAULT 'USD';

-- Create picker_earnings table to track all earnings
CREATE TABLE IF NOT EXISTS picker_earnings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  amount numeric(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  platform_fee numeric(10,2) DEFAULT 0,
  net_amount numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'available', 'paid')),
  payment_intent_id text,
  created_at timestamptz DEFAULT now(),
  available_at timestamptz,
  paid_at timestamptz
);

ALTER TABLE picker_earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pickers can view own earnings"
  ON picker_earnings FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Create picker_payouts table to track payout history
CREATE TABLE IF NOT EXISTS picker_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount numeric(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed')),
  stripe_payout_id text,
  stripe_transfer_id text,
  failure_reason text,
  created_at timestamptz DEFAULT now(),
  paid_at timestamptz,
  metadata jsonb DEFAULT '{}'::jsonb
);

ALTER TABLE picker_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pickers can view own payouts"
  ON picker_payouts FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_picker_earnings_picker_id ON picker_earnings(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_earnings_status ON picker_earnings(status);
CREATE INDEX IF NOT EXISTS idx_picker_earnings_created_at ON picker_earnings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_picker_payouts_picker_id ON picker_payouts(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_payouts_created_at ON picker_payouts(created_at DESC);
