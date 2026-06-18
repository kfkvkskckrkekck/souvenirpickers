-- Stripe Payment Integration System
--
-- 1. New Tables
--    - payment_intents: Tracks Stripe payment intents
--    - payment_escrow: Manages escrow system for secure payments
--    - refunds: Tracks refund requests and processing
--
-- 2. Security
--    - Enable RLS on all tables
--    - Clients can view their own payment records
--    - Pickers can view payments for their orders

-- Create payment_intents table
CREATE TABLE IF NOT EXISTS payment_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  stripe_payment_intent_id text UNIQUE,
  amount numeric(10, 2) NOT NULL,
  currency text DEFAULT 'usd',
  status text NOT NULL DEFAULT 'pending',
  client_secret text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payment_escrow table
CREATE TABLE IF NOT EXISTS payment_escrow (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_intent_id uuid REFERENCES payment_intents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  status text NOT NULL DEFAULT 'held',
  held_at timestamptz DEFAULT now(),
  released_at timestamptz,
  released_to uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Create refunds table
CREATE TABLE IF NOT EXISTS refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_intent_id uuid REFERENCES payment_intents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  stripe_refund_id text UNIQUE,
  amount numeric(10, 2) NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending',
  initiated_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_escrow ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

-- Policies for payment_intents
CREATE POLICY "Users can view own payment intents"
  ON payment_intents FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payment_intents.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "System can insert payment intents"
  ON payment_intents FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update payment intents"
  ON payment_intents FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Policies for payment_escrow
CREATE POLICY "Users can view own escrow records"
  ON payment_escrow FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payment_escrow.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "System can manage escrow"
  ON payment_escrow FOR ALL
  TO authenticated
  WITH CHECK (true);

-- Policies for refunds
CREATE POLICY "Users can view own refunds"
  ON refunds FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = refunds.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can request refunds"
  ON refunds FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.client_id = auth.uid()
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payment_intents_order_id ON payment_intents(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_stripe_id ON payment_intents(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_payment_escrow_order_id ON payment_escrow(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);
