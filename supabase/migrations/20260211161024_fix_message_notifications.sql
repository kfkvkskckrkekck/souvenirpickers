/*
  # Fix Message Notifications System

  1. Changes
    - Fix notify_new_message() to use conversations table (client_id, picker_id) instead of non-existent conversation_participants
    - Add in-app notification creation to notifications table
    - Ensure unread message counts update properly in the header

  2. Security
    - Uses SECURITY DEFINER to ensure proper access
    - Creates notifications only for the recipient user
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_new_message_notification ON conversation_messages;
DROP FUNCTION IF EXISTS notify_new_message();

-- Create improved function to send new message notifications
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_id uuid;
  v_recipient_email text;
  v_recipient_name text;
  v_sender_name text;
  v_supabase_url text;
  v_message_preview text;
  v_conversation conversations%ROWTYPE;
BEGIN
  -- Get conversation details
  SELECT * INTO v_conversation
  FROM conversations
  WHERE id = NEW.conversation_id;

  -- Determine recipient (the person who didn't send the message)
  IF NEW.sender_id = v_conversation.client_id THEN
    v_recipient_id := v_conversation.picker_id;
  ELSE
    v_recipient_id := v_conversation.client_id;
  END IF;

  -- Get recipient details
  SELECT email, full_name
  INTO v_recipient_email, v_recipient_name
  FROM profiles
  WHERE id = v_recipient_id;

  -- Get sender name
  SELECT full_name
  INTO v_sender_name
  FROM profiles
  WHERE id = NEW.sender_id;

  -- Create in-app notification for recipient
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read,
    metadata
  ) VALUES (
    v_recipient_id,
    'new_message',
    'New message from ' || COALESCE(v_sender_name, 'a user'),
    substring(NEW.content, 1, 100) || CASE WHEN length(NEW.content) > 100 THEN '...' ELSE '' END,
    false,
    jsonb_build_object(
      'conversation_id', NEW.conversation_id,
      'message_id', NEW.id,
      'sender_id', NEW.sender_id,
      'sender_name', v_sender_name
    )
  );

  -- Send email notification (if recipient email exists)
  IF v_recipient_email IS NOT NULL THEN
    -- Get Supabase URL from environment
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    IF v_supabase_url IS NULL THEN
      v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    END IF;

    -- Create message preview (first 100 characters)
    v_message_preview := substring(NEW.content, 1, 100);
    IF length(NEW.content) > 100 THEN
      v_message_preview := v_message_preview || '...';
    END IF;

    -- Send email notification
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_recipient_email,
        'subject', 'New message from ' || COALESCE(v_sender_name, 'a user'),
        'type', 'message_received',
        'data', jsonb_build_object(
          'recipient_name', COALESCE(v_recipient_name, 'there'),
          'sender_name', COALESCE(v_sender_name, 'Someone'),
          'message_preview', v_message_preview
        )
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error sending message notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Recreate trigger for new messages
CREATE TRIGGER trigger_new_message_notification
  AFTER INSERT ON conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();

-- Add index for faster notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_type_user ON notifications(type, user_id);