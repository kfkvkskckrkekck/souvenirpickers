/*
  # Add Client Payment Methods

  1. New Table
    - `client_payment_methods`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `method_type` (text) - Type of payment method (credit_card, debit_card, paypal, etc.)
      - `method_name` (text) - Display name for the payment method
      - `last_four` (text) - Last 4 digits for cards
      - `card_brand` (text) - Card brand (visa, mastercard, etc.)
      - `expiry_month` (integer) - Card expiry month
      - `expiry_year` (integer) - Card expiry year
      - `is_default` (boolean) - Whether this is the default payment method
      - `active` (boolean) - Whether payment method is active
      - `stripe_payment_method_id` (text) - Stripe payment method ID
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS on `client_payment_methods` table
    - Add policy for clients to manage their own payment methods
*/

CREATE TABLE IF NOT EXISTS client_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  method_type text NOT NULL CHECK (method_type IN ('credit_card', 'debit_card', 'paypal', 'bank_account', 'other')),
  method_name text NOT NULL,
  last_four text,
  card_brand text,
  expiry_month integer CHECK (expiry_month >= 1 AND expiry_month <= 12),
  expiry_year integer CHECK (expiry_year >= 2024),
  is_default boolean DEFAULT false,
  active boolean DEFAULT true,
  stripe_payment_method_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE client_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view own payment methods"
  ON client_payment_methods
  FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Clients can insert own payment methods"
  ON client_payment_methods
  FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can update own payment methods"
  ON client_payment_methods
  FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can delete own payment methods"
  ON client_payment_methods
  FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());
