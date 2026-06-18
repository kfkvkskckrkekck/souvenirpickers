/*
  # Consolidate Orders Update Policies for Collectors

  ## Changes
  - Remove duplicate and conflicting update policies for collectors
  - Create a single comprehensive policy that allows all necessary updates
  
  ## Security
  - Collectors can only update their own orders (client_id = auth.uid())
  - Allows updates for all necessary order statuses
*/

-- Drop all existing collector/client update policies
DROP POLICY IF EXISTS "Clients can update their pending orders" ON orders;
DROP POLICY IF EXISTS "Clients can update their pending and quoted orders" ON orders;
DROP POLICY IF EXISTS "Collectors can update orders for quotes and delivery" ON orders;

-- Create a single comprehensive policy for collector updates
CREATE POLICY "Collectors can update their orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());
