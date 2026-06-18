/*
  # Create Support Chat System

  1. New Tables
    - `support_conversations`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `status` (text: open, closed) - conversation status
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `support_messages`
      - `id` (uuid, primary key)
      - `support_conversation_id` (uuid, foreign key to support_conversations)
      - `sender_id` (text) - user id or 'system' for automated messages
      - `content` (text) - message content
      - `is_support` (boolean) - true if message is from support team
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Users can only view/create their own support conversations
    - Users can only view/create messages in their own conversations
    - Support staff can view all (handled via service role)
*/

-- Create support_conversations table
CREATE TABLE IF NOT EXISTS support_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create support_messages table
CREATE TABLE IF NOT EXISTS support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  support_conversation_id uuid REFERENCES support_conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id text NOT NULL,
  content text NOT NULL,
  is_support boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_support_conversations_user_id ON support_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_support_conversations_status ON support_conversations(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_conversation_id ON support_messages(support_conversation_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at);

-- Enable RLS
ALTER TABLE support_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for support_conversations

-- Users can view their own conversations
CREATE POLICY "Users can view own support conversations"
  ON support_conversations
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can create their own conversations
CREATE POLICY "Users can create own support conversations"
  ON support_conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own conversations
CREATE POLICY "Users can update own support conversations"
  ON support_conversations
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policies for support_messages

-- Users can view messages in their own conversations
CREATE POLICY "Users can view messages in own support conversations"
  ON support_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = support_messages.support_conversation_id
      AND support_conversations.user_id = auth.uid()
    )
  );

-- Users can create messages in their own conversations
CREATE POLICY "Users can create messages in own support conversations"
  ON support_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM support_conversations
      WHERE support_conversations.id = support_messages.support_conversation_id
      AND support_conversations.user_id = auth.uid()
    )
  );

-- Create function to update support_conversations.updated_at
CREATE OR REPLACE FUNCTION update_support_conversation_updated_at()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE support_conversations
  SET updated_at = now()
  WHERE id = NEW.support_conversation_id;
  RETURN NEW;
END;
$$;

-- Create trigger to update updated_at when new message is added
DROP TRIGGER IF EXISTS trigger_update_support_conversation_updated_at ON support_messages;
CREATE TRIGGER trigger_update_support_conversation_updated_at
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_support_conversation_updated_at();

-- Grant necessary permissions
GRANT ALL ON support_conversations TO authenticated;
GRANT ALL ON support_messages TO authenticated;
