/*
  Fix picker_mark_shipped and collector_confirm_delivery functions
  to use the current order status values (paid, processing, shipped)
  instead of the obsolete ones (accepted, confirmed, in_progress).
*/

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
  -- Accept 'processing' (picker accepted the order) or 'paid' (payment received)
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
    AND picker_id = auth.uid()
    AND status IN ('processing', 'paid')
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
    status = 'shipped',
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
    UPDATE payment_escrow
    SET
      shipping_released = true,
      shipping_released_at = now(),
      notes = 'Shipping cost released to picker upon marking shipped. Item cost remains in escrow until delivery confirmed.'
    WHERE id = v_escrow.id;
  END IF;

  -- Notify collector
  INSERT INTO notifications (user_id, type, title, message, metadata)
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
    jsonb_build_object(
      'order_id', p_order_id,
      'tracking_number', p_tracking_number,
      'shipped_at', now(),
      'auto_release_in_days', 14
    )
  );

  -- Notify picker
  INSERT INTO notifications (user_id, type, title, message, metadata)
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
    jsonb_build_object(
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

-- Also fix collector_confirm_delivery to accept 'shipped' status
CREATE OR REPLACE FUNCTION collector_confirm_delivery(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
  v_release_result json;
BEGIN
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
    AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
    );
  END IF;

  -- Accept 'shipped' (current flow) or legacy statuses for safety
  IF v_order.status NOT IN ('shipped', 'delivered', 'in_progress', 'confirmed') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  IF v_order.payment_status != 'paid' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order must be paid before confirming delivery'
    );
  END IF;

  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Delivery has already been confirmed for this order'
    );
  END IF;

  UPDATE orders
  SET
    status = 'delivered',
    actual_delivery = now(),
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type IN ('delivery_confirmation', 'picker_mark_delivered', 'collector_confirm_delivery');

  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
    AND status = 'held';

  IF v_escrow_id IS NOT NULL THEN
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Processing',
    'The collector confirmed they received the order. Your payment is being processed now!',
    jsonb_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid immediately.',
    jsonb_build_object('order_id', p_order_id)
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed. Payment is being processed.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Also fix collector_confirm_delivery_and_receipt to accept 'shipped'
CREATE OR REPLACE FUNCTION collector_confirm_delivery_and_receipt(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
BEGIN
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
    AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
    );
  END IF;

  IF v_order.status NOT IN ('shipped', 'delivered', 'in_progress', 'confirmed') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  IF v_order.payment_status != 'paid' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order must be paid before confirming delivery'
    );
  END IF;

  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been confirmed'
    );
  END IF;

  UPDATE orders
  SET
    status = 'delivered',
    actual_delivery = COALESCE(actual_delivery, now()),
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  PERFORM cancel_order_reminders(p_order_id);

  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
    AND status = 'held';

  IF v_escrow_id IS NOT NULL THEN
    PERFORM release_escrow_to_picker(v_escrow_id, v_picker_id);
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Order Confirmed - Payment Processing',
    'The collector confirmed receipt of the order. Your payment is being processed now!',
    jsonb_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'confirmation_received',
    'Thank You for Confirming',
    'Your confirmation has been received. The picker will be paid immediately.',
    jsonb_build_object('order_id', p_order_id)
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'message', 'Delivery confirmed and payment will be processed immediately.',
    'status_updated', true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix process_auto_release_orders to use 'shipped' status
CREATE OR REPLACE FUNCTION process_auto_release_orders()
RETURNS json AS $$
DECLARE
  v_order record;
  v_count integer := 0;
  v_escrow_id uuid;
  v_release_result json;
BEGIN
  FOR v_order IN
    SELECT o.*, pe.id as escrow_id
    FROM orders o
    LEFT JOIN payment_escrow pe ON pe.order_id = o.id
    WHERE o.auto_release_at <= now()
      AND o.status IN ('shipped', 'in_progress', 'confirmed')
      AND o.goods_confirmed = false
      AND pe.status = 'held'
      AND pe.id IS NOT NULL
    ORDER BY o.auto_release_at ASC
    LIMIT 50
  LOOP
    BEGIN
      UPDATE orders
      SET
        status = 'delivered',
        actual_delivery = now(),
        goods_confirmed = true,
        goods_confirmed_at = now(),
        confirmation_notes = 'Auto-confirmed: No issues reported within 14 days of shipping',
        updated_at = now()
      WHERE id = v_order.id;

      SELECT release_escrow_to_picker(v_order.escrow_id, v_order.picker_id) INTO v_release_result;

      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        v_order.picker_id,
        'auto_release_completed',
        'Payment Automatically Released',
        'Your payment for order has been automatically released since delivery was not disputed within 14 days.',
        jsonb_build_object('order_id', v_order.id, 'escrow_id', v_order.escrow_id)
      );

      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        v_order.client_id,
        'auto_release_completed',
        'Order Automatically Confirmed',
        'Your order has been automatically confirmed as delivered since no issues were reported within 14 days.',
        jsonb_build_object('order_id', v_order.id)
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
