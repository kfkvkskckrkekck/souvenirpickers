/*
  # Simplified Order Status Flow - Based on Actual User Actions

  ## The Real Workflow

  1. Picker creates listing → Listing available for browsing
  2. Collector browses & clicks "Buy" → Adds to cart or direct purchase
  3. Collector places order & requests shipping quote → Status: awaiting_quote
  4. Picker provides shipping quote → Status: quote_provided
  5. Collector proceeds to payment → Status: payment_pending
  6. Payment successful → Status: paid
  7. Picker prepares & ships item → Status: shipped
  8. Collector receives item → Status: delivered
  9. Collector confirms delivery → Status: completed (payment released to picker)

  ## Simplified Status System

  Main Statuses:
  - awaiting_quote - Collector placed order, waiting for picker to provide shipping cost
  - quote_provided - Picker provided shipping quote, collector needs to approve & pay
  - payment_pending - Collector approved quote, payment processing
  - paid - Payment successful, picker can prepare item
  - shipped - Picker shipped item to collector
  - delivered - Item delivered (auto or collector confirmation)
  - completed - Collector confirmed receipt, payment released to picker
  - cancelled - Order cancelled by either party
  - refunded - Payment refunded to collector
*/

-- First, remove the old constraint if it exists
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Update all existing orders to new status values BEFORE adding constraint
UPDATE orders
SET status = CASE
  -- Orders waiting for shipping quote (pending/unpaid without quote)
  WHEN status IN ('pending', 'unpaid') AND (shipping_quote_status IS NULL OR shipping_quote_status = 'no_quote_needed' OR shipping_quote_status = 'quote_requested') THEN 'awaiting_quote'

  -- Orders with quote provided, awaiting payment
  WHEN status IN ('pending', 'unpaid') AND shipping_quote_status = 'quote_provided' THEN 'quote_provided'

  -- Processing/accepted/paid orders ready for picker to ship
  WHEN status IN ('paid', 'accepted', 'processing') THEN 'paid'

  -- Shipped orders
  WHEN status = 'shipped' THEN 'shipped'

  -- Delivered orders (not yet confirmed by collector)
  WHEN status = 'delivered' AND goods_confirmed_at IS NULL THEN 'delivered'

  -- Completed orders (collector confirmed)
  WHEN status IN ('delivered', 'received') AND goods_confirmed_at IS NOT NULL THEN 'completed'

  -- Cancelled orders
  WHEN status = 'cancelled' THEN 'cancelled'

  -- Refunded orders
  WHEN status = 'refunded' THEN 'refunded'

  -- Any other status: default to awaiting_quote
  ELSE 'awaiting_quote'
END;

-- NOW add the new constraint with only the valid statuses
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'awaiting_quote',
    'quote_provided',
    'payment_pending',
    'paid',
    'shipped',
    'delivered',
    'completed',
    'cancelled',
    'refunded'
  ));

-- Create function to get user-friendly display status
CREATE OR REPLACE FUNCTION get_order_display_status(
  p_status text,
  p_user_type text
)
RETURNS text AS $$
BEGIN
  IF p_user_type IN ('collector', 'client') THEN
    RETURN CASE p_status
      WHEN 'awaiting_quote' THEN 'Waiting for Shipping Quote'
      WHEN 'quote_provided' THEN 'Review Quote & Pay'
      WHEN 'payment_pending' THEN 'Processing Payment'
      WHEN 'paid' THEN 'Paid - Picker Preparing Item'
      WHEN 'shipped' THEN 'In Transit'
      WHEN 'delivered' THEN 'Delivered - Confirm Receipt'
      WHEN 'completed' THEN 'Order Complete'
      WHEN 'cancelled' THEN 'Cancelled'
      WHEN 'refunded' THEN 'Refunded'
      ELSE p_status
    END;
  ELSIF p_user_type = 'picker' THEN
    RETURN CASE p_status
      WHEN 'awaiting_quote' THEN 'Provide Shipping Quote'
      WHEN 'quote_provided' THEN 'Quote Sent - Awaiting Payment'
      WHEN 'payment_pending' THEN 'Payment Processing'
      WHEN 'paid' THEN 'Paid - Prepare & Ship Item'
      WHEN 'shipped' THEN 'Shipped - In Transit'
      WHEN 'delivered' THEN 'Delivered'
      WHEN 'completed' THEN 'Completed - Payment Released'
      WHEN 'cancelled' THEN 'Cancelled'
      WHEN 'refunded' THEN 'Refunded'
      ELSE p_status
    END;
  ELSE
    RETURN p_status;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function to get available actions for current status
