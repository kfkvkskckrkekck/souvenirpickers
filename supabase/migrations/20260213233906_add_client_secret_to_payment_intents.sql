/*
  # Add client_secret to payment_intents

  1. Changes
    - Add client_secret column to payment_intents table
    - Add metadata column to payment_intents table for storing additional data

  2. Security
    - Column is nullable for backwards compatibility
*/

-- Add client_secret column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payment_intents' AND column_name = 'client_secret'
  ) THEN
    ALTER TABLE payment_intents ADD COLUMN client_secret text;
  END IF;
END $$;

-- Add metadata column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payment_intents' AND column_name = 'metadata'
  ) THEN
    ALTER TABLE payment_intents ADD COLUMN metadata jsonb DEFAULT '{}'::jsonb;
  END IF;
END $$;
