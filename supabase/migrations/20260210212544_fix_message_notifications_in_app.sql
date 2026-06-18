/*
  # Fix Message Notifications to Show in App

  1. Changes
    - Update notify_new_message() function to create in-app notifications
    - Ensures pickers see notification badge when they receive messages
    - Keeps email notifications working
  
  2. Security
    - Maintains existing RLS policies
    - Uses SECURITY DEFINER for system operations
*/

-- Drop and recreate the function to add in-app notifications
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient_id uuid;
  v_recipient_email text;
  v_recipient_name text;
  v_sender_name text;
  v_supabase_url text;
  v_message_preview text;
  v_conversation_id uuid;
BEGIN
  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://gejhwupzezmuektmaiyg.supabase.co';
  END IF;

  -- Get sender name
  SELECT full_name INTO v_sender_name
  FROM profiles
  WHERE id = NEW.sender_id;

  -- Create message preview (first 100 characters)
  v_message_preview := substring(NEW.content, 1, 100);
  IF length(NEW.content) > 100 THEN
    v_message_preview := v_message_preview || '...';
  END IF;

  -- Get conversation details
  SELECT id INTO v_conversation_id
  FROM conversations
  WHERE id = NEW.conversation_id;

  -- Get recipient details (the other person in the conversation)
  SELECT 
    CASE 
      WHEN c.client_id = NEW.sender_id THEN c.picker_id
      ELSE c.client_id
    END,
    p.email,
    p.full_name
  INTO v_recipient_id, v_recipient_email, v_recipient_name
  FROM conversations c
  JOIN profiles p ON p.id = CASE 
    WHEN c.client_id = NEW.sender_id THEN c.picker_id
    ELSE c.client_id
  END
  WHERE c.id = NEW.conversation_id;

  -- Create in-app notification for recipient
  IF v_recipient_id IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      read
    ) VALUES (
      v_recipient_id,
      'message',
      'New message from ' || COALESCE(v_sender_name, 'a user'),
      v_message_preview,
      '/messages',
      false
    );
  END IF;

  -- Send email notification to recipient
  IF v_recipient_email IS NOT NULL THEN
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