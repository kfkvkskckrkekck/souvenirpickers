/*
  # Add Gift and Shipping Quote Fields to Orders Table
  
  ## Overview
  This migration adds missing fields to the orders table to support:
  - Gift orders with recipient information
  - Shipping quote workflow (matching cart_items system)
  - Structured delivery address fields
  
  ## Changes
  
  1. **Gift Order Fields**
    - `is_gift` - Boolean flag for gift orders
    - `gift_recipient_name` - Name of gift recipient
    - `gift_recipient_email` - Email for gift notifications
    - `gift_message` - Personal message from sender
    - `gift_recipient_address` - Formatted delivery address for gift
  
  2. **Shipping Quote Fields**
    - `transportation_cost` - Shipping cost provided by picker
    - `shipping_quote_status` - Tracks quote workflow
    - `shipping_notes` - Picker's notes about shipping
    - `quote_requested_at` - Timestamp when quote requested
    - `quote_provided_at` - Timestamp when quote provided
  
  3. **Structured Address Fields**
    - `delivery_street` - Street address
    - `delivery_street_line2` - Apt/suite number
    - `delivery_city` - City
    - `delivery_postal_code` - Postal/ZIP code
    - `delivery_country` - Country
    - `estimated_weight_kg` - Package weight for quotes
*/

-- Add gift order fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_gift boolean DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS gift_recipient_name text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS gift_recipient_email text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS gift_message text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS gift_recipient_address text;

-- Add shipping quote workflow fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS transportation_cost numeric(10, 2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_quote_status text DEFAULT 'quote_requested';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipping_notes text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS quote_requested_at timestamptz DEFAULT now();
ALTER TABLE orders ADD COLUMN IF NOT EXISTS quote_provided_at timestamptz;

-- Add structured delivery address fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_street text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_street_line2 text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_city text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_postal_code text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_country text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS estimated_weight_kg numeric(5, 2);

-- Add check constraint for valid shipping quote status
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'orders_valid_shipping_quote_status'
  ) THEN
    ALTER TABLE orders 
    ADD CONSTRAINT orders_valid_shipping_quote_status 
    CHECK (shipping_quote_status IN ('quote_requested', 'quote_provided', 'quote_approved', 'no_quote_needed'));
  END IF;
END $$;

-- Create index for pickers to find orders needing quotes
CREATE INDEX IF NOT EXISTS idx_orders_quote_requests 
ON orders(shipping_quote_status, picker_id) 
WHERE shipping_quote_status = 'quote_requested';

-- Create notification trigger when picker provides shipping quote
CREATE OR REPLACE FUNCTION notify_collector_of_order_quote_provided()
RETURNS TRIGGER AS $$
DECLARE
  v_listing_title text;
  v_picker_name text;
BEGIN
  -- Only send notification when status changes to 'quote_provided'
  IF NEW.shipping_quote_status = 'quote_provided' 
     AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_provided') THEN
    
    -- Get listing title
    SELECT title INTO v_listing_title
    FROM listings
    WHERE id = NEW.listing_id;
    
    -- Get picker name
    SELECT full_name INTO v_picker_name
    FROM profiles
    WHERE id = NEW.picker_id;
    
    -- Create notification for collector
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'shipping_quote_provided',
      'Shipping Quote Ready',
      v_picker_name || ' has provided a shipping quote for your order: €' || COALESCE(NEW.transportation_cost::text, '0'),
      jsonb_build_object(
        'order_id', NEW.id,
        'listing_id', NEW.listing_id,
        'transportation_cost', NEW.transportation_cost,
        'shipping_notes', NEW.shipping_notes
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for order quote notifications
DROP TRIGGER IF EXISTS order_quote_provided_notification ON orders;
CREATE TRIGGER order_quote_provided_notification
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_collector_of_order_quote_provided();