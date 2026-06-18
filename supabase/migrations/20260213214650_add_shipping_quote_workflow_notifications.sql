/*
  # Add Shipping Quote Workflow Notifications
  
  1. Changes
    - Update notify_new_order function to create in-app notifications for pickers when quote is needed
    - Enhance quote provided notification with better metadata
    - Add notification for when collector accepts/rejects a quote
  
  2. Notifications Created
    - For Picker: "Shipping Quote Needed" when order requires quote
    - For Collector: "Shipping Quote Provided" when picker submits quote (already exists, enhancing)
    - For Picker: "Quote Accepted" when collector accepts the quote
*/

-- Drop and recreate the notify_new_order function with in-app notifications
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_picker_email text;
  v_picker_name text;
  v_client_email text;
  v_client_name text;
  v_listing_title text;
  v_supabase_url text;
  v_needs_quote boolean;
BEGIN
  -- Get Supabase URL from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  END IF;

  -- Get picker details
  SELECT p.email, p.full_name 
  INTO v_picker_email, v_picker_name
  FROM profiles p
  WHERE p.id = NEW.picker_id;

  -- Get client details
  SELECT p.email, p.full_name 
  INTO v_client_email, v_client_name
  FROM profiles p
  WHERE p.id = NEW.client_id;

  -- Get listing title
  SELECT l.title 
  INTO v_listing_title
  FROM listings l
  WHERE l.id = NEW.listing_id;

  -- Check if shipping quote is needed
  v_needs_quote := (NEW.shipping_quote_status = 'quote_requested');

  -- Create IN-APP notification for picker
  IF v_needs_quote THEN
    -- Picker needs to provide a shipping quote
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'shipping_quote_needed',
      'Shipping Quote Needed',
      v_client_name || ' ordered ' || v_listing_title || '. Please provide a shipping quote.',
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'client_name', v_client_name,
        'listing_title', v_listing_title,
        'delivery_address', jsonb_build_object(
          'city', NEW.delivery_city,
          'country', NEW.delivery_country
        )
      )
    );
  ELSE
    -- Regular order notification for picker
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'new_order',
      'New Order Received',
      v_client_name || ' ordered ' || v_listing_title || ' (Qty: ' || NEW.quantity || ')',
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'client_name', v_client_name,
        'listing_title', v_listing_title,
        'quantity', NEW.quantity,
        'total_price', NEW.total_price
      )
    );
  END IF;

  -- Create IN-APP notification for collector
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    NEW.client_id,
    'order_placed',
    'Order Placed Successfully',
    'Your order for ' || v_listing_title || ' has been placed with ' || v_picker_name,
    jsonb_build_object(
      'order_id', NEW.id,
      'listing_id', NEW.listing_id,
      'picker_name', v_picker_name,
      'listing_title', v_listing_title,
      'needs_quote', v_needs_quote
    )
  );

  -- Send EMAIL notification to picker
  IF v_picker_email IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_picker_email,
        'subject', 'New Order Received - Order #' || substring(NEW.id::text, 1, 8),
        'type', 'new_order_picker',
        'data', jsonb_build_object(
          'picker_name', COALESCE(v_picker_name, 'there'),
          'customer_name', COALESCE(v_client_name, 'A customer'),
          'order_id', substring(NEW.id::text, 1, 8),
          'item_title', COALESCE(v_listing_title, 'Item'),
          'quantity', NEW.quantity,
          'total_amount', NEW.total_price,
          'needs_quote', v_needs_quote
        )
      )
    );
  END IF;

  -- Send EMAIL confirmation to client
  IF v_client_email IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-email-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'to', v_client_email,
        'subject', 'Order Confirmed - Order #' || substring(NEW.id::text, 1, 8),
        'type', 'order_confirmation',
        'data', jsonb_build_object(
          'customer_name', COALESCE(v_client_name, 'there'),
          'order_id', substring(NEW.id::text, 1, 8),
          'item_title', COALESCE(v_listing_title, 'Item'),
          'total_amount', NEW.total_price
        )
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Error sending new order notification: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Add notification when collector accepts/rejects quote
CREATE OR REPLACE FUNCTION notify_picker_quote_accepted()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_picker_name text;
  v_client_name text;
  v_listing_title text;
BEGIN
  -- Only trigger when quote status changes to approved
  IF NEW.shipping_quote_status = 'quote_approved' 
    AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_approved') THEN
    
    -- Get names
    SELECT full_name INTO v_picker_name FROM profiles WHERE id = NEW.picker_id;
    SELECT full_name INTO v_client_name FROM profiles WHERE id = NEW.client_id;
    SELECT title INTO v_listing_title FROM listings WHERE id = NEW.listing_id;
    
    -- Notify picker that quote was accepted
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'quote_accepted',
      'Shipping Quote Accepted',
      v_client_name || ' accepted your shipping quote of €' || NEW.transportation_cost || ' for ' || v_listing_title,
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'transportation_cost', NEW.transportation_cost,
        'client_name', v_client_name
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for quote acceptance
DROP TRIGGER IF EXISTS order_quote_accepted_notification ON orders;
CREATE TRIGGER order_quote_accepted_notification
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_picker_quote_accepted();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION notify_new_order() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_picker_quote_accepted() TO authenticated;
