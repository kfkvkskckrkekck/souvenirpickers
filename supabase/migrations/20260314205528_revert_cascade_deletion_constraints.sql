/*
  # Revert CASCADE Deletion on Orders Table

  Reverting the CASCADE deletion behavior to protect data integrity.
  This ensures user deletion doesn't automatically cascade to orders.

  1. Changes
    - Remove CASCADE deletion from orders foreign keys
    - Restore default RESTRICT behavior
*/

-- Drop CASCADE foreign key constraints
ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_picker_id_fkey;

ALTER TABLE orders 
  DROP CONSTRAINT IF EXISTS orders_client_id_fkey;

-- Re-add without CASCADE (default is RESTRICT)
ALTER TABLE orders
  ADD CONSTRAINT orders_picker_id_fkey 
  FOREIGN KEY (picker_id) 
  REFERENCES auth.users(id);

ALTER TABLE orders
  ADD CONSTRAINT orders_client_id_fkey 
  FOREIGN KEY (client_id) 
  REFERENCES auth.users(id);
