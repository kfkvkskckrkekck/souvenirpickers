/*
  # Create Smart Desire Matching System

  1. New Tables
    - `desire_matches`
      - `id` (uuid, primary key)
      - `desire_id` (uuid, references client_desires)
      - `picker_id` (uuid, references profiles)
      - `match_score` (integer) - Overall score 0-100
      - `distance_km` (decimal) - Distance from desire location to picker
      - `picker_rating` (decimal) - Picker's average rating
      - `viewed_at` (timestamptz) - When client viewed this match
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Functions
    - `calculate_desire_matches()` - Finds and scores pickers for desires
    - Match scoring algorithm:
      - Distance: 40 points (closer = better)
      - Rating: 30 points (higher rating = better)
      - Experience: 20 points (more orders = better)
      - Activity: 10 points (recent activity = better)

  3. Triggers
    - Automatically run matching when new desires are created
    - Re-run matching when desires are updated

  4. Security
    - Enable RLS on desire_matches
    - Clients can view their own matches
    - System can insert/update matches
*/

-- Create desire_matches table
CREATE TABLE IF NOT EXISTS desire_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  desire_id uuid NOT NULL REFERENCES client_desires(id) ON DELETE CASCADE,
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  match_score integer NOT NULL DEFAULT 0 CHECK (match_score >= 0 AND match_score <= 100),
  distance_km decimal(10,2),
  picker_rating decimal(3,2) DEFAULT 0,
  viewed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(desire_id, picker_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_desire_matches_desire_id ON desire_matches(desire_id);
CREATE INDEX IF NOT EXISTS idx_desire_matches_picker_id ON desire_matches(picker_id);
CREATE INDEX IF NOT EXISTS idx_desire_matches_score ON desire_matches(match_score DESC);

-- Enable RLS
ALTER TABLE desire_matches ENABLE ROW LEVEL SECURITY;

-- Clients can view matches for their desires
CREATE POLICY "Clients can view their desire matches"
  ON desire_matches
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM client_desires
      WHERE client_desires.id = desire_matches.desire_id
      AND client_desires.client_id = auth.uid()
    )
  );

-- Clients can update viewed_at for their matches
CREATE POLICY "Clients can update their match views"
  ON desire_matches
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM client_desires
      WHERE client_desires.id = desire_matches.desire_id
      AND client_desires.client_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM client_desires
      WHERE client_desires.id = desire_matches.desire_id
      AND client_desires.client_id = auth.uid()
    )
  );

-- Service role can manage all matches (for automatic matching)
GRANT ALL ON desire_matches TO service_role;
GRANT ALL ON desire_matches TO authenticated;

-- Function to calculate distance between two points (simplified Haversine)
CREATE OR REPLACE FUNCTION calculate_distance(lat1 float, lon1 float, lat2 float, lon2 float)
RETURNS float AS $$
DECLARE
  R float := 6371; -- Earth's radius in km
  dLat float;
  dLon float;
  a float;
  c float;
BEGIN
  dLat := radians(lat2 - lat1);
  dLon := radians(lon2 - lon1);
  a := sin(dLat/2) * sin(dLat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon/2) * sin(dLon/2);
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate desire matches
CREATE OR REPLACE FUNCTION calculate_desire_matches(p_desire_id uuid)
RETURNS void AS $$
DECLARE
  v_desire client_desires%ROWTYPE;
  v_picker RECORD;
  v_distance_score integer;
  v_rating_score integer;
  v_experience_score integer;
  v_activity_score integer;
  v_total_score integer;
  v_distance_km decimal;
  v_picker_rating decimal;
  v_total_orders integer;
  v_days_since_active integer;
