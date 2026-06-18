/*
  # Add company billing information
  
  ## Overview
  This migration adds company billing information fields to the profiles table
  for proper invoicing and payment processing.
  
  ## 1. Changes to profiles table
    - `company_name` (text, optional company name for business accounts)
    - `billing_address` (text, street address for billing)
    - `billing_city` (text, city for billing)
    - `billing_postal_code` (text, postal/zip code)
    - `billing_country` (text, country for billing)
    - `tax_id` (text, VAT/Tax ID number for businesses)
    - `billing_email` (text, email for billing/invoices)
    - `billing_phone` (text, phone number for billing inquiries)
  
  ## 2. Notes
    - All fields are optional to support both individual and business accounts
    - Tax ID field supports VAT numbers and other tax identifiers
    - Billing email defaults to user's primary email if not specified
    - Information used for generating invoices and payment processing
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'company_name'
  ) THEN
    ALTER TABLE profiles ADD COLUMN company_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_address'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_address text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_city'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_city text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_postal_code'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_postal_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_country'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_country text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'tax_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN tax_id text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_email'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_email text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_phone'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_phone text;
  END IF;
END $$;