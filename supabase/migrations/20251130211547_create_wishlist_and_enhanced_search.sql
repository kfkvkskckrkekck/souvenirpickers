/*
  # Create Wishlist and Enhanced Search System

  ## Overview
  This migration adds wishlist functionality and enhanced search capabilities to improve user engagement and discovery.

  ## 1. New Tables
  
  ### `wishlists`
  - `id` (uuid, primary key) - Unique wishlist item identifier
  - `user_id` (uuid, foreign key) - References auth.users
  - `listing_id` (uuid, foreign key) - References listings
  - `created_at` (timestamptz) - When item was added to wishlist
  - `notes` (text, optional) - User's personal notes about the item

  ### `search_history`
  - `id` (uuid, primary key) - Unique search record identifier
  - `user_id` (uuid, foreign key) - References auth.users (nullable for anonymous)
  - `search_query` (text) - The search text entered
  - `filters_applied` (jsonb) - Filter parameters used
  - `results_count` (integer) - Number of results returned
  - `created_at` (timestamptz) - When search was performed

  ### `popular_searches`
  - `id` (uuid, primary key) - Unique record identifier
  - `search_term` (text, unique) - The search term
  - `search_count` (integer) - Number of times searched
  - `last_searched_at` (timestamptz) - Most recent search
  - `updated_at` (timestamptz) - Last update timestamp

  ## 2. Indexes
  - Index on wishlists(user_id) for fast user wishlist lookups
  - Index on wishlists(listing_id) for wishlist count queries
  - Index on search_history(user_id) for user search history
  - Full-text search index on listings for enhanced search

  ## 3. Functions
  - `update_listing_search_vector()` - Trigger function for full-text search
  - `get_trending_listings()` - Function to calculate trending listings based on views

  ## 4. Security
  - Enable RLS on all new tables
  - Users can manage their own wishlists
  - Users can view their own search history
  - Popular searches are publicly readable

  ## 5. Important Notes
  - Wishlist provides quick access to saved items
  - Search history helps personalize recommendations
  - Popular searches improve discovery
  - Listing views track engagement for trending algorithms
*/

-- Create wishlists table
CREATE TABLE IF NOT EXISTS wishlists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Create search_history table
CREATE TABLE IF NOT EXISTS search_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  search_query text NOT NULL,
  filters_applied jsonb DEFAULT '{}'::jsonb,
  results_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create popular_searches table
CREATE TABLE IF NOT EXISTS popular_searches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  search_term text UNIQUE NOT NULL,
  search_count integer DEFAULT 1,
  last_searched_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_wishlists_user_id ON wishlists(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlists_listing_id ON wishlists(listing_id);
CREATE INDEX IF NOT EXISTS idx_wishlists_created_at ON wishlists(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_search_history_user_id ON search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_created_at ON search_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_popular_searches_count ON popular_searches(search_count DESC);
CREATE INDEX IF NOT EXISTS idx_popular_searches_term ON popular_searches(search_term);

-- Add indexes to existing listing_views table
CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_created_at ON listing_views(created_at DESC);

-- Add full-text search to listings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'search_vector'
  ) THEN
    ALTER TABLE listings ADD COLUMN search_vector tsvector;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON listings USING gin(search_vector);

-- Function to update search vector (uses region and pickup_location instead of location)
CREATE OR REPLACE FUNCTION update_listing_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.category, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(NEW.region, '')), 'D') ||
    setweight(to_tsvector('english', COALESCE(NEW.pickup_location, '')), 'D');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update search vector
DROP TRIGGER IF EXISTS update_listing_search_vector_trigger ON listings;
CREATE TRIGGER update_listing_search_vector_trigger
  BEFORE INSERT OR UPDATE OF title, description, category, region, pickup_location
  ON listings
  FOR EACH ROW
  EXECUTE FUNCTION update_listing_search_vector();

-- Update existing listings search vectors
UPDATE listings 
SET search_vector = 
  setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(description, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(category, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(region, '')), 'D') ||
  setweight(to_tsvector('english', COALESCE(pickup_location, '')), 'D')
WHERE search_vector IS NULL;

-- Function to get trending listings (uses existing listing_views table)
CREATE OR REPLACE FUNCTION get_trending_listings(time_period interval DEFAULT '7 days'::interval, limit_count integer DEFAULT 10)
RETURNS TABLE (
  listing_id uuid,
  view_count bigint,
  unique_viewers bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    lv.listing_id,
    COUNT(*) as view_count,
    COUNT(DISTINCT lv.user_id) as unique_viewers
  FROM listing_views lv
  WHERE lv.created_at > now() - time_period
  GROUP BY lv.listing_id
  ORDER BY view_count DESC, unique_viewers DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE popular_searches ENABLE ROW LEVEL SECURITY;

-- Wishlist policies
CREATE POLICY "Users can view own wishlist"
  ON wishlists FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can add to own wishlist"
  ON wishlists FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove from own wishlist"
  ON wishlists FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own wishlist notes"
  ON wishlists FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Search history policies
CREATE POLICY "Users can view own search history"
  ON search_history FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Anyone can insert search history"
  ON search_history FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Popular searches policies
CREATE POLICY "Anyone can view popular searches"
  ON popular_searches FOR SELECT
  TO authenticated, anon
  USING (true);