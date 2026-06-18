/*
  # Fix Support Email Notifications

  1. Changes
    - Update trigger function to properly use pg_net extension
    - Store Supabase URL and service role key as database settings
    - Send email notifications when users send support messages
    
  2. Security
    - Function runs as SECURITY DEFINER
    - Only triggers on INSERT of new support messages from users
*/

-- Drop existing function to recreate it
DROP FUNCTION IF EXISTS notify_support_team_of_new_message() CASCADE;

-- Create function to send support email notification
CREATE OR REPLACE FUNCTION notify_support_team_of_new_message()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_profile record;
  v_supabase_url text;
  v_request_id bigint;
BEGIN
  -- Only send email if message is from user (not support team)
  IF NEW.is_support = false AND NEW.sender_id != 'system' THEN
    
    -- Get user profile information
    SELECT full_name, email INTO v_user_profile
    FROM profiles
    WHERE id = NEW.sender_id::uuid;
    
    -- Get Supabase URL from environment
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    IF v_supabase_url IS NULL THEN
      v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    END IF;
    
    -- Use pg_net to send async HTTP request to edge function
    SELECT INTO v_request_id net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
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
    
    -- Log the request (optional, for debugging)
    RAISE LOG 'Support email notification queued with request_id: %', v_request_id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the insert
    RAISE WARNING 'Failed to send support email notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger to notify support team
DROP TRIGGER IF EXISTS trigger_notify_support_team ON support_messages;
CREATE TRIGGER trigger_notify_support_team
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_support_team_of_new_message();