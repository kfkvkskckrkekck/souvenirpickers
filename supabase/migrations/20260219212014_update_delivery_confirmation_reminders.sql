/*
  # Update Delivery Confirmation Reminder Schedule

  1. Changes
    - Better reminder schedule based on shipping timeline
    - Reminders at 3, 7, 10, and 12 days after shipping
    - Final urgent reminder at 12 days (2 days before auto-release)
    - Clear messaging about auto-release

  2. Why
    - Give collectors time for international shipping
    - But remind them before auto-release happens
    - Make it clear what happens if they don't respond
*/

-- Update the reminder creation function with better schedule
CREATE OR REPLACE FUNCTION create_collector_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_shipped_at timestamptz;
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

  -- Use shipping date if available, otherwise order creation date
  v_shipped_at := COALESCE(v_order.shipped_at, v_order.created_at);

  -- Cancel any existing reminders for this order
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'collector_confirm_delivery';

  -- Schedule reminders at strategic times after shipping
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    -- Day 3: Gentle reminder
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_shipped_at + INTERVAL '3 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1,
        'urgency', 'low'
      )
    ),
    -- Day 7: Standard reminder
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_shipped_at + INTERVAL '7 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2,
        'urgency', 'medium'
      )
    ),
    -- Day 10: Important reminder
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_shipped_at + INTERVAL '10 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3,
        'urgency', 'high',
        'days_until_auto_release', 4
      )
    ),
    -- Day 12: Urgent - Auto-release in 2 days!
    (
      'collector_confirm_delivery',
      v_order.client_id,
      p_order_id,
      v_shipped_at + INTERVAL '12 days',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 4,
        'urgency', 'urgent',
        'days_until_auto_release', 2
      )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update reminder processing with better messages
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
  v_urgency text;
BEGIN
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
      IF v_reminder.reminder_type = 'collector_confirm_delivery' THEN
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        v_urgency := COALESCE(v_reminder.data->>'urgency', 'medium');

        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN v_urgency = 'urgent' THEN '⚠️ URGENT: Confirm Delivery in 2 Days'
            WHEN v_urgency = 'high' THEN 'Important: Confirm Your Delivery'
            WHEN v_urgency = 'medium' THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Have You Received Your Order?'
          END,
          CASE 
            WHEN v_urgency = 'urgent' THEN 
              'IMPORTANT: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will be automatically confirmed in 2 days if you don''t respond. If there are any issues with your order, please contact support NOW. Otherwise, please confirm delivery so the picker can receive payment.'
            WHEN v_urgency = 'high' THEN 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will be automatically confirmed in 4 days if no issues are reported. Please confirm delivery if you''ve received it, or contact support if there are problems.'
            WHEN v_urgency = 'medium' THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Please confirm delivery so they can receive payment. If you haven''t received it yet, no action needed - this is just a reminder.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' should be arriving soon. Please confirm when you receive it!'
          END,
          v_reminder.data
        );
      END IF;

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

-- Update trigger to use shipped_at when available
CREATE OR REPLACE FUNCTION trigger_collector_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Create reminders when order is shipped
  IF NEW.shipped_at IS NOT NULL 
     AND (OLD.shipped_at IS NULL OR OLD.shipped_at != NEW.shipped_at) THEN
    PERFORM create_collector_delivery_reminders(NEW.id);
  END IF;

  -- Cancel reminders if delivery is confirmed
  IF (NEW.status = 'delivered' OR NEW.goods_confirmed = true) 
     AND (OLD IS NULL OR (OLD.status != 'delivered' AND COALESCE(OLD.goods_confirmed, false) = false)) THEN
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

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_collector_delivery_reminders ON orders;
CREATE TRIGGER on_collector_delivery_reminders
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_collector_delivery_reminders();