/*
  # Add Portfolio Videos to Picker Profiles

  1. Changes
    - Add `portfolio_videos` column to `picker_profiles` table
      - `portfolio_videos` (text array) - URLs of portfolio videos showcasing picker's work
  
  2. Details
    - Allows pickers to upload and display videos in their profile
    - Videos can showcase items they've sourced or their travel experiences
    - Stored as an array of URLs from Supabase storage
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'portfolio_videos'
  ) THEN
    ALTER TABLE picker_profiles 
    ADD COLUMN portfolio_videos text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;