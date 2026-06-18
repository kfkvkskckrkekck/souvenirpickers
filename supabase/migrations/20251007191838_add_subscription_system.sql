/*
  # Add subscription system with 3-month free trial

  ## Overview
  This migration adds a subscription system where all users get a 3-month free trial,
  then are charged 1 euro per month after the trial expires.

  ## 1. Changes to profiles table
    - `trial_started_at` (timestamptz, when the trial started)
    - `trial_ends_at` (timestamptz, when the trial ends - 3 months after start)
    - `subscription_status` (text, current subscription status)
    - `subscription_started_at` (timestamptz, when paid subscription started)
    - `last_payment_date` (timestamptz, last successful payment)
    - `next_payment_due` (timestamptz, when next payment is due)
    - `payment_failed` (boolean, whether last payment attempt failed)

  ## 2. Notes
    - Trial period is 3 months (90 days) from account creation
    - After trial, subscription is 1 euro per month
    - Subscription status can be: 'trial', 'active', 'past_due', 'cancelled'
    - Trial starts automatically when profile is created
    - Payment tracking for monthly billing cycle
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'trial_started_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN trial_started_at timestamptz DEFAULT now();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'trial_ends_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN trial_ends_at timestamptz DEFAULT (now() + interval '90 days');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'subscription_status'
  ) THEN
    ALTER TABLE profiles ADD COLUMN subscription_status text DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'cancelled'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'subscription_started_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN subscription_started_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'last_payment_date'
  ) THEN
    ALTER TABLE profiles ADD COLUMN last_payment_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'next_payment_due'
  ) THEN
    ALTER TABLE profiles ADD COLUMN next_payment_due timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_failed'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_failed boolean DEFAULT false;
  END IF;
END $$;

UPDATE profiles
SET 
  trial_started_at = COALESCE(trial_started_at, created_at),
  trial_ends_at = COALESCE(trial_ends_at, created_at + interval '90 days'),
  subscription_status = COALESCE(subscription_status, 'trial')
WHERE trial_started_at IS NULL OR trial_ends_at IS NULL OR subscription_status IS NULL;