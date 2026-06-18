-- Real-Time Chat System
--
-- 1. Updates to existing tables
--    - Add read_at timestamp to conversation_messages
--    - Add last_message and unread_count to conversations
--    - Add typing indicators
--
-- 2. New Tables
--    - message_reactions: React to messages with emojis
--    - message_attachments: Store file attachments
--    - typing_indicators: Track who is typing
--
-- 3. Security
--    - Enable RLS on all tables
--    - Real-time subscriptions enabled

-- Add new columns to conversation_messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'read_at'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN read_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'edited_at'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN edited_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'deleted'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN deleted boolean DEFAULT false;
  END IF;
END $$;

-- Add columns to conversations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'last_message'
  ) THEN
    ALTER TABLE conversations ADD COLUMN last_message text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'last_message_at'
  ) THEN
    ALTER TABLE conversations ADD COLUMN last_message_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'client_unread_count'
  ) THEN
    ALTER TABLE conversations ADD COLUMN client_unread_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'picker_unread_count'
  ) THEN
    ALTER TABLE conversations ADD COLUMN picker_unread_count integer DEFAULT 0;
  END IF;
END $$;

-- Create message_reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES conversation_messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(message_id, user_id, reaction)
);

-- Create message_attachments table
CREATE TABLE IF NOT EXISTS message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES conversation_messages(id) ON DELETE CASCADE,
  file_url text NOT NULL,
  file_name text,
  file_type text,
  file_size bigint,
  created_at timestamptz DEFAULT now()
);

-- Create typing_indicators table
CREATE TABLE IF NOT EXISTS typing_indicators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  is_typing boolean DEFAULT true,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- Policies for message_reactions
CREATE POLICY "Users can view reactions in their conversations"
  ON message_reactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.id = message_reactions.message_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can add reactions"
  ON message_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove their reactions"
  ON message_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Policies for message_attachments
CREATE POLICY "Users can view attachments in their conversations"
  ON message_attachments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.id = message_attachments.message_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can add attachments to their messages"
  ON message_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      WHERE cm.id = message_id
      AND cm.sender_id = auth.uid()
    )
  );

-- Policies for typing_indicators
CREATE POLICY "Users can view typing in their conversations"
  ON typing_indicators FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = typing_indicators.conversation_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their typing status"
  ON typing_indicators FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_attachments_message_id ON message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_conversation_id ON typing_indicators(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_read ON conversation_messages(conversation_id, read_at);

-- Function to update conversation last message
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET 
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    updated_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update last message
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_message_sent_update_conversation'
  ) THEN
    CREATE TRIGGER on_message_sent_update_conversation
      AFTER INSERT ON conversation_messages
      FOR EACH ROW
      EXECUTE FUNCTION update_conversation_last_message();
  END IF;
END $$;

-- Function to update unread counts
CREATE OR REPLACE FUNCTION update_unread_counts()
RETURNS TRIGGER AS $$
DECLARE
  conv_client_id uuid;
  conv_picker_id uuid;
BEGIN
  SELECT client_id, picker_id INTO conv_client_id, conv_picker_id
  FROM conversations
  WHERE id = NEW.conversation_id;

  IF NEW.sender_id = conv_client_id THEN
    UPDATE conversations
    SET picker_unread_count = picker_unread_count + 1
    WHERE id = NEW.conversation_id;
  ELSE
    UPDATE conversations
    SET client_unread_count = client_unread_count + 1
    WHERE id = NEW.conversation_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for unread counts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_message_sent_update_unread'
  ) THEN
    CREATE TRIGGER on_message_sent_update_unread
      AFTER INSERT ON conversation_messages
      FOR EACH ROW
      EXECUTE FUNCTION update_unread_counts();
  END IF;
END $$;

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE conversation_messages
  SET read_at = now()
  WHERE conversation_id = p_conversation_id
  AND sender_id != auth.uid()
  AND read_at IS NULL;

  UPDATE conversations
  SET 
    client_unread_count = CASE WHEN client_id = auth.uid() THEN 0 ELSE client_unread_count END,
    picker_unread_count = CASE WHEN picker_id = auth.uid() THEN 0 ELSE picker_unread_count END
  WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
