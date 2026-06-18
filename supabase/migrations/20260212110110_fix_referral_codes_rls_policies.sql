/*
  # Fix Referral Codes RLS Policies
  
  ## Problem
  The referral_codes table has RLS enabled but NO policies defined.
  This prevents authenticated users from inserting or viewing their referral codes.
  
  ## Changes
  1. Add INSERT policy for users to create their own referral code
  2. Add SELECT policy for users to view their own referral code
  3. Add UPDATE policy for users to update their own referral code (for uses_count)
  
  ## Security
  - Users can only insert/update/select their own referral codes (user_id = auth.uid())
  - No access to other users' codes
*/

-- Drop existing policies if any (safety measure)
DROP POLICY IF EXISTS "Users can view own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Users can create own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Users can update own referral code" ON referral_codes;

-- Allow users to view their own referral code
CREATE POLICY "Users can view own referral code"
  ON referral_codes
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Allow users to create their own referral code
CREATE POLICY "Users can create own referral code"
  ON referral_codes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Allow users to update their own referral code (for uses_count increments)
CREATE POLICY "Users can update own referral code"
  ON referral_codes
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
