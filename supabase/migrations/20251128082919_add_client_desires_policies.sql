/*
  # Add RLS policies for client_desires table

  1. Changes
    - Add SELECT, INSERT, UPDATE, DELETE policies for client_desires table
  
  2. Security
    - Pickers can view all active desires
    - Clients can view their own desires
    - Clients can create their own desires
    - Clients can update/delete their own desires
*/

-- Clients can view their own desires
CREATE POLICY "Clients can view own desires"
  ON client_desires
  FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- Pickers can view all active desires
CREATE POLICY "Pickers can view active desires"
  ON client_desires
  FOR SELECT
  TO authenticated
  USING (
    active = true AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'picker'
    )
  );

-- Clients can create their own desires
CREATE POLICY "Clients can create desires"
  ON client_desires
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'client'
    )
  );

-- Clients can update their own desires
CREATE POLICY "Clients can update own desires"
  ON client_desires
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (auth.uid() = client_id);

-- Clients can delete their own desires
CREATE POLICY "Clients can delete own desires"
  ON client_desires
  FOR DELETE
  TO authenticated
  USING (auth.uid() = client_id);
