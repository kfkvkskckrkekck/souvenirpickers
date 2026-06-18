/*
  # Update Collector Confirm Delivery to Return Picker ID

  1. Changes
    - Return picker_id in the response
    - This allows frontend to call process-picker-payout edge function
    - Simpler approach than database HTTP calls

  2. Why
    - Database HTTP calls (pg_net) require complex setup
    - Frontend can easily make the call with proper auth
    - More reliable and easier to debug
*/

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
  IF v_order.status NOT IN ('in_progress', 'confirmed') THEN
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

  -- Check if already delivered
  IF v_order.status = 'delivered' OR v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Delivery has already been confirmed for this order'
    );
  END IF;

  -- Update order: mark as delivered AND confirm receipt in one action
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

  -- Cancel any pending reminders
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type IN ('delivery_confirmation', 'picker_mark_delivered', 'collector_confirm_delivery');

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- Release escrow and mark for payout (this updates the escrow status)
  IF v_escrow_id IS NOT NULL THEN
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;
  END IF;

  -- Notify picker
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Processing',
    'The collector confirmed they received the order. Your payment is being processed now!',
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
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid immediately.',
    json_build_object(
      'order_id', p_order_id
    )
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

GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;