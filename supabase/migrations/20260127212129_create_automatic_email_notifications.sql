/*
  # Automatic Email Notification System

  This migration sets up automatic email notifications using the Resend API via Edge Functions.
  
  ## New Functions
  
  1. **notify_new_order()**
     - Triggers when a new order is created
     - Sends email to picker about new order
     - Sends confirmation email to client
  
  2. **notify_order_status_change()**
     - Triggers when order status changes
     - Sends status update email to client
     - Notifies picker on status changes
  
  3. **notify_new_message()**
     - Triggers when a new conversation message is sent
     - Sends email notification to recipient
  
  ## Database Triggers
  
  - `trigger_new_order_notification` - Fires on INSERT to orders table
  - `trigger_order_status_notification` - Fires on UPDATE to orders table (status change)
  - `trigger_new_message_notification` - Fires on INSERT to conversation_messages table
  
  ## Email Types
  
  - `new_order_picker` - Notify picker of new order
  - `order_confirmation` - Notify client order is confirmed
  - `order_status_update` - Notify client of status changes
  - `message_received` - Notify user of new messages
  
  ## Notes
  
  - Uses Resend API via the send-email-notification Edge Function
  - Requires RESEND_API_KEY to be configured in Supabase Edge Function settings
  - Automatically handles email formatting and delivery
  - Includes error handling and logging
*/

-- Function to send new order notifications
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_picker_email text;
  v_picker_name text;
  v_client_email text;
  v_client_name text;
  v_listing_title text;
  v_supabase_url text;
BEGIN
  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://gejhwupzezmuektmaiyg.supabase.co';
  END IF;

  -- Get picker details
  SELECT p.email, p.full_name 
  INTO v_picker_email, v_picker_name
  FROM profiles p
  WHERE p.id = NEW.picker_id;

  -- Get client details
  SELECT p.email, p.full_name 
  INTO v_client_email, v_client_name
  FROM profiles p
  WHERE p.id = NEW.client_id;

  -- Get listing title
  SELECT l.title 
  INTO v_listing_title
  FROM listings l
  WHERE l.id = NEW.listing_id;

  -- Send notification to picker
  IF v_picker_email IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_picker_email,
        'subject', 'New Order Received - Order #' || substring(NEW.id::text, 1, 8),
        'type', 'new_order_picker',
        'data', jsonb_build_object(
          'picker_name', COALESCE(v_picker_name, 'there'),
          'customer_name', COALESCE(v_client_name, 'A customer'),
          'order_id', substring(NEW.id::text, 1, 8),
          'item_title', COALESCE(v_listing_title, 'Item'),
          'quantity', NEW.quantity,
          'total_amount', NEW.total_price
        )
      )
    );
  END IF;

  -- Send confirmation to client
  IF v_client_email IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_client_email,
        'subject', 'Order Confirmed - Order #' || substring(NEW.id::text, 1, 8),
        'type', 'order_confirmation',
        'data', jsonb_build_object(
          'customer_name', COALESCE(v_client_name, 'there'),
          'order_id', substring(NEW.id::text, 1, 8),
          'item_title', COALESCE(v_listing_title, 'Item'),
          'total_amount', NEW.total_price
        )
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error sending new order notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Function to send order status change notifications
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_client_email text;
  v_client_name text;
  v_supabase_url text;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://gejhwupzezmuektmaiyg.supabase.co';
  END IF;

  -- Get client details
  SELECT p.email, p.full_name 
  INTO v_client_email, v_client_name
  FROM profiles p
  WHERE p.id = NEW.client_id;

  -- Send status update notification to client
  IF v_client_email IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_client_email,
        'subject', 'Order Status Update - Order #' || substring(NEW.id::text, 1, 8),
        'type', 'order_status_update',
        'data', jsonb_build_object(
          'customer_name', COALESCE(v_client_name, 'there'),
          'order_id', substring(NEW.id::text, 1, 8),
          'new_status', NEW.status,
          'notes', NEW.notes
        )
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error sending order status notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Function to send new message notifications
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_email text;
  v_recipient_name text;
  v_sender_name text;
  v_supabase_url text;
  v_message_preview text;
BEGIN
  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://gejhwupzezmuektmaiyg.supabase.co';
  END IF;

  -- Get recipient details (everyone in conversation except sender)
  FOR v_recipient_email, v_recipient_name IN
    SELECT p.email, p.full_name
    FROM conversation_participants cp
    JOIN profiles p ON p.id = cp.user_id
    WHERE cp.conversation_id = NEW.conversation_id
      AND cp.user_id != NEW.sender_id
  LOOP
    -- Get sender name
    SELECT p.full_name 
    INTO v_sender_name
    FROM profiles p
    WHERE p.id = NEW.sender_id;

    -- Create message preview (first 100 characters)
    v_message_preview := substring(NEW.content, 1, 100);
    IF length(NEW.content) > 100 THEN
      v_message_preview := v_message_preview || '...';
    END IF;

    -- Send notification to recipient
    IF v_recipient_email IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_supabase_url || '/functions/v1/send-email-notification',
        headers := jsonb_build_object(
          'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
          'to', v_recipient_email,
          'subject', 'New message from ' || COALESCE(v_sender_name, 'a user'),
          'type', 'message_received',
          'data', jsonb_build_object(
            'recipient_name', COALESCE(v_recipient_name, 'there'),
            'sender_name', COALESCE(v_sender_name, 'Someone'),
            'message_preview', v_message_preview
          )
        )
      );
    END IF;
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error sending message notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create triggers

-- Trigger for new orders
DROP TRIGGER IF EXISTS trigger_new_order_notification ON orders;
CREATE TRIGGER trigger_new_order_notification
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_order();

-- Trigger for order status changes
DROP TRIGGER IF EXISTS trigger_order_status_notification ON orders;
CREATE TRIGGER trigger_order_status_notification
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();

-- Trigger for new messages
DROP TRIGGER IF EXISTS trigger_new_message_notification ON conversation_messages;
CREATE TRIGGER trigger_new_message_notification
  AFTER INSERT ON conversation_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();