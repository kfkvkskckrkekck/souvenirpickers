/*
  # Fix Custom Orders Insert Policy

  1. Changes
    - Drop the existing restrictive insert policy that checks auth.uid() = picker_id
    - Create a new insert policy that checks if the user has a picker_profile
    - This allows pickers to insert custom orders using their picker_profile.id

  2. Security
    - Only authenticated users with picker profiles can create custom orders
    - The policy verifies the user owns the picker_profile they're inserting with
*/

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Pickers can create custom orders" ON custom_orders;

-- Create a new policy that checks if the user has a matching picker_profile
CREATE POLICY "Pickers can create custom orders"
  ON custom_orders
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = custom_orders.picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );