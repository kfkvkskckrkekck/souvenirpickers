/*
  # Add Missing Goods Confirmation Columns

  ## Changes
  - Add `goods_confirmed` column (boolean) - Whether collector confirmed receipt
  - Add `goods_confirmed_at` column (timestamptz) - When confirmation happened
  - Keep existing `goods_received` columns for backward compatibility
  - Create index for goods_confirmed lookups
*/

-- Add goods_confirmed column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed boolean DEFAULT false;
  END IF;
END $$;

-- Add goods_confirmed_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed_at timestamptz;
  END IF;
END $$;

-- Create index for goods_confirmed lookups
CREATE INDEX IF NOT EXISTS idx_orders_goods_confirmed 
ON orders(goods_confirmed, goods_confirmed_at) 
WHERE goods_confirmed = true;