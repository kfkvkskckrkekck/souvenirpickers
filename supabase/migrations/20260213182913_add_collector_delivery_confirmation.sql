/*
  # Add Collector-Initiated Delivery Confirmation

  1. New Function
    - `collector_confirm_delivery_and_receipt()` - Collector marks order as delivered + confirms receipt
    - Handles case where picker forgot to update order status
    - Immediately releases escrow payment

  2. Updates
    - Allow collectors to mark order as delivered if picker forgets
    - Sets actual_delivery timestamp
    - Marks goods as confirmed
    - Triggers immediate payment release

  3. Benefits
    - Collectors can confirm receipt even if picker forgot to update status
    - Prevents payment delays due to picker inaction
    - Maintains trust in the platform

  4. Security
    - Only collector of the order can confirm
    - Only works for orders in 'in_progress' or 'confirmed' status
    - Prevents abuse by requiring order to exist and be paid
*/

-- Function for collector to confirm delivery AND receipt (when picker forgot to mark as delivered)
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
  -- Get order details
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

  -- Check if order is in a valid state
  IF v_order.status NOT IN ('in_progress', 'confirmed', 'delivered') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  -- Check if payment was made
  IF v_order.payment_status != 'paid' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order must be paid before confirming delivery'
    );
  END IF;

  -- Check if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been confirmed'
    );
  END IF;

  -- Update order: mark as delivered (if not already) AND confirm receipt
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

  -- Cancel any pending delivery reminders
  PERFORM cancel_order_reminders(p_order_id);

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- Release escrow immediately
  IF v_escrow_id IS NOT NULL THEN
    PERFORM release_escrow_to_picker(v_escrow_id, v_picker_id);
  END IF;

  -- Notify picker
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Order Confirmed - Payment Processing',
    'The collector confirmed receipt of the order. Your payment is being processed now!',
    json_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  -- Notify collector
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'confirmation_received',
    'Thank You for Confirming',
    'Your confirmation has been received. The picker will be paid immediately.',
    json_build_object(
      'order_id', p_order_id
    )
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION collector_confirm_delivery_and_receipt(uuid, text) TO authenticated;

-- Add helpful comment
COMMENT ON FUNCTION collector_confirm_delivery_and_receipt(uuid, text) IS 
  'Allows collector to confirm delivery and receipt even if picker forgot to mark as delivered. Releases payment immediately.';
