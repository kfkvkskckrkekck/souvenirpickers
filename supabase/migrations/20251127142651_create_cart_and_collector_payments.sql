/*
  # Create Shopping Cart and Collector Payment Methods System

  ## Overview
  This migration creates a shopping cart system for collectors and adds payment method management.

  ## New Tables
  
  ### 1. `cart_items`
  Shopping cart for collectors to add items before checkout
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `listing_id` (uuid, references listings) - The item being added
  - `quantity` (integer) - Number of items
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. `collector_payment_methods`
  Payment methods for collectors (separate from picker payment methods)
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `method_type` (text) - credit_card, debit_card, paypal, etc.
  - `card_brand` (text) - Visa, Mastercard, etc.
  - `last_four` (text) - Last 4 digits of card
  - `cardholder_name` (text) - Name on card
  - `expiry_month` (integer) - Card expiry month
  - `expiry_year` (integer) - Card expiry year
  - `is_default` (boolean) - Whether this is the default payment method
  - `stripe_payment_method_id` (text) - Stripe payment method ID
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - RLS enabled on all tables
  - Collectors can only access their own cart items and payment methods
  - Proper indexes for performance

  ## Important Notes
  - Cart items are linked to active listings
  - Payment methods store minimal card info for display
  - Actual payment processing will use Stripe
  - First payment method is automatically default
*/

-- Create cart_items table
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT unique_cart_item UNIQUE (client_id, listing_id)
);

-- Create collector_payment_methods table
CREATE TABLE IF NOT EXISTS collector_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  method_type text NOT NULL DEFAULT 'credit_card',
  card_brand text,
  last_four text,
  cardholder_name text NOT NULL,
  expiry_month integer,
  expiry_year integer,
  is_default boolean DEFAULT false,
  stripe_payment_method_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_method_type CHECK (method_type IN ('credit_card', 'debit_card', 'paypal', 'bank_account', 'other')),
  CONSTRAINT valid_expiry_month CHECK (expiry_month IS NULL OR (expiry_month >= 1 AND expiry_month <= 12)),
  CONSTRAINT valid_expiry_year CHECK (expiry_year IS NULL OR expiry_year >= 2024)
);

-- Enable RLS
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE collector_payment_methods ENABLE ROW LEVEL SECURITY;

-- Cart items policies
CREATE POLICY "Collectors can view their own cart items"
  ON cart_items FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Collectors can add items to their cart"
  ON cart_items FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can update their cart items"
  ON cart_items FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can remove items from their cart"
  ON cart_items FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());

-- Collector payment methods policies
CREATE POLICY "Collectors can view their own payment methods"
  ON collector_payment_methods FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Collectors can add their payment methods"
  ON collector_payment_methods FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can update their payment methods"
  ON collector_payment_methods FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can delete their payment methods"
  ON collector_payment_methods FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cart_items_client_id ON cart_items(client_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_listing_id ON cart_items(listing_id);
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_client_id ON collector_payment_methods(client_id);
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_default ON collector_payment_methods(client_id, is_default) WHERE is_default = true;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_cart_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_cart_items_updated_at_trigger ON cart_items;
CREATE TRIGGER update_cart_items_updated_at_trigger
  BEFORE UPDATE ON cart_items
  FOR EACH ROW
  EXECUTE FUNCTION update_cart_updated_at();

DROP TRIGGER IF EXISTS update_collector_payment_methods_updated_at_trigger ON collector_payment_methods;
CREATE TRIGGER update_collector_payment_methods_updated_at_trigger
  BEFORE UPDATE ON collector_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION update_cart_updated_at();