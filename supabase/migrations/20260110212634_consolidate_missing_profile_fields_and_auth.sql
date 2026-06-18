/*
  # Consolidate Missing Profile Fields and Auth Setup

  1. Changes
    - Add all missing subscription fields to profiles table
    - Add billing and social media fields
    - Add default delivery address field
    - Add admin flag
    - Create profile creation trigger for auth

  2. Security
    - Maintains existing RLS policies
    - Creates trigger with SECURITY DEFINER
*/

-- Add subscription fields
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS trial_started_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz DEFAULT (now() + interval '30 days'),
ADD COLUMN IF NOT EXISTS subscription_status text DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'cancelled')),
ADD COLUMN IF NOT EXISTS subscription_started_at timestamptz,
ADD COLUMN IF NOT EXISTS last_payment_date timestamptz,
ADD COLUMN IF NOT EXISTS next_payment_due timestamptz,
ADD COLUMN IF NOT EXISTS payment_failed boolean DEFAULT false;

-- Add billing fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS company_name text,
ADD COLUMN IF NOT EXISTS billing_address text,
ADD COLUMN IF NOT EXISTS billing_city text,
ADD COLUMN IF NOT EXISTS billing_postal_code text,
ADD COLUMN IF NOT EXISTS billing_country text,
ADD COLUMN IF NOT EXISTS tax_id text,
ADD COLUMN IF NOT EXISTS billing_email text,
ADD COLUMN IF NOT EXISTS billing_phone text;

-- Add delivery address
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS default_delivery_address text;

-- Add social media fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS facebook_url text,
ADD COLUMN IF NOT EXISTS twitter_url text,
ADD COLUMN IF NOT EXISTS instagram_url text,
ADD COLUMN IF NOT EXISTS threads_url text;

-- Add admin flag
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Create profile creation trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type,
        trial_started_at,
        trial_ends_at,
        subscription_status
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val,
        now(),
        now() + interval '30 days',
        'trial'
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Update existing profiles to have subscription data
UPDATE profiles
SET 
  trial_started_at = COALESCE(trial_started_at, created_at),
  trial_ends_at = COALESCE(trial_ends_at, created_at + interval '30 days'),
  subscription_status = COALESCE(subscription_status, 'trial'),
  payment_failed = COALESCE(payment_failed, false)
WHERE trial_started_at IS NULL OR trial_ends_at IS NULL OR subscription_status IS NULL;

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';
