/*
  # Fix Notification Functions - Remove app.base_url Configuration

  1. Problem
    - Functions try to use current_setting('app.base_url') which is not configured
    - This causes error when sending notifications
  
  2. Changes
    - Update all notification functions to use hardcoded URL or remove URL references
    - Replace current_setting('app.base_url') with 'https://souvenirpickers.com'
  
  3. Notes
    - Using production domain directly
    - Can be updated later if needed
*/

-- Fix notify_collector_pay_now function
CREATE OR REPLACE FUNCTION notify_collector_pay_now()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_title TEXT;
BEGIN
  -- Only trigger when quote is provided (transportation_cost is set)
  IF NEW.transportation_cost IS NOT NULL AND (OLD.transportation_cost IS NULL OR OLD.transportation_cost != NEW.transportation_cost) THEN
    
    -- Get listing title
    SELECT title INTO v_item_title
    FROM listings
    WHERE id = NEW.listing_id;

    -- COLLECTOR ACTION REQUIRED: Pay Now
    PERFORM send_order_notification_simple(
      NEW.client_id,
      'order',
      'Ready to Pay - Quote Received',
      'Shipping quote ready: $' || NEW.transportation_cost::text || '. Total: $' || (NEW.total_price + NEW.transportation_cost)::text,
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Pay Now'
      ),
      'Ready to Pay - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      'Your shipping quote is ready!' || E'\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Item Price: $' || NEW.total_price::text || E'\n' ||
      'Shipping: $' || NEW.transportation_cost::text || E'\n' ||
      'TOTAL: $' || (NEW.total_price + NEW.transportation_cost)::text || E'\n\n' ||
      '→ ACTION REQUIRED: Pay now to complete your order' || E'\n\n' ||
      'Pay now: https://souvenirpickers.com/orders'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Fix notify_collector_of_order_quote_provided function
CREATE OR REPLACE FUNCTION notify_collector_of_order_quote_provided()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_title TEXT;
BEGIN
  -- Only fire when shipping quote is newly provided
  IF NEW.transportation_cost IS NOT NULL 
     AND NEW.shipping_quote_status = 'quote_provided'
     AND (OLD.transportation_cost IS NULL OR OLD.shipping_quote_status != 'quote_provided') THEN
    
    -- Get item title from listing
    SELECT title INTO v_item_title
    FROM listings
    WHERE id = NEW.listing_id;
    
    -- Send notification to collector
    PERFORM send_order_notification_simple(
      NEW.client_id,
      'order',
      'Shipping Quote Ready',
      'Your picker provided a shipping quote: $' || NEW.transportation_cost::text || '. Review and pay to proceed.',
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'Review Quote & Pay Now'
      ),
      'Your Shipping Quote is Ready - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'Great news! Your picker has provided a shipping quote for your order.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Item Price: $' || NEW.total_price::text || E'\n' ||
      'Shipping Cost: $' || NEW.transportation_cost::text || E'\n' ||
      'Total: $' || (NEW.total_price + NEW.transportation_cost)::text || E'\n\n' ||
      'NEXT STEP: Review the quote and proceed to payment.\n\n' ||
      'Click here to review and pay: https://souvenirpickers.com/orders'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Also fix other notification functions that might use app.base_url
CREATE OR REPLACE FUNCTION notify_picker_quote_canceled()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_title TEXT;
BEGIN
  -- Only fire when shipping quote is canceled
  IF NEW.shipping_quote_status = 'canceled' 
     AND OLD.shipping_quote_status != 'canceled' THEN
    
    -- Get item title from listing
    SELECT title INTO v_item_title
    FROM listings
    WHERE id = NEW.listing_id;
    
    -- Send notification to picker
    PERFORM send_order_notification_simple(
      NEW.picker_id,
      'order',
      'Shipping Quote Canceled',
      'The collector has canceled the shipping quote for order #' || NEW.id::text,
      jsonb_build_object(
        'order_id', NEW.id,
        'action_url', '/orders',
        'action_text', 'View Order'
      ),
      'Shipping Quote Canceled - ' || COALESCE(v_item_title, 'Order #' || NEW.id::text),
      E'The collector has canceled the shipping quote for this order.\n\n' ||
      'Item: ' || COALESCE(v_item_title, 'Your order') || E'\n' ||
      'Order ID: ' || NEW.id::text || E'\n\n' ||
      'View order details: https://souvenirpickers.com/orders'
    );
  END IF;

  RETURN NEW;
END;
$$;