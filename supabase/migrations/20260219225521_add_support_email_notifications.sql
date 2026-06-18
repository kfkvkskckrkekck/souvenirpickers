/*
  # Add Support Email Notifications

  1. Changes
    - Create trigger function to send email notifications when users send support messages
    - Trigger sends email to support@souvenirpickers.com with user's message
    - Only sends email for non-support messages (from users, not support team)
    
  2. Security
    - Function runs as SECURITY DEFINER to call edge function
    - Only triggers on INSERT of new support messages
*/

-- Create function to send support email notification
CREATE OR REPLACE FUNCTION notify_support_team_of_new_message()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_profile record;
  v_conversation record;
BEGIN
  -- Only send email if message is from user (not support team)
  IF NEW.is_support = false AND NEW.sender_id != 'system' THEN
    
    -- Get user profile information
    SELECT full_name, email INTO v_user_profile
    FROM profiles
    WHERE id = NEW.sender_id::uuid;
    
    -- Get conversation details
    SELECT user_id, created_at INTO v_conversation
    FROM support_conversations
    WHERE id = NEW.support_conversation_id;
    
    -- Call edge function to send email to support team
    PERFORM net.http_post(
      url := current_setting('app.supabase_url', true) || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
      ),
      body := jsonb_build_object(
        'to', 'support@souvenirpickers.com',
        'subject', 'New Support Message from ' || COALESCE(v_user_profile.full_name, 'User'),
        'type', 'support_message_received',
        'data', jsonb_build_object(
          'user_name', COALESCE(v_user_profile.full_name, 'A user'),
          'user_email', v_user_profile.email,
          'message', NEW.content,
          'conversation_id', NEW.support_conversation_id,
          'message_id', NEW.id,
          'sent_at', NEW.created_at
        )
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to notify support team
DROP TRIGGER IF EXISTS trigger_notify_support_team ON support_messages;
CREATE TRIGGER trigger_notify_support_team
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_support_team_of_new_message();
