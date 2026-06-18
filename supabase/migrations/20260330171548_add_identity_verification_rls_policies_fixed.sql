/*
  # Add RLS policies for identity_verifications table

  1. Security Policies
    - Users can insert their own verification records
    - Users can view their own verification records
    - Users can update their own pending verifications
*/

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert own verifications" ON identity_verifications;
DROP POLICY IF EXISTS "Users can view own verifications" ON identity_verifications;
DROP POLICY IF EXISTS "Users can update own pending verifications" ON identity_verifications;

-- Allow users to insert their own verification records
CREATE POLICY "Users can insert own verifications"
  ON identity_verifications
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Allow users to view their own verification records
CREATE POLICY "Users can view own verifications"
  ON identity_verifications
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow users to update their own pending verifications
CREATE POLICY "Users can update own pending verifications"
  ON identity_verifications
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (auth.uid() = user_id);