/*
  # Fix Orders Status Constraint

  1. Changes
    - Drop the existing check constraint on orders.status
    - Add new check constraint that includes 'pending' status
    - The database has a default of 'pending' but the constraint was missing this value
  
  2. Reason
    - Orders were failing to be created because the default status 'pending' was not in the allowed values list
    - This caused a constraint violation error when inserting new orders
*/

-- Drop the existing constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Add new constraint with 'pending' included
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'unpaid'::text, 
    'paid'::text, 
    'accepted'::text, 
    'processing'::text, 
    'shipped'::text, 
    'received'::text, 
    'cancelled'::text, 
    'refunded'::text
  ]));