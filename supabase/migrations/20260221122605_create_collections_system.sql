/*
  # Create Collections System

  1. New Tables
    - `collections`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to profiles)
      - `name` (text, collection name)
      - `description` (text, optional description)
      - `is_public` (boolean, whether collection is public)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `collection_items`
      - `id` (uuid, primary key)
      - `collection_id` (uuid, foreign key to collections)
      - `listing_id` (uuid, optional foreign key to listings)
      - `desire_id` (uuid, optional foreign key to client_desires)
      - `notes` (text, optional notes about the item)
      - `added_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Users can only manage their own collections
    - Public collections can be viewed by anyone
    - Collection items follow collection permissions

  3. Indexes
    - Index on user_id for fast collection lookup
    - Index on collection_id for fast item lookup
*/

-- Create collections table
CREATE TABLE IF NOT EXISTS collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text DEFAULT '',
  is_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create collection_items table
CREATE TABLE IF NOT EXISTS collection_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  collection_id uuid NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  desire_id uuid REFERENCES client_desires(id) ON DELETE CASCADE,
  notes text DEFAULT '',
  added_at timestamptz DEFAULT now(),
  CONSTRAINT collection_items_has_listing_or_desire CHECK (
    (listing_id IS NOT NULL AND desire_id IS NULL) OR
    (listing_id IS NULL AND desire_id IS NOT NULL)
  )
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON collections(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id ON collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_listing_id ON collection_items(listing_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_desire_id ON collection_items(desire_id);

-- Enable RLS
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_items ENABLE ROW LEVEL SECURITY;

-- Collections policies
CREATE POLICY "Users can view their own collections"
  ON collections FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can view public collections"
  ON collections FOR SELECT
  TO authenticated
  USING (is_public = true);

CREATE POLICY "Users can insert their own collections"
  ON collections FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own collections"
  ON collections FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their own collections"
  ON collections FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Collection items policies
CREATE POLICY "Users can view items in their collections"
  ON collection_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view items in public collections"
  ON collection_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.is_public = true
    )
  );

CREATE POLICY "Users can insert items into their collections"
  ON collection_items FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update items in their collections"
  ON collection_items FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete items from their collections"
  ON collection_items FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_items.collection_id
      AND collections.user_id = auth.uid()
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_collection_updated_at()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE collections
  SET updated_at = now()
  WHERE id = NEW.collection_id;
  RETURN NEW;
END;
$$;

-- Trigger to update collection timestamp when items are added/removed
DROP TRIGGER IF EXISTS update_collection_timestamp_on_item_insert ON collection_items;
CREATE TRIGGER update_collection_timestamp_on_item_insert
  AFTER INSERT ON collection_items
  FOR EACH ROW
  EXECUTE FUNCTION update_collection_updated_at();

DROP TRIGGER IF EXISTS update_collection_timestamp_on_item_delete ON collection_items;
CREATE TRIGGER update_collection_timestamp_on_item_delete
  AFTER DELETE ON collection_items
  FOR EACH ROW
  EXECUTE FUNCTION update_collection_updated_at();
