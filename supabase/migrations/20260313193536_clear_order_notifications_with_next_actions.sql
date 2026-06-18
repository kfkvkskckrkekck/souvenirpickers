/*
  # Clear Order Notifications with Next Actions

  This migration creates a comprehensive notification system for the simplified order flow.
  Both in-app notifications and email notifications are sent with clear next actions for users.

  ## Notification Strategy

  Every status change triggers:
  1. In-app notification to the relevant party
  2. Email notification with clear call-to-action
  3. Clear description of what happened and what to do next

  ## Email Templates

  Each notification includes:
  - Clear subject line
  - What happened (status change)
  - What you need to do next
  - Direct link to take action
  - Order details for context
*/

-- Drop existing triggers to recreate them
DROP TRIGGER IF EXISTS trigger_auto_transition_on_quote ON orders;
DROP TRIGGER IF EXISTS trigger_auto_transition_on_payment ON orders;
DROP TRIGGER IF EXISTS trigger_notify_simplified_status ON orders;

-- Function: Send both in-app and email notifications
CREATE OR REPLACE FUNCTION send_order_notification(
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

-- Trigger 1: When picker provides shipping quote
CREATE OR REPLACE FUNCTION notify_quote_provided()
RETURNS TRIGGER AS $$
DECLARE
  v_collector_email text;
  v_item_title text;
BEGIN
  IF NEW.transportation_cost IS NOT NULL
     AND NEW.shipping_quote_status = 'quote_provided'
     AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_provided')
     AND NEW.status = 'awaiting_quote' THEN

    NEW.status := 'quote_provided';

    -- Get collector email and item details
    SELECT p.email INTO v_collector_email
    FROM auth.users p
    WHERE p.id = NEW.client_id;

    SELECT title INTO v_item_title
    FROM listings
    WHERE id = NEW.listing_id;

    -- Send notification to collector
    PERFORM send_order_notification(
      NEW.client_id,
      'order',
      'Shipping Quote Ready!',
      'Your picker has provided a shipping quote of $' || NEW.transportation_cost::text || '. Review and proceed to payment to complete your order.',
      jsonb_build_object(
        'order_id', NEW.id,
        'shipping_cost', NEW.transportation_cost,
        'action_url', '/orders',
        'action_text', 'Review Quote & Pay Now'
      ),
      'Your Shipping Quote is Ready - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'Great news! Your picker has provided a shipping quote for your order.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Item Price: $' || NEW.item_price::text || E'\n' ||
      'Shipping Cost: $' || NEW.transportation_cost::text || E'\n' ||
      'Total: $' || (NEW.item_price + NEW.transportation_cost)::text || E'\n\n' ||
      'NEXT STEP: Review the quote and proceed to payment.\n\n' ||
      'Click here to review and pay: ' || current_setting('app.base_url') || '/orders'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_transition_on_quote
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.shipping_quote_status IS DISTINCT FROM OLD.shipping_quote_status)
  EXECUTE FUNCTION notify_quote_provided();

-- Trigger 2: When payment is successful
CREATE OR REPLACE FUNCTION notify_payment_success()
RETURNS TRIGGER AS $$
DECLARE
  v_picker_email text;
  v_item_title text;
  v_delivery_address text;
BEGIN
  IF NEW.payment_status = 'paid'
     AND (OLD.payment_status IS NULL OR OLD.payment_status != 'paid')
     AND NEW.status IN ('quote_provided', 'payment_pending', 'awaiting_quote') THEN

    NEW.status := 'paid';

    -- Get picker email and item details
    SELECT p.email INTO v_picker_email
    FROM auth.users p
    WHERE p.id = NEW.picker_id;

    SELECT title INTO v_item_title
    FROM listings
    WHERE id = NEW.listing_id;

    -- Build delivery address
    v_delivery_address := COALESCE(NEW.delivery_street, '') || ', ' ||
                         COALESCE(NEW.delivery_city, '') || ', ' ||
                         COALESCE(NEW.delivery_postal_code, '') || ', ' ||
                         COALESCE(NEW.delivery_country, '');

    -- Send notification to picker
    PERFORM send_order_notification(
      NEW.picker_id,
      'order',
      'Payment Received - Time to Ship!',
      'Payment of $' || NEW.total_amount::text || ' has been received. Prepare and ship the item to the collector.',
      jsonb_build_object(
        'order_id', NEW.id,
        'total_amount', NEW.total_amount,
        'action_url', '/orders',
        'action_text', 'Prepare & Ship Item'
      ),
      'Payment Received - Ship Order #' || NEW.id::text,
      E'Excellent! Payment has been received for your order.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Order') || E'\n' ||
      'Amount: $' || NEW.total_amount::text || E'\n' ||
      'Delivery Address: ' || v_delivery_address || E'\n\n' ||
      'NEXT STEPS:\n' ||
      '1. Prepare the item\n' ||
      '2. Upload a pickup video (recommended)\n' ||
      '3. Ship the item\n' ||
      '4. Mark as shipped in your orders\n\n' ||
      'Manage this order: ' || current_setting('app.base_url') || '/orders'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_transition_on_payment
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.payment_status IS DISTINCT FROM OLD.payment_status)
  EXECUTE FUNCTION notify_payment_success();

