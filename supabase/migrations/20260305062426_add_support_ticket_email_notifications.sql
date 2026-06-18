/*
  # Add Support Ticket Email Notifications

  1. Changes
    - Create trigger function to send email notifications when users submit support tickets
    - Trigger sends email to support@souvenirpickers.com with ticket details
    - Includes user information, subject, category, and full message
    
  2. Security
    - Function runs as SECURITY DEFINER to call edge function
    - Only triggers on INSERT of new support tickets
*/

-- Create function to send support ticket email notification
CREATE OR REPLACE FUNCTION notify_support_team_of_new_ticket()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_profile record;
  v_supabase_url text;
  v_function_url text;
BEGIN
  -- Get user profile information
  SELECT full_name, email INTO v_user_profile
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings', true)::json->>'supabase_url';
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  END IF;
  
  v_function_url := v_supabase_url || '/functions/v1/send-email-notification';
  
  -- Call edge function to send email to support team
  PERFORM net.http_post(
    url := v_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'to', 'support@souvenirpickers.com',
      'subject', 'New Support Ticket: ' || NEW.subject,
      'type', 'support_ticket',
      'data', jsonb_build_object(
        'ticket_id', NEW.id,
        'user_name', COALESCE(v_user_profile.full_name, 'User'),
        'user_email', v_user_profile.email,
        'subject', NEW.subject,
        'category', NEW.category,
        'message', NEW.message,
        'priority', NEW.priority,
        'created_at', NEW.created_at
      )
    )
  );
  
  RETURN NEW;
END;
$$;

-- Create trigger to notify support team when new ticket is created
DROP TRIGGER IF EXISTS trigger_notify_support_team_ticket ON support_tickets;
CREATE TRIGGER trigger_notify_support_team_ticket
  AFTER INSERT ON support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION notify_support_team_of_new_ticket();