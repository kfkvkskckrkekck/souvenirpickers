/*
  # Fix Email Confirmation Trigger with Better Error Handling

  1. Changes
    - Improve error handling in confirmation email trigger
    - Add better logging
    - Ensure trigger doesn't fail signup if email fails
    
  2. Security
    - Maintains SECURITY DEFINER for auth access
    - Better error messages for debugging
*/

-- Recreate function with improved error handling
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
    BEGIN
      -- Get Supabase URL from environment
      v_supabase_url := current_setting('app.settings.supabase_url', true);
      IF v_supabase_url IS NULL THEN
        v_supabase_url := 'https://atdtxkijznyzrrxsovwz.supabase.co';
      END IF;
      
      -- Extract user name from metadata
      v_user_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
      );
      
      -- Build confirmation URL with proper redirect
      v_confirmation_url := 'https://souvenirpickers.com?token_hash=' || NEW.confirmation_token || '&type=signup';
      
      -- Send confirmation email via edge function
      SELECT INTO v_request_id net.http_post(
        url := v_supabase_url || '/functions/v1/send-email-notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.supabase_anon_key', true)
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
        -- Log detailed error but don't fail the signup
        RAISE WARNING 'Failed to send signup confirmation email for %. Error: % (SQLSTATE: %)', 
          NEW.email, SQLERRM, SQLSTATE;
    END;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_send_signup_confirmation ON auth.users;
CREATE TRIGGER trigger_send_signup_confirmation
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION send_signup_confirmation_email();
