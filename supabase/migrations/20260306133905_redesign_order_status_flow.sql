/*
  # Redesign Order Status Flow for Logical Progression

  ## Overview
  This migration creates a more intuitive order status system with clear stages
  for both collectors and pickers, linked directly to actions they take.

  ## New Status Flow

  ### For Collectors:
  1. **unpaid** - Order created but payment not completed (Action: Complete payment)
  2. **paid** - Payment successful, waiting for picker to start (Action: Wait for picker)
  3. **processing** - Picker is working on finding/purchasing item (Action: Wait for updates)
  4. **shipped** - Item shipped by picker (Action: Wait for delivery)
  5. **received** - Collector confirms receipt (Action: Confirm delivery)
  6. **cancelled** - Order cancelled by either party
  7. **refunded** - Payment refunded to collector

  ### For Pickers:
  1. **awaiting_payment** - Order created, waiting for collector payment (Action: Wait)
  2. **new_order** - Payment received, new order to accept (Action: Accept order)
  3. **accepted** - Order accepted, need to start work (Action: Mark as processing)
  4. **processing** - Working on finding/purchasing item (Action: Upload pickup video & mark shipped)
  5. **shipped** - Item shipped to collector (Action: Wait for delivery confirmation)
  6. **completed** - Collector confirmed delivery, payment released (Action: None - final state)
  7. **cancelled** - Order cancelled
  8. **refunded** - Payment refunded

  ## Action Triggers
  - Collector creates order → Status: **unpaid**
  - Collector completes payment → Status: **paid** (Picker sees: **new_order**)
  - Picker accepts order → Status: **accepted**
  - Picker starts work → Status: **processing**
  - Picker uploads pickup video & ships → Status: **shipped**
  - Collector confirms delivery → Status: **received** (Picker sees: **completed**)
  - Either party cancels → Status: **cancelled**
  - Refund processed → Status: **refunded**
*/

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS valid_status;

-- Add new constraint with all valid statuses
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'pending',          -- Legacy status, will be migrated
    'accepted',         -- Both: picker accepted order
    'in_progress',      -- Legacy status, will be migrated
    'delivered',        -- Legacy status, will be migrated
    'cancelled',        -- Both: order cancelled
    'refunded',         -- Both: payment refunded
    'unpaid',           -- Collector: order created, needs to pay
    'paid',             -- Collector: paid, waiting for picker to accept
    'processing',       -- Both: picker is working on the order
    'shipped',          -- Both: item has been shipped
    'received'          -- Collector: confirmed delivery
  ));

-- Update existing orders to new status values
-- Map old statuses to new ones
UPDATE orders SET status = 'unpaid' WHERE status = 'pending' AND payment_status = 'pending';
UPDATE orders SET status = 'paid' WHERE status = 'pending' AND payment_status = 'paid';
UPDATE orders SET status = 'processing' WHERE status = 'in_progress';
UPDATE orders SET status = 'shipped' WHERE status = 'delivered' AND goods_confirmed_at IS NULL;
UPDATE orders SET status = 'received' WHERE status = 'delivered' AND goods_confirmed_at IS NOT NULL;

-- Now remove the legacy statuses from the constraint
ALTER TABLE orders DROP CONSTRAINT orders_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status IN (
    'unpaid',           -- Collector: order created, needs to pay
    'paid',             -- Collector: paid, waiting for picker to accept
    'accepted',         -- Both: picker accepted order
    'processing',       -- Both: picker is working on the order
    'shipped',          -- Both: item has been shipped
    'received',         -- Collector: confirmed delivery
    'cancelled',        -- Both: order cancelled
    'refunded'          -- Both: payment refunded
  ));

-- Create function to get display status for user type
CREATE OR REPLACE FUNCTION get_order_display_status(
  p_status text,
  p_user_type text,
  p_payment_status text
)
RETURNS text AS $$
BEGIN
  -- For collectors (clients)
  IF p_user_type = 'collector' OR p_user_type = 'client' THEN
    CASE p_status
      WHEN 'unpaid' THEN RETURN 'Pending Payment';
      WHEN 'paid' THEN RETURN 'Paid - Waiting for Picker';
      WHEN 'accepted' THEN RETURN 'Accepted by Picker';
      WHEN 'processing' THEN RETURN 'Picker is Finding Item';
      WHEN 'shipped' THEN RETURN 'Shipped - In Transit';
      WHEN 'received' THEN RETURN 'Delivered';
      WHEN 'cancelled' THEN RETURN 'Cancelled';
      WHEN 'refunded' THEN RETURN 'Refunded';
      ELSE RETURN p_status;
    END CASE;

  -- For pickers
  ELSIF p_user_type = 'picker' THEN
    CASE p_status
      WHEN 'unpaid' THEN RETURN 'Awaiting Payment';
      WHEN 'paid' THEN RETURN 'New Order - Needs Acceptance';
      WHEN 'accepted' THEN RETURN 'Accepted - Start Work';
      WHEN 'processing' THEN RETURN 'Processing Order';
      WHEN 'shipped' THEN RETURN 'Shipped - Awaiting Delivery';
      WHEN 'received' THEN RETURN 'Completed';
      WHEN 'cancelled' THEN RETURN 'Cancelled';
      WHEN 'refunded' THEN RETURN 'Refunded';
      ELSE RETURN p_status;
    END CASE;

  ELSE
    RETURN p_status;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function to get next available actions for user
