/*
  # Fix Referral Rewards RLS Policies
  
  ## Problem
  The referral_rewards table has RLS enabled but NO policies defined.
  This prevents users from viewing their referral rewards.
  
  ## Changes
  1. Add SELECT policy for users to view their own rewards (as referrer or referred)
  2. Add INSERT policy for system to create rewards (authenticated users)
  
  ## Security
  - Users can view rewards where they are the referrer OR the referred person
  - Only authenticated users can insert rewards (typically done by backend/triggers)
*/

-- Drop existing policies if any (safety measure)
DROP POLICY IF EXISTS "Users can view own rewards" ON referral_rewards;
DROP POLICY IF EXISTS "Users can create rewards" ON referral_rewards;

-- Allow users to view rewards where they are involved (referrer or referred)
CREATE POLICY "Users can view own rewards"
  ON referral_rewards
  FOR SELECT
  TO authenticated
  USING (referrer_id = auth.uid() OR referred_id = auth.uid());

-- Allow authenticated users to insert rewards (for signup flow)
CREATE POLICY "Users can create rewards"
  ON referral_rewards
  FOR INSERT
  TO authenticated
  WITH CHECK (true);
