/*
  # Fix orders.picker_id to reference profiles instead of picker_profiles

  1. Changes
    - Drop old foreign key constraint first
    - Update all existing orders to use profiles.id instead of picker_profiles.id
    - Add new foreign key constraint pointing to profiles table
  
  2. Security
    - No changes to RLS policies needed
    - Maintains referential integrity
*/

-- Drop the old foreign key that points to picker_profiles FIRST
ALTER TABLE orders 
DROP CONSTRAINT IF EXISTS orders_picker_id_fkey;

-- Update all existing orders to use the correct picker_id (profiles.id)
-- This updates orders where picker_id is currently a picker_profiles.id
UPDATE orders o
SET picker_id = pp.user_id
FROM picker_profiles pp
WHERE o.picker_id = pp.id;

-- Add the new foreign key that points to profiles
ALTER TABLE orders 
ADD CONSTRAINT orders_picker_id_fkey 
FOREIGN KEY (picker_id) 
REFERENCES profiles(id) 
ON DELETE CASCADE;

-- Create an index to improve join performance
CREATE INDEX IF NOT EXISTS idx_orders_picker_id ON orders(picker_id);
