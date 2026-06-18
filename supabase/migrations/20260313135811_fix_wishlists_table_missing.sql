-- Create Wishlists Table
-- 
-- 1. New Tables
--   - wishlists: Stores user wishlist items
--     - id (uuid, primary key)
--     - user_id (uuid, references auth.users)
--     - listing_id (uuid, references listings)
--     - notes (text, optional personal notes)
--     - created_at (timestamptz)
-- 
-- 2. Security
--   - Enable RLS on wishlists table
--   - Add policies for authenticated users to manage their own wishlist items
-- 
-- 3. Indexes
--   - Add index on user_id for fast lookups
--   - Add unique constraint on (user_id, listing_id) to prevent duplicates

CREATE TABLE IF NOT EXISTS wishlists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- Create unique index to prevent duplicate wishlist entries
CREATE UNIQUE INDEX IF NOT EXISTS wishlists_user_listing_unique ON wishlists(user_id, listing_id);

-- Create index for faster user lookups
CREATE INDEX IF NOT EXISTS wishlists_user_id_idx ON wishlists(user_id);

-- Create index for faster listing lookups
CREATE INDEX IF NOT EXISTS wishlists_listing_id_idx ON wishlists(listing_id);

-- Enable RLS
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own wishlist items
CREATE POLICY "Users can view own wishlist items"
  ON wishlists FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy: Users can add items to their own wishlist
CREATE POLICY "Users can add own wishlist items"
  ON wishlists FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own wishlist items
CREATE POLICY "Users can update own wishlist items"
  ON wishlists FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own wishlist items
CREATE POLICY "Users can delete own wishlist items"
  ON wishlists FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);