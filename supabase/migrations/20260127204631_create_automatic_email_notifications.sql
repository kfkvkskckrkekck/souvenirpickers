/*
  # Automatic Email Notification System

  Creates database triggers and functions to automatically send emails when important events occur.

  1. New Functions
    - `send_email_via_edge_function` - Helper function to call the email edge function
    - `handle_new_order_email` - Sends order confirmation emails
    - `handle_order_status_change_email` - Sends shipping/delivery notifications
    - `handle_new_conversation_message_email` - Sends new message notifications

  2. New Triggers
    - `trigger_send_order_confirmation` - Fires when new order is created
    - `trigger_send_order_status_update` - Fires when order status changes
    - `trigger_send_conversation_message_notification` - Fires when new message is sent

  3. Security
    - All functions run with security definer (elevated privileges)
    - Proper error handling to prevent email failures from blocking transactions
*/

-- Helper function to call the send-email-notification edge function
CREATE OR REPLACE FUNCTION send_email_via_edge_function(
  p_to text,
  p_subject text,
  p_type text,
  p_data jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url text;
  v_response text;
BEGIN
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';

  -- Call the edge function using http extension
  BEGIN
    SELECT content::text INTO v_response
    FROM extensions.http((
      'POST',
      v_supabase_url || '/functions/v1/send-email-notification',
      ARRAY[
        extensions.http_header('Content-Type', 'application/json'),
        extensions.http_header('Authorization', 'Bearer ' || current_setting('request.jwt.claims', true)::json->>'sub')
      ],
      'application/json',
      json_build_object(
        'to', p_to,
        'subject', p_subject,
        'type', p_type,
        'data', p_data
      )::text
    )::extensions.http_request);

    RAISE NOTICE 'Email sent successfully to %', p_to;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to send email to %: %', p_to, SQLERRM;
  END;
END;
$$;

-- Function to send order confirmation email
CREATE OR REPLACE FUNCTION handle_new_order_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_email text;
  v_customer_name text;
  v_listing_title text;
  v_total_amount numeric;
BEGIN
  SELECT au.email, p.full_name
  INTO v_customer_email, v_customer_name
  FROM profiles p
  JOIN auth.users au ON au.id = p.id
  WHERE p.id = NEW.client_id;

  SELECT title
  INTO v_listing_title
  FROM listings
  WHERE id = NEW.listing_id;

  v_total_amount := NEW.item_price + COALESCE(NEW.shipping_cost, 0);

  PERFORM send_email_via_edge_function(
    v_customer_email,
    'Order Confirmation - SouvenirPickers',
    'order_confirmation',
    jsonb_build_object(
      'customer_name', v_customer_name,
      'order_id', NEW.id,
      'item_title', v_listing_title,
      'total_amount', v_total_amount
    )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending order confirmation email: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Function to send order status change email
CREATE OR REPLACE FUNCTION handle_order_status_change_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_email text;
  v_customer_name text;
  v_tracking_number text;
BEGIN
  IF NEW.status = 'shipped' AND OLD.status != 'shipped' THEN
    SELECT au.email, p.full_name
    INTO v_customer_email, v_customer_name
    FROM profiles p
    JOIN auth.users au ON au.id = p.id
    WHERE p.id = NEW.client_id;

    SELECT tracking_number
    INTO v_tracking_number
    FROM shipment_tracking
    WHERE order_id = NEW.id
    ORDER BY created_at DESC
    LIMIT 1;

    PERFORM send_email_via_edge_function(
      v_customer_email,
      'Your Order Has Shipped - SouvenirPickers',
      'order_shipped',
      jsonb_build_object(
        'customer_name', v_customer_name,
        'order_id', NEW.id,
        'tracking_number', COALESCE(v_tracking_number, 'Not available'),
        'estimated_delivery', (CURRENT_DATE + INTERVAL '7 days')::text
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending order status email: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Function to send new conversation message notification email
CREATE OR REPLACE FUNCTION handle_new_conversation_message_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient_email text;
  v_recipient_name text;
  v_sender_name text;
  v_other_user_id uuid;
  v_notifications_enabled boolean;
BEGIN
  SELECT
    CASE
      WHEN c.user1_id = NEW.sender_id THEN c.user2_id
      ELSE c.user1_id
    END
  INTO v_other_user_id
  FROM conversations c
  WHERE c.id = NEW.conversation_id;

  SELECT 
    COALESCE(np.email_enabled, true) AND COALESCE(np.messages, true)
  INTO v_notifications_enabled
  FROM notification_preferences np
  WHERE np.user_id = v_other_user_id;

  IF v_notifications_enabled IS NULL THEN
    v_notifications_enabled := true;
  END IF;

  IF v_notifications_enabled THEN
    SELECT au.email, p.full_name
    INTO v_recipient_email, v_recipient_name
    FROM profiles p
    JOIN auth.users au ON au.id = p.id
    WHERE p.id = v_other_user_id;

    SELECT full_name
    INTO v_sender_name
    FROM profiles
    WHERE id = NEW.sender_id;

    PERFORM send_email_via_edge_function(
      v_recipient_email,
      'New Message from ' || v_sender_name || ' - SouvenirPickers',
      'message_received',
      jsonb_build_object(
        'recipient_name', v_recipient_name,
        'sender_name', v_sender_name,
        'message_preview', LEFT(NEW.content, 100)
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error sending message notification email: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_send_order_confirmation ON orders;
DROP TRIGGER IF EXISTS trigger_send_order_status_update ON orders;
DROP TRIGGER IF EXISTS trigger_send_conversation_message_notification ON conversation_messages;

-- Create trigger for order confirmation emails
CREATE TRIGGER trigger_send_order_confirmation
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION handle_new_order_email();

-- Create trigger for order status change emails
CREATE TRIGGER trigger_send_order_status_update
AFTER UPDATE OF status ON orders
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION handle_order_status_change_email();

-- Create trigger for new conversation message notifications
CREATE TRIGGER trigger_send_conversation_message_notification
AFTER INSERT ON conversation_messages
FOR EACH ROW
EXECUTE FUNCTION handle_new_conversation_message_email();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation_id ON conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_sender_id ON conversation_messages(sender_id);
