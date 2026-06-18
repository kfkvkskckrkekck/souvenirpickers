/*
  # Add UPDATE policy for profiles table

  1. Changes
    - Add policy to allow authenticated users to update their own profile
    - This enables users to switch between picker and client modes
  
  2. Security
    - Users can only update their own profile (auth.uid() = id)
    - Prevents users from modifying other users' profiles
*/

CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
