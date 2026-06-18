/*
  # Add RLS Policies for Listings Table

  1. Security Changes
    - Add INSERT policy for pickers to create their own listings
    - Add UPDATE policy for pickers to edit their own listings
    - Add DELETE policy for pickers to remove their own listings

  2. Notes
    - Pickers can only manage listings associated with their picker_profile
    - Clients can only view listings (existing SELECT policy)
*/

-- Allow pickers to insert their own listings
CREATE POLICY "Pickers can create own listings"
  ON listings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Allow pickers to update their own listings
CREATE POLICY "Pickers can update own listings"
  ON listings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Allow pickers to delete their own listings
CREATE POLICY "Pickers can delete own listings"
  ON listings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );