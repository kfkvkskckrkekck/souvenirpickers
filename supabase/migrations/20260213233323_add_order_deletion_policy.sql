/*
  # Add Order Deletion Policy

  1. Changes
    - Add DELETE policy for orders so collectors can cancel unpaid orders
    - Only allows deletion of orders in 'pending' or 'accepted' status with 'pending' payment status

  2. Security
    - Collectors can only delete their own unpaid orders
    - Prevents deletion of paid or in-progress orders
*/

-- Add DELETE policy for orders
DO $$ BEGIN
  DROP POLICY IF EXISTS "Collectors can delete own unpaid orders" ON orders;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

CREATE POLICY "Collectors can delete own unpaid orders"
  ON orders
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = client_id 
    AND status IN ('pending', 'accepted')
    AND payment_status = 'pending'
  );
