/*
  # Fix Listing Deletion Constraint

  1. Changes
    - Update the foreign key constraint on orders.listing_id to allow SET NULL on delete
    - This allows pickers to delete listings even if orders exist for them
    - Order history is preserved with all necessary information (price, quantity, etc.)
  
  2. Security
    - No RLS changes needed
    - Maintains data integrity while allowing listing management
*/

-- Drop the existing constraint
ALTER TABLE orders 
DROP CONSTRAINT IF EXISTS orders_listing_id_fkey;

-- Make listing_id nullable if it isn't already (it should be)
ALTER TABLE orders 
ALTER COLUMN listing_id DROP NOT NULL;

-- Recreate the constraint with ON DELETE SET NULL
ALTER TABLE orders 
ADD CONSTRAINT orders_listing_id_fkey 
FOREIGN KEY (listing_id) 
REFERENCES listings(id) 
ON DELETE SET NULL;
