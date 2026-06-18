/*
  # Fix All Notification Functions to Use metadata Column

  1. Changes
    - Update all functions that insert into notifications table
    - Replace 'data' column references with 'metadata'
    - The notifications table uses 'metadata' column, not 'data'
  
  2. Functions Updated
    - collector_confirm_delivery_v3
    - process_pending_picker_reminders
    - Any other functions that insert notifications with data column
  
  3. Security
    - Maintains existing security posture
    - No changes to RLS policies
*/

-- Fix collector_confirm_delivery_v3 function
CREATE OR REPLACE FUNCTION collector_confirm_delivery_v3(p_order_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_order record;
  v_picker_id uuid;
  v_payout_result jsonb;
BEGIN
  -- Get order details and lock the row
  SELECT o.*, p.full_name as picker_name, p.id as picker_user_id
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order not found'
    );
  END IF;

  -- Verify caller is the collector
  IF v_order.client_id != auth.uid() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized'
    );
  END IF;

  -- Verify order status is delivered
  IF v_order.status != 'delivered' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Order must be in delivered status'
    );
  END IF;

  -- Check if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Goods already confirmed'
    );
  END IF;

  -- Update order to mark goods as confirmed
  UPDATE orders
  SET 
    goods_confirmed = true,
    goods_confirmed_at = now(),
    updated_at = now()
  WHERE id = p_order_id;

  -- Cancel any pending delivery reminders
  PERFORM cancel_order_reminders(p_order_id);

  v_picker_id := v_order.picker_user_id;

  -- Notify picker about confirmation
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Delivery Confirmed!',
    'The collector has confirmed receipt of the order. Payment is being processed.',
    jsonb_build_object(
      'order_id', p_order_id,
      'collector_id', v_order.client_id
    )
  );

  -- Notify collector about confirmation
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'goods_confirmed',
    'Receipt Confirmed',
    'Thank you for confirming receipt. Payment has been released to ' || v_order.picker_name || '.',
    jsonb_build_object(
      'order_id', p_order_id,
      'picker_id', v_picker_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed successfully'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix process_pending_picker_reminders function
CREATE OR REPLACE FUNCTION process_pending_picker_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_order record;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
      AND reminder_type = 'picker_delivery_reminder'
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Get order and picker details
      SELECT o.*, p.full_name as collector_name
      INTO v_order
      FROM orders o
      LEFT JOIN profiles p ON p.id = o.client_id
      WHERE o.id = v_reminder.related_id;

      IF FOUND AND NOT v_order.goods_confirmed AND v_order.status = 'shipped' THEN
        -- Send reminder notification to picker
        INSERT INTO notifications (user_id, type, title, message, metadata)
        VALUES (
          v_reminder.user_id,
          'picker_delivery_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Final Reminder: Mark Order as Delivered'
            ELSE 'Reminder: Mark Order as Delivered'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Final reminder: Please mark the order for ' || COALESCE(v_order.collector_name, 'the collector') || 
              ' as delivered once you have shipped it.'
            ELSE 
              'Don''t forget to mark the order for ' || COALESCE(v_order.collector_name, 'the collector') || 
              ' as delivered once it has been shipped.'
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
      -- Log error but continue processing
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

-- Fix process_pending_reminders function  
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
      -- Handle different reminder types
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        -- Get picker name from order
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        -- Send reminder notification
        INSERT INTO notifications (user_id, type, title, message, metadata)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 'Last Reminder: Confirm Receipt'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Please Confirm Your Order'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Final reminder: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will auto-confirm in 12 hours. Confirm now to release payment immediately!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Confirm receipt to release their payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' was delivered. Please confirm receipt when you receive it!'
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
      -- Log error but continue processing
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