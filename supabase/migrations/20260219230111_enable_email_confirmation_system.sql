/*
  # Enable Professional Email Confirmation System

  1. Changes
    - Create trigger to send confirmation email on user signup
    - Sends professional HTML email with confirmation link
    - Users must confirm email before they can log in
    
  2. Security
    - Function runs as SECURITY DEFINER
    - Only triggers on new user creation in auth.users
    - Uses pg_net for async email delivery
    
  3. Email Template
    - Professional welcome message
    - Clear call-to-action button
    - 24-hour expiry notice
    - Fallback plain text link
*/

-- Create function to send signup confirmation email
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
    
    -- Get Supabase URL from environment
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    IF v_supabase_url IS NULL THEN
      v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
    END IF;
    
    -- Extract user name from metadata
    v_user_name := COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    );
    
    -- Build confirmation URL
    v_confirmation_url := v_supabase_url || '/auth/v1/verify?token=' || NEW.confirmation_token || '&type=signup&redirect_to=' || v_supabase_url;
    
    -- Send confirmation email via edge function
    SELECT INTO v_request_id net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
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
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;
CREATE TRIGGER trigger_send_signup_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_signup_confirmation_email();

-- Note: Supabase auth configuration must have "Enable email confirmations" turned ON
-- This is done in the Supabase Dashboard under Authentication > Settings > Email Auth
