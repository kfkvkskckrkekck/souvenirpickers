/*
  # Add video support to listings

  ## Overview
  This migration adds a videos column to the listings table to support multiple video uploads.

  ## 1. Changes
  - Add `videos` column to `listings` table (text array)
  - This column will store URLs of uploaded videos

  ## 2. Notes
  - Existing listings will have an empty array for videos by default
  - Pickers can upload multiple videos for each listing
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'videos'
  ) THEN
    ALTER TABLE listings ADD COLUMN videos text[] DEFAULT '{}';
  END IF;
END $$;