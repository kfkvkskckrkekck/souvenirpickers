/*
  # Fix Profiles Stripe Columns
  
  1. Changes to Profiles Table
    - Add stripe_customer_id column for Stripe integration
    - Add default_payment_card_id reference for payment methods
    - Add payment_method_added flag
    
  2. Security
    - No RLS changes needed (profiles already has RLS)
    
  3. Important Notes
    - These columns are essential for payment processing
    - stripe_customer_id stores the Stripe customer ID for each user
    - Only users who add payment methods will have these populated
*/

-- Add Stripe customer ID to profiles
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
    ALTER TABLE profiles ADD COLUMN default_payment_card_id uuid;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_method_added'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_method_added boolean DEFAULT false;
  END IF;
END $$;

-- Add foreign key constraint if picker_payment_cards table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'picker_payment_cards'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'profiles_default_payment_card_id_fkey'
    AND table_name = 'profiles'
  ) THEN
    ALTER TABLE profiles 
    ADD CONSTRAINT profiles_default_payment_card_id_fkey 
    FOREIGN KEY (default_payment_card_id) 
    REFERENCES picker_payment_cards(id) 
    ON DELETE SET NULL;
  END IF;
END $$;
