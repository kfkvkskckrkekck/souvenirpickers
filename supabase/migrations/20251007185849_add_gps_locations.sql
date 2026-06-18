/*
  # Add GPS location support

  ## Overview
  This migration adds GPS coordinates and enhanced region support for pickers and listings.

  ## 1. Changes to picker_profiles
  - Add `latitude` column (numeric, stores GPS latitude)
  - Add `longitude` column (numeric, stores GPS longitude)
  - Add `location_updated_at` column (timestamp, tracks when location was last updated)

  ## 2. Changes to listings
  - Add `latitude` column (numeric, stores listing-specific GPS latitude)
  - Add `longitude` column (numeric, stores listing-specific GPS longitude)
  - Add `pickup_location` column (text, human-readable pickup address)

  ## 3. Notes
  - GPS coordinates allow precise location tracking for pickers
  - Listings can have specific pickup locations different from picker's current location
  - Coordinates can be used for map displays and proximity searches
  - All GPS fields are optional to respect privacy
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN latitude numeric(10, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'longitude'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN longitude numeric(11, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'location_updated_at'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN location_updated_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE listings ADD COLUMN latitude numeric(10, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'longitude'
  ) THEN
    ALTER TABLE listings ADD COLUMN longitude numeric(11, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'pickup_location'
  ) THEN
    ALTER TABLE listings ADD COLUMN pickup_location text;
  END IF;
END $$;