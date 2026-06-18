/*
  # Add base_price column to listings table
  
  1. Changes
    - Add `base_price` column to listings table to store the item cost separately from transportation
    - Set default value to match the total price for existing listings
    - Add check constraint to ensure base_price is non-negative
  
  2. Notes
    - Existing listings will have base_price set equal to their current price
    - New listings can specify base_price and transportation_cost separately
*/

-- Add base_price column to listings table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'listings' AND column_name = 'base_price'
  ) THEN
    ALTER TABLE listings 
    ADD COLUMN base_price numeric DEFAULT 0 CHECK (base_price >= 0);
    
    -- Update existing listings to set base_price to current price minus transportation_cost
    UPDATE listings 
    SET base_price = GREATEST(price - COALESCE(transportation_cost, 0), 0)
    WHERE base_price = 0;
  END IF;
END $$;