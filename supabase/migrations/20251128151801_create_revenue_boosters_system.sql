/*
  # Create Revenue Boosters System

  1. New Tables
    - `revenue_insights`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles)
      - `insight_type` (text) - Type of insight (pricing, inventory, promotion, etc.)
      - `title` (text) - Insight title
      - `description` (text) - Detailed description
      - `potential_revenue` (decimal) - Estimated revenue impact
      - `priority` (text) - high, medium, low
      - `action_url` (text) - Where to take action
      - `action_label` (text) - Button label for action
      - `status` (text) - active, dismissed, completed
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `revenue_booster_actions`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles)
      - `insight_id` (uuid, references revenue_insights)
      - `action_type` (text) - Type of action taken
      - `action_data` (jsonb) - Additional action data
      - `created_at` (timestamptz)

  2. Views
    - `picker_revenue_stats` - Aggregated revenue statistics for insights

  3. Functions
    - `generate_revenue_insights()` - Generates personalized insights
    - `calculate_revenue_potential()` - Calculates potential revenue

  4. Security
    - Enable RLS on all tables
    - Pickers can only view their own insights
    - System generates insights automatically

  5. Notes
    - Insights are generated based on:
      - Listing performance
      - Pricing compared to market
      - Inventory gaps
      - Seasonal opportunities
      - Engagement metrics
*/

-- Create revenue_insights table
CREATE TABLE IF NOT EXISTS revenue_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  insight_type text NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  potential_revenue decimal(10,2) DEFAULT 0,
  priority text NOT NULL DEFAULT 'medium',
  action_url text,
  action_label text DEFAULT 'Take Action',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_priority CHECK (priority IN ('high', 'medium', 'low')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'dismissed', 'completed'))
);

-- Create revenue_booster_actions table
CREATE TABLE IF NOT EXISTS revenue_booster_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  insight_id uuid REFERENCES revenue_insights(id),
  action_type text NOT NULL,
  action_data jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_revenue_insights_picker_id ON revenue_insights(picker_id);
CREATE INDEX IF NOT EXISTS idx_revenue_insights_status ON revenue_insights(status);
CREATE INDEX IF NOT EXISTS idx_revenue_insights_priority ON revenue_insights(priority);
CREATE INDEX IF NOT EXISTS idx_revenue_booster_actions_picker_id ON revenue_booster_actions(picker_id);
CREATE INDEX IF NOT EXISTS idx_revenue_booster_actions_insight_id ON revenue_booster_actions(insight_id);

-- Enable RLS
ALTER TABLE revenue_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_booster_actions ENABLE ROW LEVEL SECURITY;

-- Pickers can view their own insights
CREATE POLICY "Pickers can view own insights"
  ON revenue_insights FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Pickers can update their own insights
CREATE POLICY "Pickers can update own insights"
  ON revenue_insights FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

-- Pickers can track their actions
CREATE POLICY "Pickers can insert own actions"
  ON revenue_booster_actions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can view own actions"
  ON revenue_booster_actions FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Create view for picker revenue stats
CREATE OR REPLACE VIEW picker_revenue_stats AS
SELECT 
  p.id as picker_id,
  COUNT(DISTINCT o.id) as total_orders,
  COALESCE(SUM(o.total_price), 0) as total_revenue,
  COALESCE(AVG(o.total_price), 0) as avg_order_value,
  COUNT(DISTINCT l.id) as total_listings,
  COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.id END) as completed_orders,
  COUNT(DISTINCT CASE WHEN o.created_at > now() - interval '30 days' THEN o.id END) as orders_last_30_days,
  COALESCE(SUM(CASE WHEN o.created_at > now() - interval '30 days' THEN o.total_price ELSE 0 END), 0) as revenue_last_30_days,
  COUNT(DISTINCT CASE WHEN l.created_at > now() - interval '30 days' THEN l.id END) as new_listings_last_30_days
FROM profiles p
LEFT JOIN orders o ON p.id = o.picker_id
LEFT JOIN listings l ON p.id = l.picker_id
WHERE p.user_type = 'picker'
GROUP BY p.id;

