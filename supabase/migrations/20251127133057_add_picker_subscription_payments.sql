/*
  # Picker Subscription Payment System

  1. New Tables
    - picker_subscription_payments: Tracks subscription payment history for pickers
    - picker_payment_cards: Stores payment card information for pickers (tokenized)
    
  2. Changes to Profiles
    - Only pickers need to pay subscription fees
    - Add stripe_customer_id for pickers
    - Add default_payment_method reference
    
  3. Security
    - Enable RLS on all tables
    - Pickers can only view and manage their own payment methods
    - Payment card data is tokenized (only store Stripe tokens, never raw card data)
    
  4. Important Notes
    - Only pickers (user_type = 'picker') are charged subscription fees
    - Clients (user_type = 'client') use the platform for free
    - Subscription is 1 euro per month after 60-day trial
    - Payment is processed automatically via Stripe
    - Pickers must add payment method before trial ends
*/

-- Create subscription payments tracking table
CREATE TABLE IF NOT EXISTS picker_subscription_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount numeric(10, 2) NOT NULL,
  currency text DEFAULT 'eur',
  stripe_payment_intent_id text UNIQUE,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'succeeded', 'failed', 'refunded')),
  billing_period_start timestamptz NOT NULL,
  billing_period_end timestamptz NOT NULL,
  payment_method_used text,
  failure_reason text,
  paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payment cards table (stores Stripe tokens only)
CREATE TABLE IF NOT EXISTS picker_payment_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  stripe_payment_method_id text UNIQUE NOT NULL,
  card_brand text,
  card_last4 text,
  card_exp_month integer,
  card_exp_year integer,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add Stripe customer ID to profiles (only for pickers)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'stripe_customer_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stripe_customer_id text UNIQUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'default_payment_card_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN default_payment_card_id uuid REFERENCES picker_payment_cards(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_method_added'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_method_added boolean DEFAULT false;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE picker_subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Policies for picker_subscription_payments
CREATE POLICY "Pickers can view own subscription payments"
  ON picker_subscription_payments FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "System can insert subscription payments"
  ON picker_subscription_payments FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "System can update subscription payments"
  ON picker_subscription_payments FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Policies for picker_payment_cards
CREATE POLICY "Pickers can view own payment cards"
  ON picker_payment_cards FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Pickers can add own payment cards"
  ON picker_payment_cards FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can update own payment cards"
  ON picker_payment_cards FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can delete own payment cards"
  ON picker_payment_cards FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_subscription_payments_picker_id ON picker_subscription_payments(picker_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON picker_subscription_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_period ON picker_subscription_payments(billing_period_start, billing_period_end);
CREATE INDEX IF NOT EXISTS idx_payment_cards_picker_id ON picker_payment_cards(picker_id);
CREATE INDEX IF NOT EXISTS idx_payment_cards_default ON picker_payment_cards(picker_id, is_default);

-- Function to automatically set only one default payment card per picker
CREATE OR REPLACE FUNCTION set_default_payment_card()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE picker_payment_cards
    SET is_default = false
    WHERE picker_id = NEW.picker_id
    AND id != NEW.id;
    
    UPDATE profiles
    SET default_payment_card_id = NEW.id,
        payment_method_added = true
    WHERE id = NEW.picker_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to manage default payment card
DROP TRIGGER IF EXISTS trigger_set_default_payment_card ON picker_payment_cards;
CREATE TRIGGER trigger_set_default_payment_card
  AFTER INSERT OR UPDATE OF is_default ON picker_payment_cards
  FOR EACH ROW
  EXECUTE FUNCTION set_default_payment_card();

-- Function to process monthly subscription payments
CREATE OR REPLACE FUNCTION process_picker_subscription_payment(
  p_picker_id uuid,
  p_amount numeric,
  p_stripe_payment_intent_id text,
  p_payment_method_used text
)
RETURNS json AS $$
DECLARE
  v_payment_id uuid;
  v_billing_start timestamptz;
  v_billing_end timestamptz;
BEGIN
  v_billing_start := date_trunc('month', now());
  v_billing_end := v_billing_start + interval '1 month';

  INSERT INTO picker_subscription_payments (
    picker_id,
    amount,
    currency,
    stripe_payment_intent_id,
    payment_status,
    billing_period_start,
    billing_period_end,
    payment_method_used,
    paid_at
  )
  VALUES (
    p_picker_id,
    p_amount,
    'eur',
    p_stripe_payment_intent_id,
    'succeeded',
    v_billing_start,
    v_billing_end,
    p_payment_method_used,
    now()
  )
  RETURNING id INTO v_payment_id;

  UPDATE profiles
  SET 
    last_payment_date = now(),
    next_payment_due = v_billing_end,
    payment_failed = false,
    subscription_status = 'active'
  WHERE id = p_picker_id;

  RETURN json_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'next_payment_due', v_billing_end
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION process_picker_subscription_payment(uuid, numeric, text, text) TO authenticated;