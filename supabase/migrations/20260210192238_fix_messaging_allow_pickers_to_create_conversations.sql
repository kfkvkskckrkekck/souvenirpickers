/*
  # Fix Messaging - Allow Pickers to Create Conversations

  1. Problem
    - Current policy only allows clients to create conversations
    - Pickers cannot respond to client desires because they can't create conversations

  2. Solution
    - Update INSERT policy to allow both clients and pickers to create conversations
    - Ensure the creator is one of the participants
*/

-- Drop the restrictive policy
DROP POLICY IF EXISTS "Clients can create conversations with pickers" ON conversations;

-- Create a new policy that allows both clients and pickers to create conversations
CREATE POLICY "Users can create conversations they participate in"
  ON conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id OR auth.uid() = picker_id
  );

-- Also add UPDATE policy if it doesn't exist
DROP POLICY IF EXISTS "Users can update their conversations" ON conversations;

CREATE POLICY "Users can update their conversations"
  ON conversations
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id OR auth.uid() = picker_id)
  WITH CHECK (auth.uid() = client_id OR auth.uid() = picker_id);