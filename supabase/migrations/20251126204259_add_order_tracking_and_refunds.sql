/*
  # Add Order Tracking and Refunds

  1. Changes to Existing Tables
    - Add columns to `orders` table
      - `tracking_number` (text) - Shipping tracking number
      - `carrier` (text) - Shipping carrier name
      - `estimated_delivery` (date) - Expected delivery date
      - `actual_delivery` (timestamptz) - Actual delivery timestamp
      - `refund_requested_at` (timestamptz) - When refund was requested
      - `refund_reason` (text) - Reason for refund request
      - `refunded_at` (timestamptz) - When refund was processed
      - `refund_amount` (decimal) - Amount refunded

  2. New Tables
    - `order_updates`
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `status` (text) - Order status update
      - `message` (text) - Update message
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamptz)

  3. Security
    - Enable RLS on new table
    - Add policies for order participants to view updates
*/

-- Add tracking and refund columns to orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'tracking_number'
  ) THEN
    ALTER TABLE orders ADD COLUMN tracking_number text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'carrier'
  ) THEN
    ALTER TABLE orders ADD COLUMN carrier text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'estimated_delivery'
  ) THEN
    ALTER TABLE orders ADD COLUMN estimated_delivery date;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'actual_delivery'
  ) THEN
    ALTER TABLE orders ADD COLUMN actual_delivery timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_requested_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_requested_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_reason'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_reason text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refunded_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN refunded_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_amount'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_amount decimal(10,2);
  END IF;
END $$;

-- Create order_updates table
CREATE TABLE IF NOT EXISTS order_updates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL,
  message text NOT NULL,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE order_updates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order participants can view updates"
  ON order_updates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_updates.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can create updates for their orders"
  ON order_updates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_updates.order_id
      AND orders.picker_id = auth.uid()
    )
    AND auth.uid() = created_by
  );

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_order_updates_order_id ON order_updates(order_id);