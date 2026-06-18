/*
  # Fix trigger_collector_delivery_reminders Function

  ## Changes
  - Update function to use correct column name `goods_received` instead of `goods_confirmed`
  - This was causing order creation to fail
*/

CREATE OR REPLACE FUNCTION public.trigger_collector_delivery_reminders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Create reminders when order is paid and in progress
  IF NEW.status = 'in_progress' 
     AND NEW.payment_status = 'paid' 
     AND (OLD.payment_status IS NULL OR OLD.payment_status != 'paid') THEN
    PERFORM create_collector_delivery_reminders(NEW.id);
  END IF;

  -- Cancel reminders if delivery is confirmed
  IF (NEW.status = 'delivered' OR NEW.goods_received = true) 
     AND (OLD.status != 'delivered' AND COALESCE(OLD.goods_received, false) = false) THEN
    UPDATE reminder_queue
    SET cancelled = true, cancelled_at = now()
    WHERE related_id = NEW.id
      AND sent = false
      AND cancelled = false
      AND reminder_type = 'collector_confirm_delivery';
  END IF;

  RETURN NEW;
END;
$$;