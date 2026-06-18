/*
  # Add Custom Signup Confirmation Email Trigger

  1. Purpose
    - Sends custom signup confirmation emails via SMTP edge function
    - Ensures Gmail receives emails properly with all required headers
    - Works alongside Supabase's built-in confirmation system

  2. Changes
    - Creates trigger function to send custom confirmation email
    - Triggers when new user is created in auth.users
    - Calls our custom SMTP edge function with Gmail-compatible settings

  3. Security
    - Uses service role to invoke edge function
    - Only sends email once per user signup
*/

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
  function_response jsonb;
BEGIN
  -- Only proceed for new user signups (not updates)
  IF TG_OP = 'INSERT' AND NEW.email IS NOT NULL AND NEW.confirmation_token IS NOT NULL THEN
    
    -- Get Supabase URL from environment
    supabase_url := current_setting('app.settings.supabase_url', true);
    IF supabase_url IS NULL THEN
      supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    END IF;
    
    -- Build confirmation URL
    confirmation_url := supabase_url || '/auth/v1/verify?token=' || NEW.confirmation_token || '&type=signup&redirect_to=' || supabase_url;
    
    -- Log the attempt
    RAISE LOG 'Sending custom signup confirmation email to: %', NEW.email;
    
    -- Call edge function to send email via custom SMTP
    BEGIN
      SELECT content::jsonb INTO function_response
      FROM http((
        'POST',
        supabase_url || '/functions/v1/send-signup-confirmation',
        ARRAY[
          http_header('Content-Type', 'application/json'),
          http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true))
        ],
        'application/json',
        json_build_object(
          'email', NEW.email,
          'confirmationUrl', confirmation_url
        )::text
      )::http_request);
      
      RAISE LOG 'Custom confirmation email sent successfully to: %', NEW.email;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the signup
      RAISE WARNING 'Failed to send custom confirmation email to %: %', NEW.email, SQLERRM;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Enable http extension if not already enabled
CREATE EXTENSION IF NOT EXISTS http;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created_send_confirmation ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_created_send_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_custom_signup_confirmation();

-- Add comment
COMMENT ON FUNCTION send_custom_signup_confirmation() IS 'Sends custom signup confirmation email via SMTP edge function with Gmail-compatible settings';
