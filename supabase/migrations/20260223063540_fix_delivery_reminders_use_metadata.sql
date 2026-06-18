/*
  # Fix Delivery Reminders to Use Correct Column Name

  1. Changes
    - Update create_delivery_reminders function to use 'metadata' instead of 'data'
    - The notifications table uses 'metadata' column, not 'data'
  
  2. Security
    - Maintains existing security posture
    - No changes to RLS policies
*/

-- Update function to create delivery confirmation reminders
CREATE OR REPLACE FUNCTION create_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_delivery_time timestamptz;
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
  IF v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use actual delivery time or current time
  v_delivery_time := COALESCE(v_order.actual_delivery, now());

  -- Cancel any existing reminders for this order
  PERFORM cancel_order_reminders(p_order_id);

  -- Schedule reminders at 12, 24, and 36 hours after delivery
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '12 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '24 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '36 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );

  -- Send immediate notification about delivery (use metadata instead of data)
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'order_delivered',
    'Order Delivered!',
    'Your order from ' || v_order.picker_name || ' has been delivered. Confirm receipt to release payment immediately.',
    jsonb_build_object(
      'order_id', p_order_id,
      'picker_id', v_order.picker_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;