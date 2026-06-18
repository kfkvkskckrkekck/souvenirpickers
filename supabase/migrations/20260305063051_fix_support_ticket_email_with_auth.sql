/*
  # Fix Support Ticket Email Trigger with Proper Authentication

  1. Changes
    - Update trigger function to include service role authorization header
    - Add proper error logging for debugging
    - Ensure edge function is called with correct authentication
    
  2. Security
    - Function runs as SECURITY DEFINER to access service role key
*/

-- Update function to send support ticket email notification with authentication
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
  v_service_role_key text;
  v_request_id bigint;
BEGIN
  -- Get user profile information
  SELECT full_name, email INTO v_user_profile
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Get Supabase URL from environment or use hardcoded
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  v_function_url := v_supabase_url || '/functions/v1/send-email-notification';
  
  -- Get service role key from vault or environment
  BEGIN
    v_service_role_key := current_setting('app.settings.service_role_key', true);
  EXCEPTION WHEN OTHERS THEN
    v_service_role_key := NULL;
  END;
  
  -- Call edge function to send email to support team
  BEGIN
    SELECT net.http_post(
      url := v_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || COALESCE(v_service_role_key, '')
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
          'category', COALESCE(NEW.category, 'other'),
          'message', NEW.description,
          'priority', COALESCE(NEW.priority, 'medium'),
          'created_at', NEW.created_at
        )
      )
    ) INTO v_request_id;
    
    RAISE NOTICE 'Support ticket email request sent: request_id=%', v_request_id;
    
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the ticket creation
    RAISE WARNING 'Failed to send support ticket email: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
  END;
  
  RETURN NEW;
END;
$$;