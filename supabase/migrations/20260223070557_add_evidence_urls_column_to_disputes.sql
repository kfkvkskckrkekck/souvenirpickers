/*
  # Add evidence_urls Column to Disputes Table

  1. Changes
    - Add `evidence_urls` column to disputes table
    - This column stores an array of evidence file URLs
  
  2. Security
    - Maintain existing RLS policies
*/

-- Add evidence_urls column to disputes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'disputes' AND column_name = 'evidence_urls'
  ) THEN
    ALTER TABLE disputes ADD COLUMN evidence_urls text[] DEFAULT '{}';
  END IF;
END $$;