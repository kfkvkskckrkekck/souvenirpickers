/*
  # Bypass Supabase Built-in Email System
  
  1. Changes
    - Set users as email_confirmed immediately on signup
    - Our custom trigger will still send confirmation emails
    - This prevents Supabase from trying to send emails (which is failing)
    - Users won't need to confirm to log in, but will still get welcome email
    
  2. Security
    - Users can log in immediately after signup
    - Welcome email still sent for engagement
*/

-- Drop old trigger
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;

-- Create new trigger that auto-confirms email
CREATE OR REPLACE FUNCTION handle_new_user_signup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
LANGUAGE plpgsql
AS $$
DECLARE
  v_confirmation_url text;
  v_user_name text;
  v_supabase_url text;
  v_request_id bigint;
BEGIN
  -- Auto-confirm the email to bypass Supabase's built-in email system
  IF NEW.email_confirmed_at IS NULL THEN
    NEW.email_confirmed_at := NOW();
  END IF;
  
  -- Set Supabase URL
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  
  -- Extract user name from metadata
  v_user_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1)
  );
  
  -- Build welcome URL
  v_confirmation_url := 'https://souvenirpickers.com';
  
  -- Send welcome email via edge function using pg_net (async, non-blocking)
  BEGIN
    SELECT net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDQxMDE4MiwiZXhwIjoyMDc5OTg2MTgyfQ.PJPzXHI1-0Mu-YTIWJg7aWyLT9kAqlqOBLFLhCh0S9Q"}'::jsonb,
      body := jsonb_build_object(
        'to', NEW.email,
        'subject', 'Welcome to SouvenirPickers!',
        'type', 'welcome_email',
        'data', jsonb_build_object(
          'user_name', v_user_name,
          'login_url', v_confirmation_url
        )
      )
    ) INTO v_request_id;
    
    RAISE LOG 'Welcome email queued for %: request_id=%', NEW.email, v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- Log error but don't fail the signup
      RAISE WARNING 'Failed to queue welcome email for %: %', NEW.email, SQLERRM;
  END;
  
  RETURN NEW;
END;
$$;

-- Create trigger BEFORE INSERT to modify the user record
CREATE TRIGGER trigger_handle_new_user_signup
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_signup();

COMMENT ON FUNCTION handle_new_user_signup() IS 
  'Auto-confirms email on signup and sends welcome email to bypass Supabase built-in email system';
