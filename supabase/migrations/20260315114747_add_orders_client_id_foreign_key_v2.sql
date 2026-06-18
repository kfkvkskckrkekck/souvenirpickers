/*
  # Add missing foreign key constraint for orders.client_id

  1. Changes
    - Add foreign key constraint from orders.client_id to profiles.id
    - This allows PostgREST API to properly join orders with client profiles
  
  2. Security
    - No changes to RLS policies needed
    - Foreign key ensures referential integrity
*/

-- Drop the constraint if it exists (to handle any inconsistent state)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'orders_client_id_fkey' 
        AND table_name = 'orders'
    ) THEN
        ALTER TABLE orders DROP CONSTRAINT orders_client_id_fkey;
    END IF;
END $$;

-- Add the foreign key constraint
ALTER TABLE orders 
ADD CONSTRAINT orders_client_id_fkey 
FOREIGN KEY (client_id) 
REFERENCES profiles(id) 
ON DELETE CASCADE;

-- Create an index to improve join performance
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
