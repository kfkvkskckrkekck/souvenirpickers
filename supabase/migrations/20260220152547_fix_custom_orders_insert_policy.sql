/*
  # Fix Custom Orders Insert Policy
  
  1. Changes
    - Drop the incorrect "Clients can create custom orders" policy
    - Add correct "Pickers can create custom orders" policy
    - Pickers create custom orders and send them TO clients
    
  2. Security
    - Only pickers can create custom orders
    - They must be the picker_id in the record
*/

-- Drop the incorrect policy
DROP POLICY IF EXISTS "Clients can create custom orders" ON custom_orders;

-- Create the correct policy: Pickers create orders for clients
CREATE POLICY "Pickers can create custom orders"
  ON custom_orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);
