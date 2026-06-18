/*
  # Fix Email Confirmation using pg_net properly

  1. Changes
    - Use extensions.net.http_post with correct syntax
    - Include proper authentication headers
    - Fix confirmation URL to redirect to production domain
    
  2. Security
    - Uses extensions.net module for HTTP requests
    - Function runs as SECURITY DEFINER
*/

-- Drop existing function and trigger
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;
DROP FUNCTION IF EXISTS send_signup_confirmation_email();

-- Create function using pg_net correctly
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
  v_request_id bigint;
BEGIN
  -- Only send email if email is not yet confirmed
  IF NEW.email_confirmed_at IS NULL AND NEW.confirmation_token IS NOT NULL THEN
    
    -- Set Supabase URL
    v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    
    -- Extract user name from metadata
    v_user_name := COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    );
    
    -- Build confirmation URL with redirect to production domain
    v_confirmation_url := v_supabase_url || '/auth/v1/verify?token=' || 
                          NEW.confirmation_token || 
                          '&type=signup&redirect_to=https://souvenirpickers.com';
    
    -- Send confirmation email via edge function using pg_net
    SELECT extensions.net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDQxMDE4MiwiZXhwIjoyMDc5OTg2MTgyfQ.PJPzXHI1-0Mu-YTIWJg7aWyLT9kAqlqOBLFLhCh0S9Q"}'::jsonb,
      body := jsonb_build_object(
        'to', NEW.email,
        'subject', 'Welcome to SouvenirPickers - Please Confirm Your Email',
        'type', 'email_confirmation',
        'data', jsonb_build_object(
          'user_name', v_user_name,
          'confirmation_url', v_confirmation_url
        )
      )
    ) INTO v_request_id;
    
    RAISE LOG 'Signup confirmation email queued for %: request_id=%', NEW.email, v_request_id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the signup
    RAISE WARNING 'Failed to send signup confirmation email for %: %', NEW.email, SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger on auth.users for signup confirmations
CREATE TRIGGER trigger_send_signup_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_signup_confirmation_email();

COMMENT ON FUNCTION send_signup_confirmation_email() IS 
  'Sends professional HTML confirmation email when new user signs up using pg_net HTTP module';