-- Trigger 3: Notify on all status changes
CREATE OR REPLACE FUNCTION notify_order_status_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_collector_email text;
  v_picker_email text;
  v_item_title text;
  v_tracking_info text;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Get emails and item details
  SELECT p.email INTO v_collector_email FROM auth.users p WHERE p.id = NEW.client_id;
  SELECT p.email INTO v_picker_email FROM auth.users p WHERE p.id = NEW.picker_id;
  SELECT title INTO v_item_title FROM listings WHERE id = NEW.listing_id;

  -- Order Shipped: Notify collector
  IF NEW.status = 'shipped' AND OLD.status = 'paid' THEN
    v_tracking_info := COALESCE(NEW.tracking_number, 'No tracking number provided');

    PERFORM send_order_notification(
      NEW.client_id,
      'order',
      'Your Order Has Been Shipped!',
      'Your item is on its way! ' || CASE WHEN NEW.tracking_number IS NOT NULL THEN 'Track your order with: ' || NEW.tracking_number ELSE 'Your picker will update you with tracking information.' END,
      jsonb_build_object(
        'order_id', NEW.id,
        'tracking_number', NEW.tracking_number,
        'action_url', '/orders',
        'action_text', 'Track Your Order'
      ),
      'Your Order is On Its Way! - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'Good news! Your order has been shipped.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Tracking: ' || v_tracking_info || E'\n\n' ||
      'NEXT STEP: Watch for delivery and confirm receipt when it arrives.\n\n' ||
      'Track your order: ' || current_setting('app.base_url') || '/orders'
    );

  -- Item Delivered: Notify collector to confirm
  ELSIF NEW.status = 'delivered' AND OLD.status = 'shipped' THEN
    PERFORM send_order_notification(
      NEW.client_id,
      'order',
      'Order Delivered - Please Confirm',
      'Your order has been delivered! Please confirm receipt so we can release payment to your picker.',
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Confirm Delivery'
      ),
      'Please Confirm Delivery - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'Your order has been delivered!\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n\n' ||
      'IMPORTANT: Please confirm delivery to release payment to your picker.\n\n' ||
      'If there are any issues, please report them before confirming.\n\n' ||
      'Confirm delivery now: ' || current_setting('app.base_url') || '/orders'
    );

  -- Delivery Confirmed: Notify picker (payment released)
  ELSIF NEW.status = 'completed' AND OLD.status = 'delivered' THEN
    PERFORM send_order_notification(
      NEW.picker_id,
      'order',
      'Delivery Confirmed - Payment Released!',
      'The collector has confirmed delivery. Your payment of $' || NEW.total_amount::text || ' has been released and will be transferred to your account.',
      jsonb_build_object(
        'order_id', NEW.id,
        'payout_amount', NEW.total_amount,
        'action_url', '/earnings',
        'action_text', 'View Your Earnings'
      ),
      'Payment Released - Order Complete!',
      E'Congratulations! Your order has been completed.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Order') || E'\n' ||
      'Payment Amount: $' || NEW.total_amount::text || E'\n\n' ||
      'The payment has been released and will be transferred to your bank account according to your payout schedule.\n\n' ||
      'NEXT STEP: Encourage the collector to leave a review!\n\n' ||
      'View your earnings: ' || current_setting('app.base_url') || '/earnings'
    );

  -- Order Cancelled
  ELSIF NEW.status = 'cancelled' THEN
    -- Notify the other party
    DECLARE
      v_notified_user_id uuid;
      v_notified_email text;
    BEGIN
      v_notified_user_id := CASE WHEN NEW.client_id = auth.uid() THEN NEW.picker_id ELSE NEW.client_id END;
      v_notified_email := CASE WHEN v_notified_user_id = NEW.picker_id THEN v_picker_email ELSE v_collector_email END;

      PERFORM send_order_notification(
        v_notified_user_id,
        'order',
        'Order Cancelled',
        'Order for "' || COALESCE(v_item_title, 'item') || '" has been cancelled.',
        jsonb_build_object(
          'order_id', NEW.id,
          'action_url', '/orders'
        ),
        'Order Cancelled - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
        E'This order has been cancelled.\n\n' ||
        'Item: ' || COALESCE(v_item_title, 'Order') || E'\n\n' ||
        'If you have questions, please contact support.\n\n' ||
        'View your orders: ' || current_setting('app.base_url') || '/orders'
      );
    END;

  -- Order Refunded
  ELSIF NEW.status = 'refunded' THEN
    PERFORM send_order_notification(
      NEW.client_id,
      'payment',
      'Refund Processed',
      'Your refund of $' || NEW.total_amount::text || ' has been processed and will appear in your account within 5-10 business days.',
      jsonb_build_object(
        'order_id', NEW.id,
        'refund_amount', NEW.total_amount
      ),
      'Refund Processed - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'Your refund has been processed.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Order') || E'\n' ||
      'Refund Amount: $' || NEW.total_amount::text || E'\n\n' ||
      'The refund will appear in your original payment method within 5-10 business days.\n\n' ||
      'If you have questions, please contact support.'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_notify_simplified_status
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION notify_order_status_changes();

-- Add configuration settings for base URL (update this with your actual domain)
DO $$
BEGIN
  -- Set base URL for email links (update this to your actual domain)
  ALTER DATABASE postgres SET app.base_url = 'https://souvenirpickers.com';
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

COMMENT ON FUNCTION send_order_notification IS 'Sends both in-app and email notifications with clear next actions';
COMMENT ON FUNCTION notify_quote_provided IS 'Notifies collector when shipping quote is provided';
COMMENT ON FUNCTION notify_payment_success IS 'Notifies picker when payment is received';
COMMENT ON FUNCTION notify_order_status_changes IS 'Notifies users of all order status changes with clear next actions';
