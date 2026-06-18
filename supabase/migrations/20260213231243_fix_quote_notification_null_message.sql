/*
  # Fix Quote Acceptance Notification NULL Message Error

  1. Changes
    - Fix notify_picker_quote_accepted function to handle NULL values properly
    - Use COALESCE to ensure message is never NULL

  2. Security
    - Maintains existing SECURITY DEFINER and permissions
*/

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

    -- Get names with fallback values
    SELECT COALESCE(full_name, 'Picker') INTO v_picker_name FROM profiles WHERE id = NEW.picker_id;
    SELECT COALESCE(full_name, 'A collector') INTO v_client_name FROM profiles WHERE id = NEW.client_id;
    SELECT COALESCE(title, 'the item') INTO v_listing_title FROM listings WHERE id = NEW.listing_id;

    -- Notify picker that quote was accepted
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.picker_id,
      'quote_accepted',
      'Shipping Quote Accepted',
      v_client_name || ' accepted your shipping quote of €' || COALESCE(NEW.transportation_cost::text, '0') || ' for ' || v_listing_title,
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'transportation_cost', NEW.transportation_cost,
        'client_name', v_client_name
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the order update
    RAISE WARNING 'Error creating quote acceptance notification: %', SQLERRM;
    RETURN NEW;
END;
$$;