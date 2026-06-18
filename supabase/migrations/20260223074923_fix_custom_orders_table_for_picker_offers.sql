/*
  # Fix Custom Orders Table for Picker-Created Offers
  
  1. Changes
    - Add columns needed for picker-created custom order offers:
      - base_price (item price)
      - transportation_cost (shipping/delivery cost)
      - total_price (base_price + transportation_cost)
      - quantity (number of items)
      - images (product images)
      - delivery_address (suggested delivery location)
      - notes (additional information)
      - expires_at (offer expiration timestamp)
      - accepted_at (when collector accepted)
      - order_id (link to created order when accepted)
    
  2. Notes
    - Existing columns (category, region, budget, reference_images, reference_links) are kept for backward compatibility
    - Status values: 'pending', 'accepted', 'rejected', 'expired'
    - Custom orders expire 48 hours after creation
*/

-- Add new columns for picker-created custom order offers
ALTER TABLE custom_orders
  ADD COLUMN IF NOT EXISTS base_price numeric(10,2),
  ADD COLUMN IF NOT EXISTS transportation_cost numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_price numeric(10,2),
  ADD COLUMN IF NOT EXISTS quantity integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS images text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS delivery_address text,
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES orders(id);

-- Update status column to use more specific values
DO $$
BEGIN
  ALTER TABLE custom_orders
    DROP CONSTRAINT IF EXISTS custom_orders_status_check;
  
  ALTER TABLE custom_orders
    ADD CONSTRAINT custom_orders_status_check
    CHECK (status IN ('pending', 'accepted', 'rejected', 'expired', 'open'));
END $$;

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_custom_orders_expires_at ON custom_orders(expires_at);
CREATE INDEX IF NOT EXISTS idx_custom_orders_order_id ON custom_orders(order_id);

-- Update existing records to set default expires_at (48 hours from creation)
UPDATE custom_orders
SET expires_at = created_at + interval '48 hours'
WHERE expires_at IS NULL;

-- Update existing records status from 'open' to 'pending'
UPDATE custom_orders
SET status = 'pending'
WHERE status = 'open';