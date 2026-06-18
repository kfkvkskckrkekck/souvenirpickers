/*
  # Add Shipping Quote Workflow to Cart System
  
  ## Overview
  This migration transforms the cart system to support a shipping quote workflow where:
  1. Collectors add items to cart and provide delivery address
  2. Collectors request shipping quotes from pickers
  3. Pickers get actual quotes from couriers and update cart items
  4. Collectors review and proceed to checkout with accurate costs
  
  ## Changes
  
  1. **Cart Items Table**
    - Add `transportation_cost` (nullable, set by picker after getting quote)
    - Add `shipping_quote_status` (tracks quote workflow)
    - Add `shipping_notes` (picker adds quote details/instructions)
    - Add `quote_requested_at` (timestamp when collector requests quote)
    - Add `quote_provided_at` (timestamp when picker provides quote)
    - Add structured delivery address fields for accurate quoting
    
  2. **Status Values**
    - `no_quote_needed` - Collector hasn't requested a quote yet
    - `quote_requested` - Collector requested shipping quote
    - `quote_provided` - Picker provided shipping cost
    - `quote_expired` - Quote needs to be updated (optional)
    
  3. **RLS Policies**
    - Collectors can view and update their cart items
    - Pickers can view cart items for their listings and update shipping costs
*/

-- Add new columns to cart_items table
DO $$ 
BEGIN
  -- Transportation cost (set by picker after getting real quote)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'transportation_cost'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN transportation_cost numeric(10, 2);
  END IF;
  
  -- Shipping quote status
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'shipping_quote_status'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN shipping_quote_status text DEFAULT 'no_quote_needed';
  END IF;
  
  -- Shipping notes from picker
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'shipping_notes'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN shipping_notes text;
  END IF;
  
  -- Timestamps for quote workflow
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'quote_requested_at'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN quote_requested_at timestamptz;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'quote_provided_at'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN quote_provided_at timestamptz;
  END IF;
  
  -- Structured delivery address fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'delivery_street'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN delivery_street text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'delivery_street_line2'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN delivery_street_line2 text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'delivery_city'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN delivery_city text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'delivery_postal_code'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN delivery_postal_code text;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'delivery_country'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN delivery_country text;
  END IF;
  
  -- Package weight (for accurate shipping quotes)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'estimated_weight_kg'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN estimated_weight_kg numeric(5, 2);
  END IF;
END $$;

-- Add check constraint for valid shipping quote status
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'valid_shipping_quote_status'
  ) THEN
    ALTER TABLE cart_items 
    ADD CONSTRAINT valid_shipping_quote_status 
    CHECK (shipping_quote_status IN ('no_quote_needed', 'quote_requested', 'quote_provided', 'quote_expired'));
  END IF;
END $$;

-- Create index for pickers to find cart items needing quotes
CREATE INDEX IF NOT EXISTS idx_cart_items_quote_requests 
ON cart_items(shipping_quote_status) 
WHERE shipping_quote_status = 'quote_requested';

-- Update RLS policies for pickers to view and update shipping quotes

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pickers can view cart items for their listings" ON cart_items;
DROP POLICY IF EXISTS "Pickers can update shipping costs for their listings" ON cart_items;

-- Allow pickers to view cart items containing their listings
CREATE POLICY "Pickers can view cart items for their listings"
  ON cart_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM listings
      WHERE listings.id = cart_items.listing_id
      AND listings.picker_id IN (
        SELECT id FROM picker_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Allow pickers to update shipping costs and notes for their listings
CREATE POLICY "Pickers can update shipping costs for their listings"
  ON cart_items
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM listings
      WHERE listings.id = cart_items.listing_id
      AND listings.picker_id IN (
        SELECT id FROM picker_profiles WHERE user_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM listings
      WHERE listings.id = cart_items.listing_id
      AND listings.picker_id IN (
        SELECT id FROM picker_profiles WHERE user_id = auth.uid()
      )
    )
  );

-- Create a notification trigger when collector requests a quote
CREATE OR REPLACE FUNCTION notify_picker_of_quote_request()
RETURNS TRIGGER AS $$
DECLARE
  v_picker_user_id uuid;
  v_listing_title text;
  v_collector_name text;
BEGIN
  -- Only send notification when status changes to 'quote_requested'
  IF NEW.shipping_quote_status = 'quote_requested' 
     AND (OLD.shipping_quote_status IS NULL OR OLD.shipping_quote_status != 'quote_requested') THEN
    
    -- Get picker user_id and listing title
    SELECT pp.user_id, l.title
    INTO v_picker_user_id, v_listing_title
    FROM listings l
    JOIN picker_profiles pp ON l.picker_id = pp.id
    WHERE l.id = NEW.listing_id;
    
    -- Get collector name
    SELECT full_name INTO v_collector_name
    FROM profiles
    WHERE id = NEW.client_id;
    
    -- Create notification for picker
    IF v_picker_user_id IS NOT NULL THEN
      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        v_picker_user_id,
        'shipping_quote_request',
        'Shipping Quote Requested',
        v_collector_name || ' has requested a shipping quote for ' || v_listing_title,
        jsonb_build_object(
          'cart_item_id', NEW.id,
          'listing_id', NEW.listing_id,
          'collector_id', NEW.client_id,
          'destination_city', NEW.delivery_city,
          'destination_country', NEW.delivery_country
        )
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for quote request notifications
DROP TRIGGER IF EXISTS cart_item_quote_request_notification ON cart_items;
CREATE TRIGGER cart_item_quote_request_notification
  AFTER UPDATE ON cart_items
  FOR EACH ROW
  EXECUTE FUNCTION notify_picker_of_quote_request();

-- Create a notification trigger when picker provides a quote
CREATE OR REPLACE FUNCTION notify_collector_of_quote_provided()
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
    SELECT p.full_name
    INTO v_picker_name
    FROM picker_profiles pp
    JOIN profiles p ON pp.user_id = p.id
    JOIN listings l ON l.picker_id = pp.id
    WHERE l.id = NEW.listing_id;
    
    -- Create notification for collector
    INSERT INTO notifications (user_id, type, title, message, metadata)
    VALUES (
      NEW.client_id,
      'shipping_quote_provided',
      'Shipping Quote Provided',
      v_picker_name || ' has provided a shipping quote for ' || v_listing_title || ': €' || NEW.transportation_cost::text,
      jsonb_build_object(
        'cart_item_id', NEW.id,
        'listing_id', NEW.listing_id,
        'transportation_cost', NEW.transportation_cost,
        'shipping_notes', NEW.shipping_notes
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for quote provided notifications
DROP TRIGGER IF EXISTS cart_item_quote_provided_notification ON cart_items;
CREATE TRIGGER cart_item_quote_provided_notification
  AFTER UPDATE ON cart_items
  FOR EACH ROW
  EXECUTE FUNCTION notify_collector_of_quote_provided();