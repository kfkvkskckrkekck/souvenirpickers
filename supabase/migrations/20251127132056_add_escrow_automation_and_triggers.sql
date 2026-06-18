/*
  # Escrow Payment Protection System - Automation & Triggers

  1. New Functions
    - automatic_escrow_creation: Automatically creates escrow record when payment is confirmed
    - release_escrow_to_picker: Releases funds to picker when order is delivered
    - refund_escrow_to_client: Refunds money to client if order is cancelled/disputed
    - auto_release_escrow: Auto-release funds after delivery confirmation period
  
  2. Triggers
    - Auto-create escrow when payment intent succeeds
    - Update order status when escrow is released
    - Handle escrow timeouts
  
  3. Important Notes
    - Funds are held in escrow until order is marked as delivered
    - Client has 48 hours to dispute after delivery
    - After 48 hours, funds auto-release to picker
    - Refunds return money to client and update order status
*/

-- Function to automatically create escrow when payment succeeds
CREATE OR REPLACE FUNCTION automatic_escrow_creation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'succeeded' AND OLD.status != 'succeeded' THEN
    INSERT INTO payment_escrow (
      payment_intent_id,
      order_id,
      amount,
      status,
      held_at
    )
    VALUES (
      NEW.id,
      NEW.order_id,
      NEW.amount,
      'held',
      now()
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release escrow to picker
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'released',
    released_at = now(),
    released_to = picker_user_id,
    notes = 'Funds released to picker after delivery confirmation'
  WHERE id = escrow_id
  AND status = 'held'
  RETURNING order_id INTO v_order_id;

  -- Update order status to completed
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET 
      status = 'completed',
      updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refund escrow to client
CREATE OR REPLACE FUNCTION refund_escrow_to_client(escrow_id uuid, refund_reason text)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
  v_payment_intent_id uuid;
  v_amount numeric;
  v_client_id uuid;
BEGIN
  -- Get escrow details
  SELECT order_id, payment_intent_id, amount
  INTO v_order_id, v_payment_intent_id, v_amount
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  -- Get client ID from order
  SELECT client_id INTO v_client_id
  FROM orders
  WHERE id = v_order_id;

  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'refunded',
    released_at = now(),
    released_to = v_client_id,
    notes = refund_reason
  WHERE id = escrow_id;

  -- Create refund record
  INSERT INTO refunds (
    payment_intent_id,
    order_id,
    amount,
    reason,
    status,
    initiated_by
  )
  VALUES (
    v_payment_intent_id,
    v_order_id,
    v_amount,
    refund_reason,
    'completed',
    v_client_id
  );

  -- Update order status to cancelled
  UPDATE orders
  SET 
    status = 'cancelled',
    updated_at = now()
  WHERE id = v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-release escrow after confirmation period
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow RECORD;
BEGIN
  FOR v_escrow IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON pe.order_id = o.id
    WHERE pe.status = 'held'
    AND o.status = 'delivered'
    AND o.delivered_at IS NOT NULL
    AND o.delivered_at < now() - INTERVAL '48 hours'
  LOOP
    PERFORM release_escrow_to_picker(v_escrow.escrow_id, v_escrow.picker_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create escrow when payment succeeds
DROP TRIGGER IF EXISTS trigger_create_escrow_on_payment ON payment_intents;
CREATE TRIGGER trigger_create_escrow_on_payment
  AFTER UPDATE ON payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION automatic_escrow_creation();

-- Create a scheduled job function that can be called by an edge function
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS json AS $$
DECLARE
  v_released_count int := 0;
BEGIN
  PERFORM auto_release_escrow_after_confirmation();
  
  GET DIAGNOSTICS v_released_count = ROW_COUNT;
  
  RETURN json_build_object(
    'success', true,
    'released_count', v_released_count,
    'processed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION refund_escrow_to_client(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_escrow_releases() TO authenticated;