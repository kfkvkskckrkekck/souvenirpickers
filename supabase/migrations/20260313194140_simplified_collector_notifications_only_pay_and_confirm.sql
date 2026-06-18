/*
  # Simplified Collector Notifications - Only Pay & Confirm Delivery

  This migration simplifies notifications for collectors:
  - Collectors only get notified when they need to TAKE ACTION
  - Two actions only: Pay and Confirm Delivery
  - Pickers get all the operational notifications

  ## Collector Notifications (Action Required)
  1. Quote Provided → "Pay Now"
  2. Delivered → "Confirm Delivery"

  ## Picker Notifications (Action Required)
  1. Payment Received → "Ship Item"
  2. Delivery Confirmed → "Payment Released"
*/

-- Drop existing triggers
DROP TRIGGER IF EXISTS trigger_auto_transition_on_quote ON orders;
DROP TRIGGER IF EXISTS trigger_auto_transition_on_payment ON orders;
DROP TRIGGER IF EXISTS trigger_notify_simplified_status ON orders;

-- Drop old function
DROP FUNCTION IF EXISTS send_order_notification(uuid, text, text, text, jsonb, text, text);
DROP FUNCTION IF EXISTS notify_quote_provided();
DROP FUNCTION IF EXISTS notify_payment_success();
DROP FUNCTION IF EXISTS notify_order_status_changes();

-- New simplified notification function
CREATE OR REPLACE FUNCTION send_order_notification_simple(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_metadata jsonb,
  p_email_subject text,
  p_email_body text
)
RETURNS void AS $$
BEGIN
  -- Insert in-app notification
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (p_user_id, p_type, p_title, p_message, p_metadata);

  -- Send email notification via edge function
  PERFORM net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/send-email-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key')
    ),
    body := jsonb_build_object(
      'to_user_id', p_user_id,
      'subject', p_email_subject,
      'body', p_email_body,
      'order_id', p_metadata->>'order_id'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. COLLECTOR: Quote Provided → Pay Now
CREATE OR REPLACE FUNCTION notify_collector_pay_now()
RETURNS TRIGGER AS $$
DECLARE
  v_item_title text;
BEGIN
  IF NEW.transportation_cost IS NOT NULL
     AND NEW.shipping_quote_status = 'quote_provided'
     AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_provided')
     AND NEW.status = 'awaiting_quote' THEN

    NEW.status := 'quote_provided';

    SELECT title INTO v_item_title FROM listings WHERE id = NEW.listing_id;

    -- COLLECTOR ACTION REQUIRED: Pay Now
    PERFORM send_order_notification_simple(
      NEW.client_id,
      'order',
      'Ready to Pay - Quote Received',
      'Shipping quote ready: $' || NEW.transportation_cost::text || '. Total: $' || (NEW.item_price + NEW.transportation_cost)::text,
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Pay Now'
      ),
      'Ready to Pay - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      'Your shipping quote is ready!' || E'\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Item Price: $' || NEW.item_price::text || E'\n' ||
      'Shipping: $' || NEW.transportation_cost::text || E'\n' ||
      'TOTAL: $' || (NEW.item_price + NEW.transportation_cost)::text || E'\n\n' ||
      '→ ACTION REQUIRED: Pay now to complete your order' || E'\n\n' ||
      'Pay now: ' || current_setting('app.base_url') || '/orders'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_collector_pay
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.shipping_quote_status IS DISTINCT FROM OLD.shipping_quote_status)
  EXECUTE FUNCTION notify_collector_pay_now();

-- 2. PICKER: Payment Received → Ship Item
CREATE OR REPLACE FUNCTION notify_picker_ship_item()
RETURNS TRIGGER AS $$
DECLARE
  v_item_title text;
  v_delivery_address text;
