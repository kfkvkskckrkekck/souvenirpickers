/*
  # Add Shipping Quote Canceled Notification

  1. Changes
    - Create trigger to notify picker when collector cancels their shipping quote
    - Allows picker to know when they need to provide a new quote

  2. Security
    - Function runs as SECURITY DEFINER with proper authorization
*/

-- Create function to notify picker when shipping quote is canceled
CREATE OR REPLACE FUNCTION notify_picker_quote_canceled()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only notify if shipping quote was canceled (transportation_cost set to null and status changed to pending_quote)
  IF OLD.transportation_cost IS NOT NULL 
     AND NEW.transportation_cost IS NULL 
     AND NEW.shipping_quote_status = 'pending_quote' THEN
    
    -- Insert notification for picker
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      metadata,
      created_at
    )
    VALUES (
      NEW.picker_id,
      'order_update',
      'Shipping Quote Canceled',
      'The collector has canceled your shipping quote. You can provide a new quote if requested.',
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'client_id', NEW.client_id
      ),
      NOW()
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for shipping quote cancellation
DROP TRIGGER IF EXISTS on_shipping_quote_canceled ON orders;
CREATE TRIGGER on_shipping_quote_canceled
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_picker_quote_canceled();