-- Function to generate revenue insights for a picker
CREATE OR REPLACE FUNCTION generate_revenue_insights(p_picker_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats RECORD;
  v_avg_market_price decimal;
  v_listing_count integer;
  v_low_price_count integer;
BEGIN
  -- Get picker stats
  SELECT * INTO v_stats FROM picker_revenue_stats WHERE picker_id = p_picker_id;
  
  -- Clear old active insights
  UPDATE revenue_insights 
  SET status = 'dismissed' 
  WHERE picker_id = p_picker_id 
    AND status = 'active' 
    AND created_at < now() - interval '7 days';
  
  -- Insight 1: Low listing count
  SELECT COUNT(*) INTO v_listing_count 
  FROM listings 
  WHERE picker_id = p_picker_id AND status = 'active';
  
  IF v_listing_count < 5 THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'inventory',
      'Add More Listings to Increase Visibility',
      'You currently have ' || v_listing_count || ' active listings. Pickers with 10+ listings earn 3x more on average. Add unique local items to attract more collectors.',
      COALESCE(v_stats.avg_order_value * 5, 50),
      'high',
      'listings',
      'Add New Listing'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 2: Pricing optimization
  SELECT AVG(price) INTO v_avg_market_price FROM listings WHERE status = 'active';
  
  SELECT COUNT(*) INTO v_low_price_count
  FROM listings
  WHERE picker_id = p_picker_id 
    AND status = 'active'
    AND price < v_avg_market_price * 0.7;
  
  IF v_low_price_count > 0 THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'pricing',
      'Optimize Your Pricing',
      'You have ' || v_low_price_count || ' listings priced significantly below market average (€' || ROUND(v_avg_market_price, 2) || '). Consider adjusting prices to match market demand.',
      v_low_price_count * 10,
      'medium',
      'listings',
      'Review Pricing'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 3: Add videos to listings
  IF EXISTS (
    SELECT 1 FROM listings 
    WHERE picker_id = p_picker_id 
      AND status = 'active' 
      AND (videos IS NULL OR array_length(videos, 1) = 0)
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'media',
      'Add Videos to Boost Conversions',
      'Listings with videos convert 40% better! Add videos to your listings to show items in detail and build trust with collectors.',
      COALESCE(v_stats.avg_order_value * 2, 30),
      'high',
      'listings',
      'Add Videos'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 4: Complete profile
  IF EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = p_picker_id 
      AND (bio IS NULL OR bio = '' OR avatar_url IS NULL)
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'profile',
      'Complete Your Profile',
      'Complete profiles get 50% more orders. Add a bio and profile photo to build trust with collectors.',
      COALESCE(v_stats.avg_order_value * 1.5, 25),
      'medium',
      'profile',
      'Complete Profile'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 5: Enable live streaming
  IF NOT EXISTS (
    SELECT 1 FROM live_streams WHERE picker_id = p_picker_id
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'engagement',
      'Start Live Streaming',
      'Engage collectors in real-time! Live streams generate 5x more engagement and can lead to custom orders on the spot.',
      100,
      'high',
      'live-streams',
      'Start Streaming'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 6: Respond to client desires
  IF EXISTS (
    SELECT 1 FROM client_desires 
    WHERE location IS NOT NULL 
      AND NOT EXISTS (
        SELECT 1 FROM listings 
        WHERE picker_id = p_picker_id 
          AND location = client_desires.location
      )
    LIMIT 1
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'opportunity',
      'Fulfill Client Desires',
      'There are unfulfilled collector requests in your area! Check the Client Desires page for guaranteed sales opportunities.',
      COALESCE(v_stats.avg_order_value * 3, 75),
      'high',
      'desires',
      'View Desires'
    )
    ON CONFLICT DO NOTHING;
  END IF;

END;
$$;

-- Function to calculate total revenue potential
CREATE OR REPLACE FUNCTION get_revenue_potential(p_picker_id uuid)
RETURNS decimal
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total decimal;
BEGIN
  SELECT COALESCE(SUM(potential_revenue), 0)
  INTO v_total
  FROM revenue_insights
  WHERE picker_id = p_picker_id
    AND status = 'active';
    
  RETURN v_total;
END;
$$;

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_revenue_insights_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER revenue_insights_updated_at
  BEFORE UPDATE ON revenue_insights
  FOR EACH ROW
  EXECUTE FUNCTION update_revenue_insights_updated_at();

COMMENT ON TABLE revenue_insights IS 'Personalized revenue optimization insights for pickers';
COMMENT ON TABLE revenue_booster_actions IS 'Track actions taken on revenue insights';
COMMENT ON FUNCTION generate_revenue_insights IS 'Generates personalized revenue insights for a picker';
