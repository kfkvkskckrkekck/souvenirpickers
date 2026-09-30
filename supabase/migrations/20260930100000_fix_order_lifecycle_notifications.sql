/*
  # Fix and complete order-lifecycle notifications

  ## Problem
  Several notifications written across the order lifecycle describe money
  moving that hasn't actually moved yet - a holdover from before the 14-day
  payout delay was added. The frontend (NotificationsView.tsx ->
  getActionButton) already supports rendering a labeled action button from
  notifications.metadata (action / action_text + action_url) - it just
  wasn't being given that data consistently, so most of these notifications
  render with no button at all. No frontend changes are needed here; this
  is a backend content fix only.

  ## Also fixed while touching this text
  picker_mark_shipped's old "Shipping Cost Released" notification divided
  shipping_amount by 100 before displaying it - but shipping_amount is
  stored in whole currency units everywhere else (payment_escrow,
  picker_earnings), not cents, so it was showing a shipping cost 100x too
  small. Removed, along with the "being processed" framing - confirmed live
  that no Stripe transfer happens at ship time at all (it's bundled into
  the same combined transfer that fires 14 days after delivery
  confirmation).

  ## Checked and ruled out while investigating this
  stripe-webhook has a separate, immediate Stripe transfer for
  orders.transportation_cost on payment success. Grepped the frontend and
  confirmed this column is only ever written by the unrelated Custom Orders
  feature (CustomOrderModal.tsx) - it's always null/0 for regular Sendcloud
  orders, so it does not double-pay shipping alongside
  process-picker-payout's combined transfer. Left untouched; out of scope
  for this change.

  ## What changed here
  - picker_mark_shipped: picker notification rewritten (no more false
    "shipping released" claim, unit bug fixed, no action button - nothing
    to do at this point); buyer notification gets an explicit "Track
    Shipment" action.
  - collector_confirm_delivery: picker notification gets a "View Earnings"
    action (text was already accurate from the previous migration).
  - process_auto_release_orders: "automatically released" (which implied
    payment already happened) corrected to describe the same 14-day
    scheduling as a manual confirmation, plus a "View Earnings" action for
    the picker.

  process-picker-payout and the stripe-webhook payment_intent.succeeded
  handler are updated to match in the accompanying code edits (not SQL).
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

  IF v_order.shipped_at IS NOT NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been marked as shipped'
    );
  END IF;

  v_picker_id := v_order.picker_id;
  v_client_id := v_order.client_id;

  UPDATE orders
  SET
    status = 'shipped',
    tracking_status = 'in_transit',
    shipped_at = now(),
    tracking_number = p_tracking_number,
    auto_release_at = now() + INTERVAL '14 days',
    updated_at = now()
  WHERE id = p_order_id;

  SELECT * INTO v_escrow
  FROM payment_escrow
  WHERE order_id = p_order_id
    AND status = 'held';

  IF v_escrow.id IS NOT NULL AND v_escrow.shipping_amount > 0 AND NOT v_escrow.shipping_released THEN
    UPDATE payment_escrow
    SET
      shipping_released = true,
      shipping_released_at = now(),
      notes = 'Shipping cost marked for release alongside item payment upon delivery confirmation.'
    WHERE id = v_escrow.id;
  END IF;

  -- Notify collector: clear next action (track, then confirm once it arrives)
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_client_id,
    'order_shipped',
    'Your Order Has Been Shipped!',
    CASE
      WHEN p_tracking_number IS NOT NULL THEN
        'Your order has shipped with tracking number: ' || p_tracking_number || '. Please confirm delivery once it arrives.'
      ELSE
        'Your order has shipped! Please confirm delivery once it arrives.'
    END,
    jsonb_build_object(
      'order_id', p_order_id,
      'tracking_number', p_tracking_number,
      'action', 'track_shipment'
    )
  );

  -- Notify picker: informational only - no money has moved yet, and there's
  -- nothing for them to do until the buyer confirms (or 14 days pass), so
  -- no action button
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'order_status_update',
    'Order Marked as Shipped',
    'Nice work! Your full payment (item + shipping) will be released 14 days after the buyer confirms delivery - or automatically, 14 days after shipping, if they don''t respond.',
    jsonb_build_object('order_id', p_order_id, 'escrow_id', v_escrow.id)
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
    tracking_status = 'delivered',
    actual_delivery = COALESCE(actual_delivery, now()),
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
    AND status IN ('held', 'processing')
  LIMIT 1;

  IF v_escrow_id IS NOT NULL THEN
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Scheduled',
    'The collector confirmed they received the order. Your payment will be released to your bank account within 14 days.',
    jsonb_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now(),
      'action_text', 'View Earnings',
      'action_url', '/earnings'
    )
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid within 14 days.',
    jsonb_build_object('order_id', p_order_id)
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed. Payment will be released to the picker within 14 days.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;

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
        tracking_status = 'delivered',
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
        'delivery_confirmed',
        'Delivery Auto-Confirmed',
        'The buyer did not respond within 14 days of shipping, so delivery was auto-confirmed. Your payment will be released within 14 days.',
        jsonb_build_object(
          'order_id', v_order.id,
          'escrow_id', v_order.escrow_id,
          'action_text', 'View Earnings',
          'action_url', '/earnings'
        )
      );

      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        v_order.client_id,
        'delivery_confirmed_collector',
        'Order Auto-Confirmed',
        'Your order was automatically marked as delivered since no issues were reported within 14 days of shipping.',
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
