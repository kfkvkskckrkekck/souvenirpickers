/*
  # Update Location Alerts to Use Country and City

  1. Changes
    - Add `country` column (text, required)
    - Add `city` column (text, required)
    - Make `latitude` and `longitude` nullable (optional)
    - Make `radius_km` nullable (not needed for country/city matching)
    - Update constraints to allow null coordinates
    - Add index on country and city for fast matching

  2. Migration Strategy
    - Add new columns as nullable first
    - For existing data, populate country and city from location_name if possible
    - Then make country and city required
    - Make coordinates optional

  3. Security
    - No changes to RLS policies needed
*/

-- Add country and city columns
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'location_alerts' AND column_name = 'country'
  ) THEN
    ALTER TABLE location_alerts ADD COLUMN country text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'location_alerts' AND column_name = 'city'
  ) THEN
    ALTER TABLE location_alerts ADD COLUMN city text;
  END IF;
END $$;

-- For existing records, try to extract country and city from location_name
-- Format expected: "City, Country" (e.g., "Paris, France")
UPDATE location_alerts
SET
  city = TRIM(SPLIT_PART(location_name, ',', 1)),
  country = TRIM(SPLIT_PART(location_name, ',', 2))
WHERE country IS NULL AND city IS NULL AND location_name LIKE '%,%';

-- For records without a comma, use the whole location_name as city
UPDATE location_alerts
SET
  city = TRIM(location_name),
  country = 'Unknown'
WHERE country IS NULL AND city IS NULL;

-- Now make country and city required
ALTER TABLE location_alerts
  ALTER COLUMN country SET NOT NULL,
  ALTER COLUMN city SET NOT NULL;

-- Make latitude and longitude nullable (optional)
ALTER TABLE location_alerts
  ALTER COLUMN latitude DROP NOT NULL,
  ALTER COLUMN longitude DROP NOT NULL;

-- Drop the coordinate constraints since they're optional now
ALTER TABLE location_alerts DROP CONSTRAINT IF EXISTS valid_latitude;
ALTER TABLE location_alerts DROP CONSTRAINT IF EXISTS valid_longitude;

-- Add new constraints that only apply when coordinates are provided
ALTER TABLE location_alerts
  ADD CONSTRAINT valid_latitude_optional
  CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));

ALTER TABLE location_alerts
  ADD CONSTRAINT valid_longitude_optional
  CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));

-- Create indexes for country and city matching
CREATE INDEX IF NOT EXISTS idx_location_alerts_country ON location_alerts(country);
CREATE INDEX IF NOT EXISTS idx_location_alerts_city ON location_alerts(city);
CREATE INDEX IF NOT EXISTS idx_location_alerts_country_city ON location_alerts(country, city);

-- Drop the coordinates index since we're not using it for matching anymore
DROP INDEX IF EXISTS idx_location_alerts_coordinates;
