/*
  # Shipping Cost Immediate Payout + Auto-Release System

  1. Problem
    - Pickers pay shipping costs upfront
    - Don't get reimbursed until collector confirms (weeks later)
    - Unfair cash flow burden on pickers

  2. Solution - Two-Tier Payment
    a) IMMEDIATE: Release shipping cost to picker when they mark "shipped"
    b) ESCROW: Keep item price in escrow until delivery confirmed
    c) AUTO-RELEASE: After 14 days from ship date, auto-release if no disputes

  3. New Fields
    - orders.shipped_at: When picker marks item as shipped
    - orders.tracking_number: Optional tracking info
    - payment_escrow.shipping_amount: Amount paid for shipping
    - payment_escrow.item_amount: Amount for the item itself
    - payment_escrow.shipping_released: Boolean flag

  4. New Flow
    - Collector pays → Full amount in escrow
    - Picker ships item → Shipping cost released immediately
    - Collector confirms OR 14 days pass → Item price released
    - Fair for everyone!
*/

-- Add new columns to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS shipped_at timestamptz,
ADD COLUMN IF NOT EXISTS tracking_number text,
ADD COLUMN IF NOT EXISTS auto_release_at timestamptz;

-- Add new columns to payment_escrow table
ALTER TABLE payment_escrow
ADD COLUMN IF NOT EXISTS shipping_amount numeric(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS item_amount numeric(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS shipping_released boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS shipping_released_at timestamptz;

-- Update existing escrow records to split amounts
UPDATE payment_escrow pe
SET 
  item_amount = COALESCE(pe.amount, 0),
  shipping_amount = 0
WHERE item_amount IS NULL;

-- Function for picker to mark order as shipped
CREATE OR REPLACE FUNCTION picker_mark_shipped(
  p_order_id uuid,
  p_tracking_number text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_picker_id uuid;
  v_escrow record;
  v_client_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  AND picker_id = auth.uid()
  AND status IN ('confirmed', 'in_progress')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or cannot be marked as shipped'
    );
  END IF;

  -- Check if already shipped
  IF v_order.shipped_at IS NOT NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been marked as shipped'
    );
  END IF;

  v_picker_id := v_order.picker_id;
  v_client_id := v_order.client_id;

  -- Update order with shipping info
  UPDATE orders
  SET
    status = 'in_progress',
    shipped_at = now(),
    tracking_number = p_tracking_number,
    auto_release_at = now() + INTERVAL '14 days',
    updated_at = now()
  WHERE id = p_order_id;

  -- Get the escrow for this order
  SELECT * INTO v_escrow
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- If there's a shipping amount and escrow exists, release it immediately
  IF v_escrow.id IS NOT NULL AND v_escrow.shipping_amount > 0 AND NOT v_escrow.shipping_released THEN
    -- Mark shipping cost as released
    UPDATE payment_escrow
    SET 
      shipping_released = true,
      shipping_released_at = now(),
      notes = 'Shipping cost released to picker upon marking shipped. Item cost remains in escrow until delivery confirmed.'
    WHERE id = v_escrow.id;

    -- Note: The actual Stripe transfer for shipping will be handled by edge function
    -- We'll call it from the frontend similar to the delivery confirmation
  END IF;

  -- Notify collector
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_client_id,
    'order_shipped',
    'Your Order Has Been Shipped!',
    CASE 
      WHEN p_tracking_number IS NOT NULL THEN
        'Your order has been shipped with tracking number: ' || p_tracking_number || '. You can confirm delivery when it arrives.'
      ELSE
        'Your order has been shipped! You''ll receive it soon. Please confirm delivery when it arrives.'
    END,
    json_build_object(
      'order_id', p_order_id,
      'tracking_number', p_tracking_number,
      'shipped_at', now(),
      'auto_release_in_days', 14
    )
  );

  -- Notify picker
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'shipping_cost_released',
    'Shipping Cost Released',
    CASE
      WHEN v_escrow.shipping_amount > 0 THEN
        'Your shipping cost ($' || (v_escrow.shipping_amount / 100)::text || ') is being processed for payment. Item payment will be released when delivery is confirmed or after 14 days.'
      ELSE
        'Order marked as shipped. Payment will be released when delivery is confirmed or after 14 days.'
    END,
    json_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow.id,
      'shipping_amount', v_escrow.shipping_amount,
      'auto_release_date', now() + INTERVAL '14 days'
    )
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow.id,
    'shipped_at', now(),
    'auto_release_at', now() + INTERVAL '14 days',
    'shipping_amount', COALESCE(v_escrow.shipping_amount, 0),
    'message', 'Order marked as shipped. Auto-release in 14 days if not confirmed earlier.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process auto-releases (called by cron job or edge function)
CREATE OR REPLACE FUNCTION process_auto_release_orders()
RETURNS json AS $$
DECLARE
  v_order record;
  v_count integer := 0;
  v_escrow_id uuid;
  v_release_result json;
BEGIN
  -- Find orders that should be auto-released
  FOR v_order IN
    SELECT o.*, pe.id as escrow_id
    FROM orders o
    LEFT JOIN payment_escrow pe ON pe.order_id = o.id
    WHERE o.auto_release_at <= now()
    AND o.status IN ('in_progress', 'confirmed')
    AND o.goods_confirmed = false
    AND pe.status = 'held'
    AND pe.id IS NOT NULL
    ORDER BY o.auto_release_at ASC
    LIMIT 50
  LOOP
    BEGIN
      -- Auto-confirm delivery
      UPDATE orders
      SET
        status = 'delivered',
        actual_delivery = now(),
        goods_confirmed = true,
        goods_confirmed_at = now(),
        confirmation_notes = 'Auto-confirmed: No issues reported within 14 days of shipping',
        updated_at = now()
      WHERE id = v_order.id;

      -- Release escrow
      SELECT release_escrow_to_picker(v_order.escrow_id, v_order.picker_id) INTO v_release_result;

      -- Notify picker
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_order.picker_id,
        'auto_release_completed',
        'Payment Automatically Released',
        'Your payment for order has been automatically released since delivery was not disputed within 14 days.',
        json_build_object(
          'order_id', v_order.id,
          'escrow_id', v_order.escrow_id
        )
      );

      -- Notify collector
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_order.client_id,
        'auto_release_completed',
        'Order Automatically Confirmed',
        'Your order has been automatically confirmed as delivered since no issues were reported within 14 days.',
        json_build_object(
          'order_id', v_order.id
        )
      );

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Error auto-releasing order %: %', v_order.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION picker_mark_shipped(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_auto_release_orders() TO service_role;

-- Create index for auto-release queries
CREATE INDEX IF NOT EXISTS idx_orders_auto_release 
ON orders(auto_release_at) 
WHERE status IN ('in_progress', 'confirmed') AND goods_confirmed = false;

COMMENT ON FUNCTION picker_mark_shipped IS 
  'Picker marks order as shipped. Releases shipping cost immediately and sets auto-release timer for 14 days.';

COMMENT ON FUNCTION process_auto_release_orders IS 
  'Automatically releases payment for orders that have been shipped for 14+ days without disputes';