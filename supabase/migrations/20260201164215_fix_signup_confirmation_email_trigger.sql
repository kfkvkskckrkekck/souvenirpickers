/*
  # Fix Signup Confirmation Email to Use External SMTP

  1. Purpose
    - Configures database to send confirmation emails via external SMTP
    - Sets up proper trigger to call edge function with confirmation URL
    
  2. Changes
    - Updates trigger function to build proper confirmation URL
    - Ensures edge function is called correctly
    
  3. Security
    - Trigger runs with security definer
    - Uses proper auth token from database
*/

-- Drop and recreate the trigger function with correct logic
CREATE OR REPLACE FUNCTION send_custom_signup_confirmation()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  confirmation_url text;
  supabase_url text := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJmcXZ6eGN6bXZmdGVxYmhneXZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0MTAxODIsImV4cCI6MjA3OTk4NjE4Mn0.2kgZ_VfgN42cs3B-40snDRgThCOVNIJ0BGQ_gdhbzy0';
  function_response jsonb;
BEGIN
  -- Only proceed for new user signups with confirmation token
  IF TG_OP = 'INSERT' AND NEW.email IS NOT NULL AND NEW.confirmation_token IS NOT NULL THEN
    
    -- Build confirmation URL that will verify the user
    confirmation_url := supabase_url || '/auth/v1/verify?token=' || NEW.confirmation_token || '&type=signup&redirect_to=https://souvenirpickers.com';
    
    -- Log the attempt
    RAISE LOG 'Sending custom signup confirmation email to: % via edge function with external SMTP', NEW.email;
    
    -- Call edge function to send email via external SMTP
    BEGIN
      SELECT content::jsonb INTO function_response
      FROM http((
        'POST',
        supabase_url || '/functions/v1/send-signup-confirmation',
        ARRAY[
          http_header('Content-Type', 'application/json'),
          http_header('Authorization', 'Bearer ' || anon_key)
        ],
        'application/json',
        json_build_object(
          'email', NEW.email,
          'confirmationUrl', confirmation_url
        )::text
      )::http_request);
      
      RAISE LOG 'Custom confirmation email sent successfully via external SMTP to: %', NEW.email;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the signup
      RAISE WARNING 'Failed to send custom confirmation email to %: %', NEW.email, SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created_send_confirmation ON auth.users;

CREATE TRIGGER on_auth_user_created_send_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_custom_signup_confirmation();

COMMENT ON FUNCTION send_custom_signup_confirmation() IS 'Sends custom signup confirmation email via edge function with external SMTP (Bluehost)';
