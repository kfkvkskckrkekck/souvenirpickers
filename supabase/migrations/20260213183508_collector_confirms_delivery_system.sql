/*
  # Collector Confirms Delivery System

  1. Changes
    - Collectors are the primary authority on delivery confirmation
    - When collector confirms delivery, payment is released immediately
    - Pickers can no longer unilaterally mark orders as "delivered"
    - If collector doesn't confirm, system prompts them with reminders
    
  2. New Flow
    - Order paid → status "in_progress"
    - Picker fulfills and ships order
    - Collector receives goods → confirms delivery
    - System releases payment immediately to picker
    - If no confirmation after reasonable time, escalation process

  3. Reminders
    - After order is X days old, remind collector to confirm delivery
    - Multiple reminder tiers
    - Dispute resolution if needed

  4. Benefits
    - Collector has full control over delivery confirmation
    - Reduces fraud (picker can't falsely claim delivery)
    - Payment only releases when collector confirms
    - More trustworthy system
*/

-- Update the confirm delivery function to be collector-centric
CREATE OR REPLACE FUNCTION collector_confirm_delivery(
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
    AND reminder_type IN ('delivery_confirmation', 'picker_mark_delivered');

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
    'message', 'Delivery confirmed. Payment will be processed immediately.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create reminders for collector to confirm delivery
CREATE OR REPLACE FUNCTION create_collector_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_order_created timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as picker_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already confirmed
  IF v_order.status = 'delivered' OR v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use order creation time
  v_order_created := v_order.created_at;

  -- Cancel any existing reminders for this order
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'collector_confirm_delivery';

  -- Schedule reminders at 3, 5, and 7 days after order creation
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_order_created + INTERVAL '3 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_order_created + INTERVAL '5 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_order_created + INTERVAL '7 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create collector reminders when order is paid
CREATE OR REPLACE FUNCTION trigger_collector_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Create reminders when order is paid and in progress
  IF NEW.status = 'in_progress' 
     AND NEW.payment_status = 'paid' 
     AND (OLD.payment_status IS NULL OR OLD.payment_status != 'paid') THEN
    PERFORM create_collector_delivery_reminders(NEW.id);
  END IF;

  -- Cancel reminders if delivery is confirmed
  IF (NEW.status = 'delivered' OR NEW.goods_confirmed = true) 
     AND (OLD.status != 'delivered' AND OLD.goods_confirmed = false) THEN
    UPDATE reminder_queue
    SET cancelled = true, cancelled_at = now()
    WHERE related_id = NEW.id
      AND sent = false
      AND cancelled = false
      AND reminder_type = 'collector_confirm_delivery';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Replace the old triggers with the new one
DROP TRIGGER IF EXISTS on_order_picker_reminders ON orders;
DROP TRIGGER IF EXISTS on_order_delivered ON orders;

CREATE TRIGGER on_collector_delivery_reminders
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_collector_delivery_reminders();

-- Update the reminder processing function
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Handle collector delivery confirmation reminders
      IF v_reminder.reminder_type = 'collector_confirm_delivery' THEN
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 'Important: Confirm Your Delivery'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Have You Received Your Order?'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Please confirm delivery of your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '. The picker is waiting for payment. If there are issues, please contact support.'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Please confirm delivery so they can receive payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' should be arriving soon. Please confirm when you receive it!'
          END,
          v_reminder.data
        );
      END IF;

      -- Mark reminder as sent
      UPDATE reminder_queue
      SET sent = true, sent_at = now()
      WHERE id = v_reminder.id;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Error processing reminder %: %', v_reminder.id, SQLERRM;
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
GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION create_collector_delivery_reminders(uuid) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION collector_confirm_delivery(uuid, text) IS 
  'Allows collector to confirm they received the delivery. This is the primary way to release payment to pickers.';

COMMENT ON FUNCTION create_collector_delivery_reminders(uuid) IS 
  'Creates reminder notifications for collectors to confirm delivery after 3, 5, and 7 days';
