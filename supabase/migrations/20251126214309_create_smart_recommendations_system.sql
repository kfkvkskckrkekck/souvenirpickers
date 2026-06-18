-- Smart Recommendations System
--
-- 1. New Tables
--    - user_activity: Track user browsing behavior
--    - listing_views: Track which listings users view
--    - user_preferences: Store inferred user preferences
--    - trending_listings: Cache trending listings
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only see their own activity

-- Create user_activity table
CREATE TABLE IF NOT EXISTS user_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL,
  entity_type text,
  entity_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create listing_views table
CREATE TABLE IF NOT EXISTS listing_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id text,
  duration_seconds integer,
  created_at timestamptz DEFAULT now()
);

-- Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  preferred_categories text[] DEFAULT ARRAY[]::text[],
  preferred_regions text[] DEFAULT ARRAY[]::text[],
  price_range_min numeric(10, 2),
  price_range_max numeric(10, 2),
  favorite_pickers text[] DEFAULT ARRAY[]::text[],
  browsing_patterns jsonb DEFAULT '{}'::jsonb,
  updated_at timestamptz DEFAULT now()
);

-- Create trending_listings table
CREATE TABLE IF NOT EXISTS trending_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  trend_score numeric(10, 2) NOT NULL,
  view_count integer DEFAULT 0,
  order_count integer DEFAULT 0,
  share_count integer DEFAULT 0,
  calculated_at timestamptz DEFAULT now(),
  UNIQUE(listing_id)
);

-- Enable RLS
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE trending_listings ENABLE ROW LEVEL SECURITY;

-- Policies for user_activity
CREATE POLICY "Users can view own activity"
  ON user_activity FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own activity"
  ON user_activity FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for listing_views
CREATE POLICY "Anyone can record listing views"
  ON listing_views FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view own listing views"
  ON listing_views FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR user_id IS NULL);

-- Policies for user_preferences
CREATE POLICY "Users can view own preferences"
  ON user_preferences FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own preferences"
  ON user_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for trending_listings
CREATE POLICY "Anyone can view trending listings"
  ON trending_listings FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_created_at ON user_activity(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_user_id ON listing_views(user_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_created_at ON listing_views(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trending_listings_score ON trending_listings(trend_score DESC);

-- Function to record listing view
CREATE OR REPLACE FUNCTION record_listing_view(
  p_listing_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_session_id text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  INSERT INTO listing_views (listing_id, user_id, session_id)
  VALUES (p_listing_id, p_user_id, p_session_id);

  IF p_user_id IS NOT NULL THEN
    INSERT INTO user_activity (user_id, activity_type, entity_type, entity_id)
    VALUES (p_user_id, 'view', 'listing', p_listing_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get personalized recommendations
CREATE OR REPLACE FUNCTION get_personalized_recommendations(
  p_user_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  listing_id uuid,
  relevance_score numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH user_prefs AS (
    SELECT 
      preferred_categories,
      preferred_regions,
      price_range_min,
      price_range_max
    FROM user_preferences
    WHERE user_id = p_user_id
  ),
  scored_listings AS (
    SELECT 
      l.id as listing_id,
      (
        CASE WHEN up.preferred_categories IS NOT NULL AND l.category = ANY(up.preferred_categories) THEN 50 ELSE 0 END +
        CASE WHEN up.preferred_regions IS NOT NULL AND l.region = ANY(up.preferred_regions) THEN 30 ELSE 0 END +
        CASE WHEN up.price_range_min IS NULL OR l.price >= up.price_range_min THEN 10 ELSE 0 END +
        CASE WHEN up.price_range_max IS NULL OR l.price <= up.price_range_max THEN 10 ELSE 0 END +
        COALESCE(pp.rating * 5, 0)
      )::numeric as relevance_score
    FROM listings l
    LEFT JOIN user_prefs up ON true
    LEFT JOIN picker_profiles pp ON pp.id = l.picker_id
    WHERE l.available = true
    AND l.id NOT IN (
      SELECT listing_id FROM orders WHERE client_id = p_user_id
    )
    ORDER BY relevance_score DESC, l.created_at DESC
    LIMIT p_limit
  )
  SELECT * FROM scored_listings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get trending listings
CREATE OR REPLACE FUNCTION get_trending_listings(p_limit integer DEFAULT 10)
RETURNS TABLE (
  listing_id uuid,
  trend_score numeric,
  view_count integer,
  order_count integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tl.listing_id,
    tl.trend_score,
    tl.view_count,
    tl.order_count
  FROM trending_listings tl
  JOIN listings l ON l.id = tl.listing_id
  WHERE l.available = true
  ORDER BY tl.trend_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user preferences based on activity
CREATE OR REPLACE FUNCTION update_user_preferences_from_activity()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT DISTINCT user_id FROM user_activity WHERE created_at > now() - interval '30 days'
  LOOP
    INSERT INTO user_preferences (user_id, preferred_categories, preferred_regions)
    SELECT 
      user_record.user_id,
      ARRAY_AGG(DISTINCT l.category) FILTER (WHERE l.category IS NOT NULL),
      ARRAY_AGG(DISTINCT l.region) FILTER (WHERE l.region IS NOT NULL)
    FROM user_activity ua
    JOIN listings l ON l.id = ua.entity_id
    WHERE ua.user_id = user_record.user_id
    AND ua.entity_type = 'listing'
    AND ua.created_at > now() - interval '30 days'
    ON CONFLICT (user_id) DO UPDATE
    SET 
      preferred_categories = EXCLUDED.preferred_categories,
      preferred_regions = EXCLUDED.preferred_regions,
      updated_at = now();
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate trending listings
CREATE OR REPLACE FUNCTION calculate_trending_listings()
RETURNS void AS $$
BEGIN
  DELETE FROM trending_listings;

  INSERT INTO trending_listings (listing_id, trend_score, view_count, order_count, share_count)
  SELECT 
    l.id,
    (
      COALESCE(view_counts.count, 0) * 1.0 +
      COALESCE(order_counts.count, 0) * 10.0 +
      COALESCE(share_counts.count, 0) * 5.0 +
      CASE WHEN l.created_at > now() - interval '7 days' THEN 20 ELSE 0 END
    )::numeric as trend_score,
    COALESCE(view_counts.count, 0)::integer,
    COALESCE(order_counts.count, 0)::integer,
    COALESCE(share_counts.count, 0)::integer
  FROM listings l
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_views
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) view_counts ON view_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM orders
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) order_counts ON order_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_shares
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) share_counts ON share_counts.listing_id = l.id
  WHERE l.available = true
  AND (
    COALESCE(view_counts.count, 0) > 0 OR
    COALESCE(order_counts.count, 0) > 0 OR
    COALESCE(share_counts.count, 0) > 0
  )
  ORDER BY trend_score DESC
  LIMIT 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
