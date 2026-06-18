/*
  # Update Support Email Address
  
  1. Changes
    - Update support ticket notification function to use correct Titan email: support@souvenirpickers.com
    - This ensures support ticket notifications go to the correct professional email inbox
  
  2. Security
    - Function maintains SECURITY DEFINER for proper authorization
*/

-- Update function to use correct support email address
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
  v_support_email text;
BEGIN
  -- Get user profile information
  SELECT full_name, email INTO v_user_profile
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Get Supabase URL from environment or use hardcoded
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  v_function_url := v_supabase_url || '/functions/v1/send-email-notification';
  
  -- Use the correct Titan email address
  v_support_email := 'support@souvenirpickers.com';
  
  -- Get service role key from vault or environment
  BEGIN
    v_service_role_key := current_setting('app.settings.service_role_key', true);
  EXCEPTION WHEN OTHERS THEN
    v_service_role_key := NULL;
  END;
  
  -- Call edge function to send email to support team via Titan email
  BEGIN
    SELECT net.http_post(
      url := v_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
      ),
      body := jsonb_build_object(
        'to', v_support_email,
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
    
    RAISE NOTICE 'Support ticket email request sent to %: request_id=%', v_support_email, v_request_id;
    
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the ticket creation
    RAISE WARNING 'Failed to send support ticket email: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
  END;
  
  RETURN NEW;
END;
$$;