/*
  # Add Missing Conversation Tracking Columns

  1. Changes
    - Add last_message, last_message_at columns to conversations
    - Add client_unread_count and picker_unread_count for badge counts
    - Create trigger to update these columns automatically
  
  2. Security
    - Maintains existing RLS policies
*/

-- Add missing columns if they don't exist
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

-- Create or replace function to update conversation metadata
CREATE OR REPLACE FUNCTION update_conversation_metadata()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update last_message and last_message_at
  UPDATE conversations
  SET 
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    updated_at = NEW.created_at
  WHERE id = NEW.conversation_id;

  -- Increment unread count for the recipient
  IF NEW.sender_id = (SELECT client_id FROM conversations WHERE id = NEW.conversation_id) THEN
    -- Sender is client, increment picker unread
    UPDATE conversations
    SET picker_unread_count = picker_unread_count + 1
    WHERE id = NEW.conversation_id;
  ELSE
    -- Sender is picker, increment client unread
    UPDATE conversations
    SET client_unread_count = client_unread_count + 1
    WHERE id = NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_update_conversation_metadata ON conversation_messages;
CREATE TRIGGER trigger_update_conversation_metadata
  AFTER INSERT ON conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_metadata();