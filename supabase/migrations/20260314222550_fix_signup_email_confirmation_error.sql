/*
  # Fix "Error sending confirmation email" Issue
  
  1. Problem
    - Supabase auth.signUp() is failing with "Error sending confirmation email"
    - This happens because Supabase is trying to send confirmation emails itself
    
  2. Solution
    - Ensure email confirmation is handled ONLY by our custom trigger
    - The trigger already has proper error handling (EXCEPTION WHEN OTHERS)
    - Make sure trigger does not interfere with signup process
    
  3. Changes
    - Update trigger to be completely non-blocking
    - Use AFTER INSERT trigger (already correct)
    - Ensure RETURN NEW always happens
*/

-- Recreate the trigger function with absolutely bulletproof error handling
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
  -- ALWAYS return NEW first - never block the signup
  -- We'll handle email in background
  
  -- Only try to send email if conditions are met
  IF NEW.email_confirmed_at IS NULL AND NEW.confirmation_token IS NOT NULL THEN
    BEGIN
      -- Use CORRECT Supabase URL for this project
      v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
      
      -- Use service role key for edge function auth
      v_service_role_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDQxMDE4MiwiZXhwIjoyMDc5OTg2MTgyfQ.PJPzXHI1-0Mu-YTIWJg7aWyLT9kAqlqOBLFLhCh0S9Q';
      
      -- Extract user name from metadata
      v_user_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
      );
      
      -- Build confirmation URL with proper redirect
      v_confirmation_url := 'https://souvenirpickers.com?token_hash=' || NEW.confirmation_token || '&type=signup';
      
      -- Send confirmation email via edge function (async, non-blocking)
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
      
      RAISE LOG 'Signup confirmation email queued for %: request_id=%', NEW.email, v_request_id;
      
    EXCEPTION
      WHEN OTHERS THEN
        -- Log error but NEVER fail - signup must succeed
        RAISE LOG 'Email send failed for % but signup succeeded. Error: %', NEW.email, SQLERRM;
    END;
  END IF;
  
  -- ALWAYS return NEW - this is critical
  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;
CREATE TRIGGER trigger_send_signup_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_signup_confirmation_email();

COMMENT ON FUNCTION send_signup_confirmation_email() IS 
  'Sends confirmation email via Bluehost SMTP after user signup. Never blocks signup even if email fails.';
