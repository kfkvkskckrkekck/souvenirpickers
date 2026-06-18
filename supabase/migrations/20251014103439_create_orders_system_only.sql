/*
  # Create Orders System

  ## Orders System
  
  1. New Tables
    - `orders`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `picker_id` (uuid, references profiles)
      - `listing_id` (uuid, references listings)
      - `status` (text) - pending, accepted, in_progress, completed, cancelled, refunded
      - `quantity` (integer)
      - `total_price` (decimal)
      - `delivery_address` (text)
      - `delivery_instructions` (text)
      - `payment_status` (text) - pending, paid, refunded
      - `payment_intent_id` (text) - for Stripe integration
      - `notes` (text)
      - `completed_at` (timestamptz)
      - `cancelled_at` (timestamptz)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
    
    - `order_status_history`
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `status` (text)
      - `notes` (text)
      - `changed_by` (uuid, references profiles)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Clients can create orders and view their own orders
    - Pickers can view orders for their listings and update order status
    - Both parties can view order status history for their orders
    
  3. Important Notes
    - Positive quantity and price constraints enforced
    - Status tracking with history for transparency
    - Payment integration ready with Stripe fields
    - Timestamps for completed and cancelled orders
*/

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) NOT NULL,
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  listing_id uuid REFERENCES listings(id) NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  quantity integer NOT NULL DEFAULT 1,
  total_price decimal(10,2) NOT NULL,
  delivery_address text,
  delivery_instructions text,
  payment_status text NOT NULL DEFAULT 'pending',
  payment_intent_id text,
  notes text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'refunded')),
  CONSTRAINT valid_payment_status CHECK (payment_status IN ('pending', 'paid', 'refunded')),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT positive_price CHECK (total_price > 0)
);

-- Order status history
CREATE TABLE IF NOT EXISTS order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL,
  notes text,
  changed_by uuid REFERENCES profiles(id) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;

-- Orders policies
CREATE POLICY "Clients can view their own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Pickers can view their orders"
  ON orders FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Clients can create orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can update their pending orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid() AND status = 'pending')
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Pickers can update their orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Order status history policies
CREATE POLICY "Users can view order status history for their orders"
  ON order_status_history FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_status_history.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can create status history for their orders"
  ON order_status_history FOR INSERT
  TO authenticated
  WITH CHECK (
    changed_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_status_history.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_picker_id ON orders(picker_id);
CREATE INDEX IF NOT EXISTS idx_orders_listing_id ON orders(listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_orders_updated_at_trigger ON orders;
CREATE TRIGGER update_orders_updated_at_trigger
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_orders_updated_at();