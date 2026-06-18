/*
  # Create Reminder Queue Table

  1. New Table
    - `reminder_queue` - Tracks scheduled reminders to be sent
    
  2. New Functions
    - `cancel_order_reminders()` - Cancels reminders for an order
    - `create_delivery_reminders()` - Schedules reminders when order is delivered
    
  3. New Triggers
    - Automatically creates reminders when order status changes to 'delivered'
    
  4. Security
    - Enable RLS on reminder_queue table
    - Add policy for users to view own reminders
*/

-- Create reminder queue table
CREATE TABLE IF NOT EXISTS reminder_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_type text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  related_id uuid,
  scheduled_for timestamptz NOT NULL,
  sent boolean DEFAULT false,
  sent_at timestamptz,
  cancelled boolean DEFAULT false,
  cancelled_at timestamptz,
  data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_reminder_queue_scheduled 
  ON reminder_queue(scheduled_for) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_user 
  ON reminder_queue(user_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_related 
  ON reminder_queue(related_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

-- Enable RLS
ALTER TABLE reminder_queue ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view own reminders"
  ON reminder_queue FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Function to cancel reminders for an order
CREATE OR REPLACE FUNCTION cancel_order_reminders(p_order_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'delivery_confirmation';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create delivery confirmation reminders
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

  -- Send immediate notification about delivery
  INSERT INTO notifications (user_id, type, title, message, data)
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

-- Trigger to create reminders when order is delivered
CREATE OR REPLACE FUNCTION trigger_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if status changed to delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Check if goods not already confirmed
    IF NOT COALESCE(NEW.goods_confirmed, false) THEN
      PERFORM create_delivery_reminders(NEW.id);
    END IF;
  END IF;

  -- Cancel reminders if goods are confirmed
  IF NEW.goods_confirmed = true AND (OLD.goods_confirmed IS NULL OR OLD.goods_confirmed = false) THEN
    PERFORM cancel_order_reminders(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS on_order_delivered ON orders;
CREATE TRIGGER on_order_delivered
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_delivery_reminders();

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_delivery_reminders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_order_reminders(uuid) TO authenticated;