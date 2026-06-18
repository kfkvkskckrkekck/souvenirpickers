/*
  # Add RLS policies for orders, conversations, and messages

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for orders table
    - Add SELECT, INSERT, UPDATE policies for conversations table
    - Add SELECT, INSERT, UPDATE policies for messages table
  
  2. Security
    - Orders: accessible by client who placed order or picker who received it
    - Conversations: accessible by both participants
    - Messages: accessible by sender and recipient
*/

-- Orders policies
CREATE POLICY "Users can view their orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Clients can create orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update their orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  )
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

-- Conversations policies
CREATE POLICY "Users can view their conversations"
  ON conversations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Users can create conversations"
  ON conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Users can update their conversations"
  ON conversations
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  )
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

-- Messages policies
CREATE POLICY "Users can view their messages"
  ON messages
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = sender_id OR 
    auth.uid() = recipient_id
  );

CREATE POLICY "Users can send messages"
  ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own messages"
  ON messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);
