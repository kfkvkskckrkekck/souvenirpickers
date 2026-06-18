/*
  # Add pickup_video_uploaded_at column to orders

  1. Changes
    - Add `pickup_video_uploaded_at` column (timestamptz) to orders table
    - This tracks when the picker uploads the pickup video

  2. Notes
    - Frontend expects this field when uploading pickup videos
    - Works alongside pickup_video_url
*/

-- Add pickup_video_uploaded_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_uploaded_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_uploaded_at timestamptz;
  END IF;
END $$;