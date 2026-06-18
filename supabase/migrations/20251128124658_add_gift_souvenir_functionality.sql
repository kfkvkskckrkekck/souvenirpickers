/*
  # Add Gift Souvenir Functionality

  1. Changes
    - Add gift-related columns to orders table
    - Enable collectors to send souvenirs as gifts
    - Store recipient information
    - Add gift message support

  2. New Columns in orders table
    - is_gift (boolean) - Whether this is a gift order
    - gift_recipient_name (text) - Name of the gift recipient
    - gift_recipient_email (text) - Email of the gift recipient
    - gift_message (text) - Personal message for the gift
    - gift_recipient_address (text) - Delivery address for the gift

  3. Features
    - Gift orders can be sent to different addresses
    - Personal messages included with gifts
    - Email notifications to recipients
    - Track gift deliveries separately
*/

-- Add gift-related columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'is_gift'
  ) THEN
    ALTER TABLE orders ADD COLUMN is_gift boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_name'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_email'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_email text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_message'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_message text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_address'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_address text;
  END IF;
END $$;

-- Create index on gift orders for analytics
CREATE INDEX IF NOT EXISTS orders_is_gift_idx ON orders(is_gift) WHERE is_gift = true;