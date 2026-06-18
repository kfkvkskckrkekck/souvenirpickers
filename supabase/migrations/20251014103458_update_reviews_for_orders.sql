/*
  # Update Reviews System for Orders

  ## Changes
  
  1. Modifications to reviews table
    - Add `order_id` column (nullable, references orders, unique)
    - Make `request_id` nullable (to support both order and request reviews)
    - Add `listing_id` column (nullable, references listings)
    - Add `response` text column for picker responses
    - Add `response_at` timestamp
    - Add `updated_at` timestamp
  
  2. Updated Security
    - Update policies to handle order-based reviews
    - Allow pickers to respond to reviews
  
  3. Important Notes
    - Reviews can now be linked to either orders or requests
    - Pickers can respond to reviews about them
    - One review per order (enforced by unique constraint)
*/

-- Add new columns to reviews table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'order_id'
  ) THEN
    ALTER TABLE reviews ADD COLUMN order_id uuid REFERENCES orders(id) UNIQUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'listing_id'
  ) THEN
    ALTER TABLE reviews ADD COLUMN listing_id uuid REFERENCES listings(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'response'
  ) THEN
    ALTER TABLE reviews ADD COLUMN response text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'response_at'
  ) THEN
    ALTER TABLE reviews ADD COLUMN response_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE reviews ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Make request_id nullable since reviews can be for orders too
DO $$
BEGIN
  ALTER TABLE reviews ALTER COLUMN request_id DROP NOT NULL;
EXCEPTION
  WHEN others THEN NULL;
END $$;

-- Drop and recreate policies with proper names
DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Clients can create reviews" ON reviews;
DROP POLICY IF EXISTS "Clients can update their reviews" ON reviews;

CREATE POLICY "authenticated_users_can_view_reviews"
  ON reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "clients_can_create_order_reviews"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid() AND
    (
      (order_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = reviews.order_id
        AND orders.client_id = auth.uid()
        AND orders.status = 'completed'
      )) OR
      (request_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = reviews.request_id
        AND requests.client_id = auth.uid()
      ))
    )
  );

CREATE POLICY "clients_can_update_own_reviews"
  ON reviews FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid() AND response IS NULL);

CREATE POLICY "pickers_can_respond_to_reviews"
  ON reviews FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews(order_id) WHERE order_id IS NOT NULL;

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_reviews_updated_at_trigger ON reviews;
CREATE TRIGGER update_reviews_updated_at_trigger
  BEFORE UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_reviews_updated_at();