BEGIN
  -- Get the desire
  SELECT * INTO v_desire FROM client_desires WHERE id = p_desire_id AND active = true;
  
  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Only match if desire has GPS coordinates
  IF v_desire.latitude IS NULL OR v_desire.longitude IS NULL THEN
    RETURN;
  END IF;

  -- Delete old matches for this desire
  DELETE FROM desire_matches WHERE desire_id = p_desire_id;

  -- Find potential pickers with location data
  FOR v_picker IN
    SELECT 
      p.id,
      p.user_type,
      pp.latitude,
      pp.longitude,
      pp.current_location,
      pp.location_updated_at,
      COALESCE(pp.rating, 0) as avg_rating,
      COUNT(DISTINCT o.id) as total_orders
    FROM profiles p
    LEFT JOIN picker_profiles pp ON pp.user_id = p.id
    LEFT JOIN orders o ON o.picker_id = p.id AND o.status = 'delivered'
    WHERE 
      p.user_type = 'picker'
      AND pp.latitude IS NOT NULL 
      AND pp.longitude IS NOT NULL
    GROUP BY p.id, pp.latitude, pp.longitude, pp.current_location, pp.location_updated_at, pp.rating
  LOOP
    -- Calculate distance in km
    v_distance_km := calculate_distance(
      v_desire.latitude::float,
      v_desire.longitude::float,
      v_picker.latitude::float,
      v_picker.longitude::float
    );

    -- Only match if within 500km
    IF v_distance_km <= 500 THEN
      -- Calculate distance score (40 points max)
      -- 0-50km: 40 pts, 50-150km: 30 pts, 150-300km: 20 pts, 300-500km: 10 pts
      IF v_distance_km <= 50 THEN
        v_distance_score := 40;
      ELSIF v_distance_km <= 150 THEN
        v_distance_score := 30;
      ELSIF v_distance_km <= 300 THEN
        v_distance_score := 20;
      ELSE
        v_distance_score := 10;
      END IF;

      -- Calculate rating score (30 points max)
      v_picker_rating := v_picker.avg_rating;
      v_rating_score := LEAST(30, (v_picker_rating * 6)::integer);

      -- Calculate experience score (20 points max)
      v_total_orders := COALESCE(v_picker.total_orders, 0);
      IF v_total_orders >= 50 THEN
        v_experience_score := 20;
      ELSIF v_total_orders >= 20 THEN
        v_experience_score := 15;
      ELSIF v_total_orders >= 5 THEN
        v_experience_score := 10;
      ELSE
        v_experience_score := LEAST(10, v_total_orders * 2);
      END IF;

      -- Calculate activity score (10 points max)
      v_days_since_active := EXTRACT(DAY FROM (now() - COALESCE(v_picker.location_updated_at, now() - interval '365 days')));
      IF v_days_since_active <= 7 THEN
        v_activity_score := 10;
      ELSIF v_days_since_active <= 30 THEN
        v_activity_score := 7;
      ELSIF v_days_since_active <= 90 THEN
        v_activity_score := 5;
      ELSE
        v_activity_score := 2;
      END IF;

      -- Calculate total score
      v_total_score := v_distance_score + v_rating_score + v_experience_score + v_activity_score;

      -- Insert match
      INSERT INTO desire_matches (
        desire_id,
        picker_id,
        match_score,
        distance_km,
        picker_rating
      ) VALUES (
        p_desire_id,
        v_picker.id,
        v_total_score,
        v_distance_km,
        v_picker_rating
      )
      ON CONFLICT (desire_id, picker_id) DO UPDATE
      SET 
        match_score = EXCLUDED.match_score,
        distance_km = EXCLUDED.distance_km,
        picker_rating = EXCLUDED.picker_rating,
        updated_at = now();
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically calculate matches when desire is created/updated
CREATE OR REPLACE FUNCTION trigger_calculate_desire_matches()
RETURNS TRIGGER AS $$
BEGIN
  -- Only calculate if desire has GPS coordinates
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL AND NEW.active = true THEN
    PERFORM calculate_desire_matches(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS auto_calculate_desire_matches ON client_desires;
CREATE TRIGGER auto_calculate_desire_matches
  AFTER INSERT OR UPDATE OF latitude, longitude, active
  ON client_desires
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_desire_matches();

-- Calculate matches for all existing active desires with GPS coordinates
DO $$
DECLARE
  v_desire_record RECORD;
BEGIN
  FOR v_desire_record IN 
    SELECT id FROM client_desires 
    WHERE active = true 
    AND latitude IS NOT NULL 
    AND longitude IS NOT NULL
  LOOP
    PERFORM calculate_desire_matches(v_desire_record.id);
  END LOOP;
END $$;
