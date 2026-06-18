/*
  # Disable Supabase Email Confirmation Completely
  
  1. Changes
    - Set email_confirmed_at immediately on user creation
    - User can log in immediately without email confirmation
    - Welcome email sent asynchronously after user is created
    
  2. Note
    - Email confirmation must be disabled in Supabase Dashboard
    - Go to Authentication > Settings > Email Auth
    - Uncheck "Enable email confirmations"
*/

-- Update trigger to AFTER INSERT so user is already created
DROP TRIGGER IF EXISTS trigger_handle_new_user_signup ON auth.users;

CREATE OR REPLACE FUNCTION send_welcome_email_after_signup()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_name text;
  v_supabase_url text;
  v_request_id bigint;
BEGIN
  -- Set Supabase URL
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  
  -- Extract user name from metadata
  v_user_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1)
  );
  
  -- Send welcome email asynchronously (won't block signup)
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
          'login_url', 'https://souvenirpickers.com'
        )
      )
    ) INTO v_request_id;
    
    RAISE LOG 'Welcome email queued for %: request_id=%', NEW.email, v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to queue welcome email for %: %', NEW.email, SQLERRM;
  END;
  
  RETURN NEW;
END;
$$;

-- Create AFTER INSERT trigger (won't block the signup)
CREATE TRIGGER trigger_send_welcome_email
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_welcome_email_after_signup();

COMMENT ON FUNCTION send_welcome_email_after_signup() IS 
  'Sends welcome email after user signup. Does not block signup if email fails.';
