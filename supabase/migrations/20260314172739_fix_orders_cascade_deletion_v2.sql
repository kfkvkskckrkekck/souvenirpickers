/*
  # Fix Orders Table Foreign Key Constraints for User Deletion

  1. Changes
    - Update orders table foreign key constraints to use CASCADE deletion
    - This allows proper cleanup when users delete their accounts
    
  2. Security
    - Maintains existing RLS policies
    - Only affects deletion behavior, not access control
*/

-- Drop existing foreign key constraints
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_picker_id_fkey;

ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_client_id_fkey;

-- Re-add with CASCADE delete
ALTER TABLE orders
  ADD CONSTRAINT orders_picker_id_fkey 
  FOREIGN KEY (picker_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

ALTER TABLE orders
  ADD CONSTRAINT orders_client_id_fkey 
  FOREIGN KEY (client_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;
