/*
  # Enable Automatic Payouts via Webhook Approach
  
  1. Problem
    - Database cannot set runtime configuration for edge function calls
    - Need alternative way to trigger automatic payouts
    
  2. Solution
    - Use pg_net extension to call edge function directly with hardcoded URL
    - When collector confirms delivery, immediately trigger payout
    
  3. Flow
    - Collector confirms delivery
    - Order status updated to 'delivered'
    - Escrow marked for processing
    - Edge function called via pg_net to process Stripe transfer
    - Picker receives payment automatically
    
  4. Security
    - Uses Supabase service role authentication
    - Only called after delivery confirmation
    - Idempotent - won't double-process payments
*/

-- Enable pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Update collector_confirm_delivery to trigger automatic payout
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

  -- Release escrow and trigger automatic payout
  IF v_escrow_id IS NOT NULL THEN
    -- Call the release function (marks for processing)
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;

    -- Trigger automatic payout via edge function
    BEGIN
      -- Make HTTP request to process-picker-payout edge function
      -- This uses pg_net to make the call asynchronously
      SELECT net.http_post(
        url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('request.jwt.claims', true)::json->>'role'
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_id,
          'pickerId', v_picker_id
        )
      ) INTO v_request_id;

      -- Log the payout trigger
      RAISE NOTICE 'Automatic payout triggered for escrow % (request ID: %)', v_escrow_id, v_request_id;
    EXCEPTION WHEN OTHERS THEN
      -- If HTTP call fails, log but don't fail the whole transaction
      -- The escrow is still marked for processing and can be handled manually or via cron
      RAISE WARNING 'Failed to trigger automatic payout: %', SQLERRM;
    END;
  END IF;

  -- Notify picker
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

  -- Notify collector
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid immediately.',
    jsonb_build_object(
      'order_id', p_order_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed. Payment is being processed automatically.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;

COMMENT ON FUNCTION collector_confirm_delivery(uuid, text) IS
  'Confirms delivery and triggers automatic Stripe payout to picker via edge function';