BEGIN
  IF NEW.payment_status = 'paid'
     AND (OLD.payment_status IS NULL OR OLD.payment_status != 'paid')
     AND NEW.status IN ('quote_provided', 'payment_pending', 'awaiting_quote') THEN

    NEW.status := 'paid';

    SELECT title INTO v_item_title FROM listings WHERE id = NEW.listing_id;

    v_delivery_address := COALESCE(NEW.delivery_street, '') || ', ' ||
                         COALESCE(NEW.delivery_city, '') || ', ' ||
                         COALESCE(NEW.delivery_postal_code, '') || ', ' ||
                         COALESCE(NEW.delivery_country, '');

    -- PICKER ACTION REQUIRED: Ship Item
    PERFORM send_order_notification_simple(
      NEW.picker_id,
      'order',
      'Payment Received - Ship Item',
      'Payment received: $' || NEW.total_amount::text || '. Prepare and ship the item.',
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Ship Item'
      ),
      'Payment Received - Ship Order #' || NEW.id::text,
      'Payment received!' || E'\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Order') || E'\n' ||
      'Amount: $' || NEW.total_amount::text || E'\n' ||
      'Ship to: ' || v_delivery_address || E'\n\n' ||
      '→ ACTION REQUIRED:' || E'\n' ||
      '1. Prepare the item' || E'\n' ||
      '2. Ship it' || E'\n' ||
      '3. Mark as shipped' || E'\n\n' ||
      'Manage order: ' || current_setting('app.base_url') || '/orders'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_picker_ship
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.payment_status IS DISTINCT FROM OLD.payment_status)
  EXECUTE FUNCTION notify_picker_ship_item();

-- 3. Status Changes: Only Action-Required Notifications
CREATE OR REPLACE FUNCTION notify_action_required_only()
RETURNS TRIGGER AS $$
DECLARE
  v_item_title text;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_item_title FROM listings WHERE id = NEW.listing_id;

  -- COLLECTOR ACTION REQUIRED: Confirm Delivery
  IF NEW.status = 'delivered' AND OLD.status = 'shipped' THEN
    PERFORM send_order_notification_simple(
      NEW.client_id,
      'order',
      'Delivered - Confirm Receipt',
      'Your order arrived! Confirm delivery to release payment to your picker.',
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Confirm Delivery'
      ),
      'Confirm Delivery - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      'Your order has been delivered!' || E'\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n\n' ||
      '→ ACTION REQUIRED: Confirm delivery to release payment' || E'\n\n' ||
      'If there are issues, report them before confirming.' || E'\n\n' ||
      'Confirm now: ' || current_setting('app.base_url') || '/orders'
    );

  -- PICKER: Payment Released (no action required, just FYI)
  ELSIF NEW.status = 'completed' AND OLD.status = 'delivered' THEN
    PERFORM send_order_notification_simple(
      NEW.picker_id,
      'order',
      'Completed - Payment Released',
      'Delivery confirmed! Payment of $' || NEW.total_amount::text || ' released to your account.',
      jsonb_build_object(
        'order_id', NEW.id,
        'payout_amount', NEW.total_amount,
        'action_url', '/earnings'
      ),
      'Payment Released - Order #' || NEW.id::text,
      'Order completed!' || E'\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Order') || E'\n' ||
      'Payment: $' || NEW.total_amount::text || E'\n\n' ||
      'Payment will be transferred to your bank account.' || E'\n\n' ||
      'View earnings: ' || current_setting('app.base_url') || '/earnings'
    );

  -- Cancellation
  ELSIF NEW.status = 'cancelled' THEN
    DECLARE
      v_notified_user_id uuid;
    BEGIN
      v_notified_user_id := CASE WHEN NEW.client_id = auth.uid() THEN NEW.picker_id ELSE NEW.client_id END;

      PERFORM send_order_notification_simple(
        v_notified_user_id,
        'order',
        'Order Cancelled',
        'Order cancelled: ' || COALESCE(v_item_title, 'item'),
        jsonb_build_object('order_id', NEW.id),
        'Order Cancelled - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
        'This order has been cancelled.' || E'\n\n' ||
        'Item: ' || COALESCE(v_item_title, 'Order') || E'\n\n' ||
        'Contact support with questions.'
      );
    END;

  -- Refund
  ELSIF NEW.status = 'refunded' THEN
    PERFORM send_order_notification_simple(
      NEW.client_id,
      'payment',
      'Refund Processed',
      'Refund of $' || NEW.total_amount::text || ' processed. Appears in 5-10 business days.',
      jsonb_build_object('order_id', NEW.id, 'refund_amount', NEW.total_amount),
      'Refund Processed - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      'Your refund has been processed.' || E'\n\n' ||
      'Amount: $' || NEW.total_amount::text || E'\n' ||
      'Timeline: 5-10 business days' || E'\n\n' ||
      'Contact support with questions.'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_action_required
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION notify_action_required_only();

COMMENT ON FUNCTION send_order_notification_simple IS 'Simplified notifications - only when user action is required';
COMMENT ON FUNCTION notify_collector_pay_now IS 'Collector ACTION: Pay for order when quote is ready';
COMMENT ON FUNCTION notify_picker_ship_item IS 'Picker ACTION: Ship item when payment received';
COMMENT ON FUNCTION notify_action_required_only IS 'Notifications only for actions: confirm delivery, payment released, cancellations';
