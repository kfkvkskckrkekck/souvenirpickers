/*
  # Create Location Alerts System

  1. New Tables
    - `location_alerts`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to profiles)
      - `location_name` (text, name of the location to watch)
      - `latitude` (numeric, latitude coordinate)
      - `longitude` (numeric, longitude coordinate)
      - `radius_km` (numeric, alert radius in kilometers)
      - `item_types` (jsonb, types of items to alert for)
      - `keywords` (text[], keywords to match)
      - `min_price` (numeric, minimum price filter)
      - `max_price` (numeric, maximum price filter)
      - `is_active` (boolean, whether alert is active)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on location_alerts table
    - Users can only manage their own alerts
    - Policies for CRUD operations

  3. Indexes
    - Index on user_id for fast lookup
    - Index on location coordinates for spatial queries
    - Index on is_active for filtering active alerts
*/

-- Create location_alerts table
CREATE TABLE IF NOT EXISTS location_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  location_name text NOT NULL,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  radius_km numeric DEFAULT 10,
  item_types jsonb DEFAULT '[]'::jsonb,
  keywords text[] DEFAULT ARRAY[]::text[],
  min_price numeric DEFAULT 0,
  max_price numeric,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
  CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180),
  CONSTRAINT valid_radius CHECK (radius_km > 0)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_location_alerts_user_id ON location_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_location_alerts_coordinates ON location_alerts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_location_alerts_is_active ON location_alerts(is_active);
CREATE INDEX IF NOT EXISTS idx_location_alerts_updated_at ON location_alerts(updated_at DESC);

-- Enable RLS
ALTER TABLE location_alerts ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT ALL ON location_alerts TO authenticated;
GRANT ALL ON location_alerts TO service_role;

-- RLS Policies
CREATE POLICY "Users can view their own location alerts"
  ON location_alerts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own location alerts"
  ON location_alerts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own location alerts"
  ON location_alerts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their own location alerts"
  ON location_alerts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_location_alert_timestamp()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Trigger to auto-update timestamp
DROP TRIGGER IF EXISTS update_location_alert_timestamp_trigger ON location_alerts;
CREATE TRIGGER update_location_alert_timestamp_trigger
  BEFORE UPDATE ON location_alerts
  FOR EACH ROW
  EXECUTE FUNCTION update_location_alert_timestamp();