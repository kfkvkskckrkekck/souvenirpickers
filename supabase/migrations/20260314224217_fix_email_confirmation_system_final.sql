/*
  # Re-Enable Email Confirmation System
  
  1. Problem
    - Email confirmation was disabled in dashboard AND in migration 20260225
    - Users are being auto-confirmed without receiving confirmation emails
    - The trigger from 20260314 can't work because no confirmation_token is generated
    
  2. Solution
    - Keep the trigger that sends confirmation emails via custom SMTP
    - Document that email confirmation MUST be enabled in Supabase Dashboard
    - Add check to ensure confirmation tokens are being generated
    
  3. Changes
    - Update trigger to handle both cases (with and without confirmation)
    - Log warnings if confirmation is disabled
    
  4. CRITICAL: Manual Step Required
    - Go to Supabase Dashboard > Authentication > Providers > Email
    - Turn ON "Confirm email" toggle
    - Save changes
    - SMTP settings must already be configured (they are)
*/

-- Verify the trigger exists and is correct
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
  -- Check if email confirmation is enabled
  IF NEW.confirmation_token IS NULL OR NEW.confirmation_token = '' THEN
    RAISE WARNING 'Email confirmation is DISABLED in Supabase Dashboard. User % was auto-confirmed. Please enable "Confirm email" in Authentication settings.', NEW.email;
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
      
      -- Send confirmation email via edge function
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
      
      RAISE LOG 'Confirmation email queued for %: request_id=%', NEW.email, v_request_id;
      
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Failed to send confirmation email for %: %', NEW.email, SQLERRM;
    END;
  END IF;
  
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
  'Sends email confirmation via custom SMTP. Requires "Confirm email" to be enabled in Supabase Dashboard.';