CREATE OR REPLACE FUNCTION get_order_available_actions(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_is_collector boolean;
  v_is_picker boolean;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  SELECT o.*, p.user_type
  INTO v_order
  FROM orders o
  JOIN profiles p ON p.id = p_user_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN v_actions;
  END IF;

  v_is_collector := (v_order.client_id = p_user_id);
  v_is_picker := (v_order.picker_id = p_user_id);

  IF v_is_collector THEN
    CASE v_order.status
      WHEN 'awaiting_quote' THEN
        v_actions := jsonb_build_array('cancel_order', 'message_picker');
      WHEN 'quote_provided' THEN
        v_actions := jsonb_build_array('pay_now', 'message_picker', 'cancel_order');
      WHEN 'payment_pending' THEN
        v_actions := jsonb_build_array('view_payment_status');
      WHEN 'paid' THEN
        v_actions := jsonb_build_array('message_picker', 'track_order');
      WHEN 'shipped' THEN
        v_actions := jsonb_build_array('track_order', 'message_picker');
      WHEN 'delivered' THEN
        v_actions := jsonb_build_array('confirm_delivery', 'report_issue');
      WHEN 'completed' THEN
        v_actions := jsonb_build_array('leave_review', 'reorder');
      ELSE
        v_actions := '[]'::jsonb;
    END CASE;
  END IF;

  IF v_is_picker THEN
    CASE v_order.status
      WHEN 'awaiting_quote' THEN
        v_actions := jsonb_build_array('provide_quote', 'message_collector');
      WHEN 'quote_provided' THEN
        v_actions := jsonb_build_array('update_quote', 'message_collector');
      WHEN 'payment_pending' THEN
        v_actions := jsonb_build_array('view_payment_status');
      WHEN 'paid' THEN
        v_actions := jsonb_build_array('mark_shipped', 'upload_video', 'message_collector');
      WHEN 'shipped' THEN
        v_actions := jsonb_build_array('update_tracking', 'message_collector');
      WHEN 'delivered' THEN
        v_actions := jsonb_build_array('message_collector');
      WHEN 'completed' THEN
        v_actions := jsonb_build_array('view_payout');
      ELSE
        v_actions := '[]'::jsonb;
    END CASE;
  END IF;

  RETURN v_actions;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger: When picker provides shipping quote
CREATE OR REPLACE FUNCTION auto_transition_on_quote_provided()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transportation_cost IS NOT NULL
     AND NEW.shipping_quote_status = 'quote_provided'
     AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_provided')
     AND NEW.status = 'awaiting_quote' THEN

    NEW.status := 'quote_provided';

    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'order',
      'Shipping Quote Provided',
      'Your picker has provided a shipping quote. Review and proceed to payment.',
      jsonb_build_object('order_id', NEW.id, 'shipping_cost', NEW.transportation_cost, 'action', 'review_quote')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_transition_on_quote ON orders;
CREATE TRIGGER trigger_auto_transition_on_quote
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.shipping_quote_status IS DISTINCT FROM OLD.shipping_quote_status)
  EXECUTE FUNCTION auto_transition_on_quote_provided();

-- Trigger: When payment is successful
CREATE OR REPLACE FUNCTION auto_transition_on_payment_success()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.payment_status = 'paid'
     AND (OLD.payment_status IS NULL OR OLD.payment_status != 'paid')
     AND NEW.status IN ('quote_provided', 'payment_pending', 'awaiting_quote') THEN

    NEW.status := 'paid';

    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'order',
      'Payment Received!',
      'Payment has been received. You can now prepare and ship the item.',
      jsonb_build_object('order_id', NEW.id, 'total_amount', NEW.total_amount, 'action', 'prepare_item')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_transition_on_payment ON orders;
CREATE TRIGGER trigger_auto_transition_on_payment
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.payment_status IS DISTINCT FROM OLD.payment_status)
  EXECUTE FUNCTION auto_transition_on_payment_success();

-- Trigger: Notify on status changes
CREATE OR REPLACE FUNCTION notify_on_simplified_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'shipped' AND OLD.status = 'paid' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (NEW.client_id, 'order', 'Order Shipped!', 'Your order has been shipped and is on its way.', jsonb_build_object('order_id', NEW.id, 'action', 'track_shipment'));

  ELSIF NEW.status = 'delivered' AND OLD.status = 'shipped' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (NEW.client_id, 'order', 'Order Delivered', 'Your order has been delivered. Please confirm receipt.', jsonb_build_object('order_id', NEW.id, 'action', 'confirm_delivery'));

  ELSIF NEW.status = 'completed' AND OLD.status = 'delivered' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (NEW.picker_id, 'order', 'Delivery Confirmed - Payment Released!', 'The collector confirmed delivery. Your payment has been released.', jsonb_build_object('order_id', NEW.id, 'action', 'view_payout'));

  ELSIF NEW.status = 'cancelled' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (CASE WHEN NEW.client_id = auth.uid() THEN NEW.picker_id ELSE NEW.client_id END, 'order', 'Order Cancelled', 'An order has been cancelled.', jsonb_build_object('order_id', NEW.id, 'action', 'view_cancelled_order'));

  ELSIF NEW.status = 'refunded' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (NEW.client_id, 'payment', 'Refund Processed', 'Your refund has been processed.', jsonb_build_object('order_id', NEW.id, 'amount', NEW.total_amount));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_simplified_status ON orders;
CREATE TRIGGER trigger_notify_simplified_status
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION notify_on_simplified_status_change();

-- Create index for common status queries
CREATE INDEX IF NOT EXISTS idx_orders_simplified_status ON orders(status)
WHERE status IN ('awaiting_quote', 'quote_provided', 'paid', 'shipped', 'delivered');
