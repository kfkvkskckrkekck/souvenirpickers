/*
  # Add filed_by Column to Disputes Table

  1. Changes
    - Add `filed_by` column to disputes table
    - This column references the user who filed the dispute
  
  2. Security
    - Maintain existing RLS policies
*/

-- Add filed_by column to disputes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'disputes' AND column_name = 'filed_by'
  ) THEN
    ALTER TABLE disputes ADD COLUMN filed_by uuid REFERENCES profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_disputes_filed_by ON disputes(filed_by);