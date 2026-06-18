/*
  # Fix orders picker_id foreign key constraint

  1. Changes
    - Delete orders with invalid picker_id references
    - Drop the incorrect foreign key constraint that references auth.users
    - Add correct foreign key constraint that references picker_profiles
    - This allows orders to properly link to pickers via their picker_profile ID

  2. Why
    - The listings table has picker_id referencing picker_profiles
    - The orders table was incorrectly referencing auth.users
    - This mismatch caused foreign key violations when creating orders
*/

-- Delete orders with invalid picker_id references
DELETE FROM orders 
WHERE picker_id NOT IN (SELECT id FROM picker_profiles);

-- Drop the incorrect foreign key constraint
ALTER TABLE orders 
DROP CONSTRAINT IF EXISTS orders_picker_id_fkey;

-- Add the correct foreign key constraint to picker_profiles
ALTER TABLE orders 
ADD CONSTRAINT orders_picker_id_fkey 
FOREIGN KEY (picker_id) 
REFERENCES picker_profiles(id) 
ON DELETE CASCADE;