CREATE OR REPLACE FUNCTION get_order_actions(
  p_order_id uuid,
  p_user_id uuid
)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_is_client boolean;
  v_is_picker boolean;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  -- Get order details
  SELECT o.*, p.user_type
  INTO v_order
  FROM orders o
  JOIN profiles p ON p.id = p_user_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN v_actions;
  END IF;

  v_is_client := (v_order.client_id = p_user_id);
  v_is_picker := (v_order.picker_id = p_user_id);

  -- Collector actions
  IF v_is_client THEN
    CASE v_order.status
      WHEN 'unpaid' THEN
        v_actions := v_actions || '["complete_payment"]'::jsonb;
      WHEN 'shipped' THEN
        v_actions := v_actions || '["confirm_delivery"]'::jsonb;
      WHEN 'paid', 'accepted', 'processing' THEN
        v_actions := v_actions || '["cancel_order"]'::jsonb;
      ELSE
        NULL;
    END CASE;
  END IF;

  -- Picker actions
  IF v_is_picker THEN
    CASE v_order.status
      WHEN 'paid' THEN
        v_actions := v_actions || '["accept_order", "decline_order"]'::jsonb;
      WHEN 'accepted' THEN
        v_actions := v_actions || '["start_processing"]'::jsonb;
      WHEN 'processing' THEN
        v_actions := v_actions || '["upload_video_and_ship"]'::jsonb;
      ELSE
        NULL;
    END CASE;
  END IF;

  RETURN v_actions;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create indexes for new status values
CREATE INDEX IF NOT EXISTS idx_orders_status_new ON orders(status) WHERE status IN ('unpaid', 'paid', 'processing', 'shipped');

-- Update trigger to automatically transition from unpaid to paid when payment succeeds
CREATE OR REPLACE FUNCTION auto_transition_order_status_on_payment()
RETURNS TRIGGER AS $$
BEGIN
  -- When payment_status changes to 'paid' and order is 'unpaid', move to 'paid'
  IF NEW.payment_status = 'paid' AND OLD.payment_status = 'pending' AND OLD.status = 'unpaid' THEN
    NEW.status := 'paid';

    -- Notify picker of new paid order
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'order',
      'New Paid Order!',
      'You have received a new paid order. Please review and accept it.',
      jsonb_build_object('order_id', NEW.id, 'action', 'new_order')
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_transition_status_on_payment ON orders;
CREATE TRIGGER trigger_auto_transition_status_on_payment
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.payment_status IS DISTINCT FROM OLD.payment_status)
  EXECUTE FUNCTION auto_transition_order_status_on_payment();

-- Update trigger for status transitions to send notifications
CREATE OR REPLACE FUNCTION notify_on_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only proceed if status actually changed
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Picker accepted order
  IF NEW.status = 'accepted' AND OLD.status = 'paid' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'order',
      'Order Accepted!',
      'Your picker has accepted your order and will start working on it soon.',
      jsonb_build_object('order_id', NEW.id, 'action', 'order_accepted')
    );

  -- Picker started processing
  ELSIF NEW.status = 'processing' AND OLD.status = 'accepted' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'order',
      'Order Processing',
      'Your picker has started working on finding your item!',
      jsonb_build_object('order_id', NEW.id, 'action', 'order_processing')
    );

  -- Item shipped
  ELSIF NEW.status = 'shipped' AND OLD.status = 'processing' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'order',
      'Order Shipped!',
      'Your order has been shipped and is on its way to you.',
      jsonb_build_object('order_id', NEW.id, 'action', 'order_shipped')
    );

  -- Delivery confirmed
  ELSIF NEW.status = 'received' AND OLD.status = 'shipped' THEN
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'order',
      'Delivery Confirmed!',
      'The collector has confirmed delivery. Your payment will be processed.',
      jsonb_build_object('order_id', NEW.id, 'action', 'delivery_confirmed')
    );

  -- Order cancelled
  ELSIF NEW.status = 'cancelled' THEN
    -- Notify the other party
    IF TG_OP = 'UPDATE' THEN
      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        CASE WHEN NEW.client_id = auth.uid() THEN NEW.picker_id ELSE NEW.client_id END,
        'order',
        'Order Cancelled',
        'An order has been cancelled.',
        jsonb_build_object('order_id', NEW.id, 'action', 'order_cancelled')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_status_change ON orders;
CREATE TRIGGER trigger_notify_on_status_change
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION notify_on_order_status_change();