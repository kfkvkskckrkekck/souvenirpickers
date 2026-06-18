/*
  # Trigger Stripe Payout on Delivery Confirmation

  1. Problem
    - Collector confirms delivery
    - Escrow is marked for processing
    - But actual Stripe transfer never happens
    - Money stays in escrow forever

  2. Solution
    - When collector confirms delivery, immediately call process-picker-payout edge function
    - Use Supabase's pg_net extension to make HTTP call from database
    - This completes the payment flow end-to-end

  3. Flow
    - Collector clicks "Confirm Delivery"
    - collector_confirm_delivery() function is called
    - Escrow is marked for payout
    - HTTP request sent to process-picker-payout edge function
    - Edge function creates Stripe transfer
    - Picker receives payment (minus 10% platform fee)
    - Everyone happy!

  4. Safety
    - Only processes if escrow is in 'held' status
    - Edge function validates picker has payout account
    - Idempotent - won't double-process
    - All existing code continues to work
*/

-- Update collector_confirm_delivery to trigger actual payout
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
  v_supabase_url text;
  v_service_key text;
  v_request_id bigint;
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

  -- Release escrow and mark for payout
  IF v_escrow_id IS NOT NULL THEN
    -- Call the release function (marks for processing)
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;

    -- Get Supabase environment variables for edge function call
    v_supabase_url := current_setting('app.settings.supabase_url', true);
    v_service_key := current_setting('app.settings.service_role_key', true);

    -- If we have the URL configured, trigger the actual payout via edge function
    IF v_supabase_url IS NOT NULL AND v_service_key IS NOT NULL THEN
      BEGIN
        -- Make HTTP request to process-picker-payout edge function
        SELECT net.http_post(
          url := v_supabase_url || '/functions/v1/process-picker-payout',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_key
          ),
          body := jsonb_build_object(
            'escrowId', v_escrow_id,
            'pickerId', v_picker_id
          )
        ) INTO v_request_id;

        -- Log the request
        RAISE NOTICE 'Payout processing triggered for escrow % (request ID: %)', v_escrow_id, v_request_id;
      EXCEPTION WHEN OTHERS THEN
        -- If HTTP call fails, log but don't fail the whole transaction
        -- The escrow is still marked for processing and can be handled manually
        RAISE WARNING 'Failed to trigger payout edge function: %', SQLERRM;
      END;
    END IF;
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
    'message', 'Delivery confirmed. Payment is being processed.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;

COMMENT ON FUNCTION collector_confirm_delivery(uuid, text) IS
  'Allows collector to confirm delivery and triggers immediate Stripe payout to picker';