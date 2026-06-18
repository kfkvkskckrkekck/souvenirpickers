/*
  # Fix Support Ticket Email Trigger

  1. Changes
    - Update trigger function to use correct column name 'description' instead of 'message'
    - Ensure proper error handling and logging
    
  2. Security
    - Function runs as SECURITY DEFINER to call edge function
*/

-- Update function to send support ticket email notification with correct column name
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
        'user_email', COALESCE(v_user_profile.email, 'unknown@example.com'),
        'subject', NEW.subject,
        'category', NEW.category,
        'message', NEW.description,
        'priority', NEW.priority,
        'created_at', NEW.created_at
      )
    )
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the ticket creation
    RAISE WARNING 'Failed to send support ticket email: %', SQLERRM;
    RETURN NEW;
END;
$$;