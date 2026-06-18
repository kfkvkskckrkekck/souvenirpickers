/*
  # Add alert_enabled column to location_alerts

  1. Changes
    - Add `alert_enabled` column (boolean) to match frontend expectations
    - Keep `is_active` for backward compatibility
    - Set default to true

  2. Notes
    - Frontend uses `alert_enabled` field
    - This ensures compatibility with the LocationAlertsView component
*/

-- Add alert_enabled column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'location_alerts' AND column_name = 'alert_enabled'
  ) THEN
    ALTER TABLE location_alerts ADD COLUMN alert_enabled boolean DEFAULT true;
  END IF;
END $$;

-- Update existing rows to have alert_enabled match is_active
UPDATE location_alerts SET alert_enabled = is_active WHERE alert_enabled IS NULL;