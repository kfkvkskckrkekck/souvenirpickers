/*
  # Re-Enable Signup Confirmation Email Trigger

  1. Purpose
    - Re-enables custom signup confirmation emails via SMTP edge function
    - Uses external SMTP (already configured in edge function secrets)
    - Ensures all signup confirmation emails use your Bluehost SMTP

  2. Changes
    - Creates trigger function to send confirmation email via edge function
    - Triggers when new user signs up
    - Calls send-signup-confirmation edge function which uses your external SMTP

  3. Security
    - Uses service role to invoke edge function
    - Only sends email once per user signup
*/

-- Enable http extension if not already enabled
CREATE EXTENSION IF NOT EXISTS http;

-- Function to send custom confirmation email via edge function
CREATE OR REPLACE FUNCTION send_custom_signup_confirmation()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  confirmation_url text;
  supabase_url text;
  service_role_key text;
  function_response jsonb;
BEGIN
  -- Only proceed for new user signups (not updates)
  IF TG_OP = 'INSERT' AND NEW.email IS NOT NULL AND NEW.confirmation_token IS NOT NULL THEN
    
    -- Get Supabase URL
    supabase_url := current_setting('app.settings.supabase_url', true);
    IF supabase_url IS NULL THEN
      supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    END IF;
    
    -- Get service role key
    service_role_key := current_setting('app.settings.service_role_key', true);
    
    -- Build confirmation URL
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
          http_header('Authorization', 'Bearer ' || service_role_key)
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created_send_confirmation ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_created_send_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_custom_signup_confirmation();

-- Add comment
COMMENT ON FUNCTION send_custom_signup_confirmation() IS 'Sends custom signup confirmation email via edge function with external SMTP (Bluehost)';
