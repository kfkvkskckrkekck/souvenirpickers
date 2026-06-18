/*
  # Add Transportation Cost to Listings

  1. Changes
    - Add `transportation_cost` column to listings table
    - Add `base_price` column to track the item price separately from transportation
    - The `price` column will remain as the total price (base + transportation)
    
  2. Notes
    - Transportation cost helps collectors understand pricing breakdown
    - Base price is the item cost without transportation
    - Total price (existing price field) = base_price + transportation_cost
    - All fields are nullable to support existing listings
*/

-- Add transportation cost and base price columns
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS transportation_cost decimal(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_price decimal(10,2);

-- For existing listings, set base_price equal to current price and transportation to 0
UPDATE listings 
SET base_price = price, 
    transportation_cost = 0
WHERE base_price IS NULL;

-- Add a comment to explain the pricing structure
COMMENT ON COLUMN listings.base_price IS 'The base cost of the item/service without transportation';
COMMENT ON COLUMN listings.transportation_cost IS 'Estimated transportation cost to acquire and deliver the item';
COMMENT ON COLUMN listings.price IS 'Total price (base_price + transportation_cost)';
