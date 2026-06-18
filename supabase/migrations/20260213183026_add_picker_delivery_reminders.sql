/*
  # Add Picker Delivery Status Reminders

  1. New Functionality
    - Remind pickers to mark orders as delivered
    - Triggers when order is in 'in_progress' for more than 2 days
    - Sends reminders at 48h, 72h, and 96h

  2. Benefits
    - Encourages pickers to update order status
    - Helps collectors know when to confirm receipt
    - Improves payment processing speed
    - Maintains accurate order tracking

  3. Flow
    - Order created and paid → status becomes 'in_progress'
    - After 48 hours: First reminder to picker
    - After 72 hours: Second reminder
    - After 96 hours: Final reminder
    - Collector can still confirm receipt regardless
*/

-- Function to create picker delivery reminders
CREATE OR REPLACE FUNCTION create_picker_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_order_created timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as client_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.client_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already delivered
  IF v_order.status = 'delivered' OR v_order.actual_delivery IS NOT NULL THEN
    RETURN;
  END IF;

  -- Use order creation time
  v_order_created := v_order.created_at;

  -- Cancel any existing picker reminders for this order
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'picker_mark_delivered';

  -- Schedule reminders at 48, 72, and 96 hours after order creation
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'picker_mark_delivered',
      v_order.picker_id,
      p_order_id,
      v_order_created + INTERVAL '48 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'client_name', v_order.client_name,
        'reminder_number', 1
      )
    ),
    (
      'picker_mark_delivered',
      v_order.picker_id,
      p_order_id,
      v_order_created + INTERVAL '72 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'client_name', v_order.client_name,
        'reminder_number', 2
      )
    ),
    (
      'picker_mark_delivered',
      v_order.picker_id,
      p_order_id,
      v_order_created + INTERVAL '96 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'client_name', v_order.client_name,
        'reminder_number', 3
      )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create picker reminders when order enters in_progress
CREATE OR REPLACE FUNCTION trigger_picker_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Create reminders when order becomes in_progress
  IF NEW.status = 'in_progress' 
     AND NEW.payment_status = 'paid' 
     AND (OLD.status IS NULL OR OLD.status != 'in_progress') THEN
    PERFORM create_picker_delivery_reminders(NEW.id);
  END IF;

  -- Cancel reminders if order is marked as delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    UPDATE reminder_queue
    SET cancelled = true, cancelled_at = now()
    WHERE related_id = NEW.id
      AND sent = false
      AND cancelled = false
      AND reminder_type = 'picker_mark_delivered';
  END IF;

  -- Cancel reminders if goods are confirmed (collector confirmed)
  IF NEW.goods_confirmed = true AND (OLD.goods_confirmed IS NULL OR OLD.goods_confirmed = false) THEN
    UPDATE reminder_queue
    SET cancelled = true, cancelled_at = now()
    WHERE related_id = NEW.id
      AND sent = false
      AND cancelled = false
      AND reminder_type = 'picker_mark_delivered';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS on_order_picker_reminders ON orders;
CREATE TRIGGER on_order_picker_reminders
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_picker_delivery_reminders();

-- Update process_pending_reminders to handle picker reminders
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
  v_client_name text;
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
      -- Handle delivery confirmation reminders (for collectors)
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⏰ Last Reminder: Confirm Receipt'
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
      
      -- Handle picker delivery status reminders
      ELSIF v_reminder.reminder_type = 'picker_mark_delivered' THEN
        SELECT p.full_name INTO v_client_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.client_id
        WHERE o.id = v_reminder.related_id;

        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'picker_delivery_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⚠️ Important: Update Order Status'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Mark Order as Delivered'
            ELSE 'Have You Delivered This Order?'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Please update the status of the order for ' || COALESCE(v_client_name, 'the collector') || 
              '. If you''ve delivered it, mark it as delivered so the collector can confirm and you can get paid faster!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Don''t forget to mark your order for ' || COALESCE(v_client_name, 'the collector') || 
              ' as delivered once you ship/deliver it. This helps speed up your payment!'
            ELSE 
              'Have you delivered the order to ' || COALESCE(v_client_name, 'the collector') || 
              '? If so, please mark it as delivered in the Orders page.'
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
GRANT EXECUTE ON FUNCTION create_picker_delivery_reminders(uuid) TO authenticated;

COMMENT ON FUNCTION create_picker_delivery_reminders(uuid) IS 
  'Creates reminder notifications for pickers to mark orders as delivered';
