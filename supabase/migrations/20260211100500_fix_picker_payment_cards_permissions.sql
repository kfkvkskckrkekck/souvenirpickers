/*
  # Fix Picker Payment Cards Permissions
  
  1. Problem
    - Users getting "permission denied for table picker_payment_cards" error
    - Need to ensure grants and policies are properly configured
    
  2. Solution
    - Re-grant all necessary permissions
    - Ensure RLS policies are correct
    - Add service role bypass if needed
    
  3. Security
    - Authenticated users can only access their own payment cards
    - RLS policies enforce user ownership
*/

-- Ensure the table exists and RLS is enabled
ALTER TABLE IF EXISTS picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Grant full permissions to authenticated users (RLS will control access)
GRANT ALL ON picker_payment_cards TO authenticated;
GRANT ALL ON picker_payment_cards TO service_role;

-- Grant usage on the sequence
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Drop and recreate policies to ensure they're correct
DROP POLICY IF EXISTS "Pickers can view own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can add own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can update own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can delete own payment cards" ON picker_payment_cards;

-- Allow service role to bypass RLS
ALTER TABLE picker_payment_cards FORCE ROW LEVEL SECURITY;

-- Create policies for authenticated users
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

-- Do the same for collector_payment_methods
ALTER TABLE IF EXISTS collector_payment_methods ENABLE ROW LEVEL SECURITY;

GRANT ALL ON collector_payment_methods TO authenticated;
GRANT ALL ON collector_payment_methods TO service_role;

DROP POLICY IF EXISTS "Users can view own payment methods" ON collector_payment_methods;
DROP POLICY IF EXISTS "Users can add own payment methods" ON collector_payment_methods;
DROP POLICY IF EXISTS "Users can update own payment methods" ON collector_payment_methods;
DROP POLICY IF EXISTS "Users can delete own payment methods" ON collector_payment_methods;

ALTER TABLE collector_payment_methods FORCE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own payment methods"
  ON collector_payment_methods FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can add own payment methods"
  ON collector_payment_methods FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own payment methods"
  ON collector_payment_methods FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own payment methods"
  ON collector_payment_methods FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
