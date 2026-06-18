/*
  # Add Stripe Subscription ID to Profiles

  1. Changes
    - Add `stripe_subscription_id` column to profiles table to store the Stripe Subscription ID
    - This enables proper Stripe Subscriptions API integration for automatic recurring billing
  
  2. Security
    - Column is accessible to service role for webhook updates
    - Users can read their own subscription ID
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'stripe_subscription_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stripe_subscription_id text;
    CREATE INDEX IF NOT EXISTS idx_profiles_stripe_subscription_id ON profiles(stripe_subscription_id);
  END IF;
END $$;
