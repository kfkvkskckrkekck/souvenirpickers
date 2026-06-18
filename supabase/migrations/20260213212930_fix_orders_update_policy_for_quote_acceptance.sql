/*
  # Fix Orders Update Policy for Quote Acceptance
  
  1. Changes
    - Update the "Clients can update their pending orders" policy to allow updates when status is 'awaiting_payment'
    - This allows clients to accept shipping quotes and proceed with payment
  
  2. Security
    - Still restricts updates to the client who owns the order
    - Only allows updates for orders in pending or awaiting_payment status
*/

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Clients can update their pending orders" ON orders;

-- Create new policy that allows clients to update pending AND awaiting_payment orders
CREATE POLICY "Clients can update their pending and quoted orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (
    (client_id = auth.uid()) 
    AND (status IN ('pending', 'awaiting_payment'))
  )
  WITH CHECK (client_id = auth.uid());
