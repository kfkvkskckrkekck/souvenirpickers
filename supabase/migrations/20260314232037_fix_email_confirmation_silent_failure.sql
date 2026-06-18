/*
  # Fix Email Confirmation - Silent Failure Mode
  
  1. Problem
    - The trigger is catching errors and displaying them to users during signup
    - This breaks the user experience even though the account is created
    
  2. Solution
    - Make the trigger completely silent - NEVER raise any errors
    - Log everything but never interrupt the signup process
    - Email sending failures should be invisible to the user
    
  3. Changes
    - Update trigger to catch ALL exceptions silently
    - Only log warnings, never raise errors to the user
*/

CREATE OR REPLACE FUNCTION send_signup_confirmation_email()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
  v_confirmation_url text;
  v_user_name text;
  v_supabase_url text;
  v_service_role_key text;
  v_request_id bigint;
BEGIN
  -- Silently skip if email confirmation is disabled
  IF NEW.confirmation_token IS NULL OR NEW.confirmation_token = '' THEN
    RETURN NEW;
  END IF;
  
  -- Only send confirmation email if user is not yet confirmed
  IF NEW.email_confirmed_at IS NULL THEN
    BEGIN
      v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
      v_service_role_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDQxMDE4MiwiZXhwIjoyMDc5OTg2MTgyfQ.PJPzXHI1-0Mu-YTIWJg7aWyLT9kAqlqOBLFLhCh0S9Q';
      
      v_user_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
      );
      
      -- Build proper confirmation URL
      v_confirmation_url := 'https://souvenirpickers.com?token_hash=' || NEW.confirmation_token || '&type=signup';
      
      -- Send confirmation email via edge function - catch ALL errors silently
      SELECT INTO v_request_id net.http_post(
        url := v_supabase_url || '/functions/v1/send-email-notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body := jsonb_build_object(
          'to', NEW.email,
          'subject', 'Welcome to SouvenirPickers - Please Confirm Your Email',
          'type', 'email_confirmation',
          'data', jsonb_build_object(
            'user_name', v_user_name,
            'confirmation_url', v_confirmation_url
          )
        )
      );
      
      -- Log success silently
      RAISE LOG 'Confirmation email queued for %: request_id=%', NEW.email, v_request_id;
      
    EXCEPTION
      WHEN OTHERS THEN
        -- Catch ALL errors silently - do not interrupt signup
        RAISE LOG 'Failed to send confirmation email for % (this is OK, signup continues): %', NEW.email, SQLERRM;
    END;
  END IF;
  
  -- ALWAYS return NEW to allow signup to complete
  RETURN NEW;
END;
$$;

-- Ensure trigger is active
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;
CREATE TRIGGER trigger_send_signup_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_signup_confirmation_email();

COMMENT ON FUNCTION send_signup_confirmation_email() IS 
  'Silently sends email confirmation via custom SMTP. Never interrupts signup even if email fails.';
