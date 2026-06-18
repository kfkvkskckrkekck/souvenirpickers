/*
  # Fix All app.* Configuration Parameters

  1. Problem
    - Multiple functions try to use current_setting('app.*') which are not configured
    - This causes errors: "unrecognized configuration parameter"
  
  2. Changes
    - Remove email notification calls from send_order_notification_simple (just do in-app notifications)
    - Email notifications will be handled by edge functions via webhooks instead
    - This simplifies the system and removes dependencies on pg_net
  
  3. Notes
    - In-app notifications still work
    - Email can be added back later via proper edge function webhooks
*/

-- Simplify send_order_notification_simple to only handle in-app notifications
-- Remove the email sending part that requires configuration parameters
CREATE OR REPLACE FUNCTION send_order_notification_simple(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_metadata jsonb,
  p_email_subject text DEFAULT NULL,
  p_email_body text DEFAULT NULL
)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insert in-app notification only
  -- Email notifications can be handled separately via edge functions/webhooks
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (p_user_id, p_type, p_title, p_message, p_metadata);
  
  -- Note: Email parameters are accepted but not used
  -- This maintains backward compatibility with existing function calls
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION send_order_notification_simple TO authenticated, service_role;