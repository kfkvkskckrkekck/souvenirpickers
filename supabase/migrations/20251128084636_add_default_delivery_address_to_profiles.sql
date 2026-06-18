/*
  # Add Default Delivery Address to Profiles
  
  ## Overview
  This migration adds a default delivery address field to the profiles table for collectors
  to save their preferred shipping address.
  
  ## Changes
  1. Add `default_delivery_address` column to profiles table
  2. This allows collectors to save their address and have it pre-filled during checkout
  
  ## Notes
  - Field is optional (nullable)
  - Collectors can update this in their profile settings
  - Will be used to pre-fill the delivery address field in cart checkout
*/

-- Add default delivery address column to profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'default_delivery_address'
  ) THEN
    ALTER TABLE profiles ADD COLUMN default_delivery_address text;
  END IF;
END $$;