/*
  # Add TikTok Links Support

  1. Changes
    - Add `media_links` column to `listings` table for TikTok/external video links
    - Add `reference_links` column to `client_desires` table for TikTok/external video links
    - These columns complement existing videos arrays with text array for external links

  2. Notes
    - Both pickers and clients can now use TikTok links instead of uploading videos
    - Links are stored separately from uploaded videos for flexibility
    - Existing video functionality remains unchanged
*/

-- Add media_links to listings table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'media_links'
  ) THEN
    ALTER TABLE listings ADD COLUMN media_links text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;

-- Add reference_links to client_desires table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'client_desires' AND column_name = 'reference_links'
  ) THEN
    ALTER TABLE client_desires ADD COLUMN reference_links text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;