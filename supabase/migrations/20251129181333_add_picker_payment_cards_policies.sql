/*
  # Add RLS Policies for Picker Payment Cards

  1. Security
    - Enable RLS on picker_payment_cards table
    - Add policies for pickers to manage their own payment cards
    
  2. Policies
    - Pickers can view their own payment cards
    - Pickers can insert their own payment cards
    - Pickers can update their own payment cards
    - Pickers can delete their own payment cards
*/

-- Ensure RLS is enabled
ALTER TABLE picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pickers can view own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can add own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can update own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can delete own payment cards" ON picker_payment_cards;

-- Create policies for picker_payment_cards
CREATE POLICY "Pickers can view own payment cards"
  ON picker_payment_cards FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Pickers can add own payment cards"
  ON picker_payment_cards FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can update own payment cards"
  ON picker_payment_cards FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can delete own payment cards"
  ON picker_payment_cards FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());
