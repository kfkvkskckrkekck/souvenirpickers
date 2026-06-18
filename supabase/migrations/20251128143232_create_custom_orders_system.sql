/*
  # Create Custom Orders System

  1. New Tables
    - `custom_orders`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles) - The picker creating the custom offer
      - `client_id` (uuid, references profiles) - The collector receiving the offer
      - `title` (text) - Custom product/service title
      - `description` (text) - Details of what's being offered
      - `base_price` (decimal) - Item/service cost
      - `transportation_cost` (decimal) - Transportation cost
      - `total_price` (decimal) - Total = base + transportation
      - `quantity` (integer) - Number of items
      - `images` (text array) - Optional product images
      - `delivery_address` (text) - Optional delivery address
      - `notes` (text) - Additional notes
      - `status` (text) - pending, accepted, rejected, expired, completed
      - `expires_at` (timestamptz) - When the offer expires
      - `accepted_at` (timestamptz) - When collector accepted
      - `order_id` (uuid, references orders) - Created order after acceptance
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on custom_orders table
    - Pickers can create and view their custom orders
    - Collectors can view and accept custom orders sent to them
    - Both parties can view orders they're involved in

  3. Notes
    - Pickers create custom orders through messages/chat
    - Collectors receive notification and can accept/reject
    - Upon acceptance, a regular order is created with payment
    - Custom orders expire after 7 days by default
*/

-- Create custom_orders table
CREATE TABLE IF NOT EXISTS custom_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  client_id uuid REFERENCES profiles(id) NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  base_price decimal(10,2) NOT NULL DEFAULT 0,
  transportation_cost decimal(10,2) NOT NULL DEFAULT 0,
  total_price decimal(10,2) NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  images text[] DEFAULT '{}',
  delivery_address text,
  notes text,
  status text NOT NULL DEFAULT 'pending',
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz,
  order_id uuid REFERENCES orders(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_custom_orders_picker_id ON custom_orders(picker_id);
CREATE INDEX IF NOT EXISTS idx_custom_orders_client_id ON custom_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_custom_orders_status ON custom_orders(status);
CREATE INDEX IF NOT EXISTS idx_custom_orders_expires_at ON custom_orders(expires_at);

-- Enable RLS
ALTER TABLE custom_orders ENABLE ROW LEVEL SECURITY;

-- Pickers can create custom orders
CREATE POLICY "Pickers can create custom orders"
  ON custom_orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

-- Pickers can view their custom orders
CREATE POLICY "Pickers can view their custom orders"
  ON custom_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Collectors can view custom orders sent to them
CREATE POLICY "Collectors can view their custom orders"
  ON custom_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- Collectors can accept/reject custom orders
CREATE POLICY "Collectors can update their custom orders"
  ON custom_orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (auth.uid() = client_id);

-- Pickers can update their pending custom orders
CREATE POLICY "Pickers can update pending custom orders"
  ON custom_orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id AND status = 'pending')
  WITH CHECK (auth.uid() = picker_id);

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_custom_orders_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER custom_orders_updated_at
  BEFORE UPDATE ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_custom_orders_updated_at();

-- Create notification when custom order is created
CREATE OR REPLACE FUNCTION notify_custom_order_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    NEW.client_id,
    'custom_order_received',
    'New Custom Order Offer',
    'You have received a custom order offer: ' || NEW.title,
    jsonb_build_object('custom_order_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER custom_order_created_notification
  AFTER INSERT ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_custom_order_created();

-- Create notification when custom order is accepted
CREATE OR REPLACE FUNCTION notify_custom_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    INSERT INTO notifications (user_id, type, title, message, data)
    VALUES (
      NEW.picker_id,
      'custom_order_accepted',
      'Custom Order Accepted',
      'Your custom order offer has been accepted: ' || NEW.title,
      jsonb_build_object('custom_order_id', NEW.id, 'order_id', NEW.order_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER custom_order_accepted_notification
  AFTER UPDATE ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_custom_order_accepted();

-- Function to expire old custom orders
CREATE OR REPLACE FUNCTION expire_old_custom_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE custom_orders
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < now();
END;
$$;

COMMENT ON TABLE custom_orders IS 'Custom orders with negotiated prices between pickers and collectors';
COMMENT ON COLUMN custom_orders.base_price IS 'Base cost of the custom item/service';
COMMENT ON COLUMN custom_orders.transportation_cost IS 'Transportation cost for the custom order';
COMMENT ON COLUMN custom_orders.total_price IS 'Total price (base_price + transportation_cost) * quantity';
COMMENT ON COLUMN custom_orders.expires_at IS 'When the custom order offer expires';
