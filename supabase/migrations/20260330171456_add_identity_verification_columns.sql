/*
  # Add missing columns to identity_verifications table

  1. Changes
    - Add document_url column to store uploaded verification documents
    - Add rejection_reason column for storing admin feedback
    - Add verified_at column to track when verification was approved
    - Rename submitted_at to created_at for consistency with component
  
  2. Security
    - No RLS changes needed, existing policies remain
*/

-- Add missing columns
DO $$ 
BEGIN
  -- Add document_url if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'identity_verifications' AND column_name = 'document_url'
  ) THEN
    ALTER TABLE identity_verifications ADD COLUMN document_url text;
  END IF;

  -- Add rejection_reason if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'identity_verifications' AND column_name = 'rejection_reason'
  ) THEN
    ALTER TABLE identity_verifications ADD COLUMN rejection_reason text;
  END IF;

  -- Add verified_at if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'identity_verifications' AND column_name = 'verified_at'
  ) THEN
    ALTER TABLE identity_verifications ADD COLUMN verified_at timestamptz;
  END IF;

  -- Add created_at if it doesn't exist (rename submitted_at)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'identity_verifications' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE identity_verifications ADD COLUMN created_at timestamptz DEFAULT now();
    
    -- Copy data from submitted_at if it exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'identity_verifications' AND column_name = 'submitted_at'
    ) THEN
      UPDATE identity_verifications SET created_at = submitted_at WHERE created_at IS NULL;
    END IF;
  END IF;
END $$;