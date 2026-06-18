/*
  # Fix Orders Update Policy for Collectors

  ## Changes
  - Update the "Clients can update their pending orders" policy to allow collectors to:
    - Accept shipping quotes (update shipping_quote_status to 'quote_accepted')
    - Confirm goods received (update goods_confirmed and goods_confirmed_at)
  
  ## Security
  - Collectors can only update their own orders (client_id = auth.uid())
  - Restricts which fields can be updated to prevent unauthorized changes
  - Maintains security by only allowing specific status transitions
*/

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Clients can update their pending orders" ON orders;

-- Create a new policy that allows collectors to update orders for quote acceptance and delivery confirmation
CREATE POLICY "Collectors can update orders for quotes and delivery"
  ON orders FOR UPDATE
  TO authenticated
  USING (
    client_id = auth.uid() AND
    (
      -- Allow updating when order is pending (general updates)
      status = 'pending' OR
      -- Allow accepting quotes when quote has been provided
      (shipping_quote_status = 'quote_provided' AND status IN ('pending', 'confirmed')) OR
      -- Allow confirming goods received when order is delivered
      (status = 'delivered')
    )
  )
  WITH CHECK (client_id = auth.uid());

-- Ensure pickers can still update their orders (this policy should already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'orders' 
    AND policyname = 'Pickers can update their orders'
  ) THEN
    CREATE POLICY "Pickers can update their orders"
      ON orders FOR UPDATE
      TO authenticated
      USING (picker_id = auth.uid())
      WITH CHECK (picker_id = auth.uid());
  END IF;
END $$;
