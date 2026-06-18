/*
  # Add RLS policies for conversation_messages table

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for conversation_messages table
  
  2. Security
    - Users can view messages in their conversations
    - Users can send messages in their conversations
    - Users can update their own messages
*/

-- Conversation messages policies
CREATE POLICY "Users can view messages in their conversations"
  ON conversation_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE conversations.id = conversation_messages.conversation_id
      AND (conversations.client_id = auth.uid() OR conversations.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their conversations"
  ON conversation_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations
      WHERE conversations.id = conversation_id
      AND (conversations.client_id = auth.uid() OR conversations.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their own messages"
  ON conversation_messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);
