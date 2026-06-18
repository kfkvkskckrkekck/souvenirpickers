/*
  # Fix cart_items table schema
  
  This migration fixes the cart_items table schema to match the expected structure.
  
  ## Changes
  1. Rename `user_id` column to `client_id`
  2. Rename `added_at` column to `created_at`
  3. Add `updated_at` column
  4. Add unique constraint for client_id + listing_id
  5. Add proper indexes
  6. Add trigger for updating updated_at
  
  ## Notes
  - Existing data will be preserved
  - This fixes the "column cart_items.client_id does not exist" error
*/

-- Rename columns to match expected schema
DO $$
BEGIN
  -- Rename user_id to client_id if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE cart_items RENAME COLUMN user_id TO client_id;
  END IF;

  -- Rename added_at to created_at if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'added_at'
  ) THEN
    ALTER TABLE cart_items RENAME COLUMN added_at TO created_at;
  END IF;

  -- Add updated_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cart_items' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE cart_items ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Add unique constraint if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'unique_cart_item'
  ) THEN
    ALTER TABLE cart_items ADD CONSTRAINT unique_cart_item UNIQUE (client_id, listing_id);
  END IF;
EXCEPTION
  WHEN duplicate_table THEN NULL;
END $$;

-- Add positive quantity constraint if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'positive_quantity'
  ) THEN
    ALTER TABLE cart_items ADD CONSTRAINT positive_quantity CHECK (quantity > 0);
  END IF;
EXCEPTION
  WHEN duplicate_table THEN NULL;
END $$;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_cart_items_client_id ON cart_items(client_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_listing_id ON cart_items(listing_id);

-- Create function for updating updated_at
CREATE OR REPLACE FUNCTION update_cart_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS update_cart_items_updated_at_trigger ON cart_items;
CREATE TRIGGER update_cart_items_updated_at_trigger
  BEFORE UPDATE ON cart_items
  FOR EACH ROW
  EXECUTE FUNCTION update_cart_updated_at();