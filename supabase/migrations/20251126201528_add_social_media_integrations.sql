/*
  # Add Social Media Integrations

  1. Changes
    - Add social media link columns to `profiles` table
      - `facebook_url` (text) - Facebook profile/page URL
      - `twitter_url` (text) - Twitter/X profile URL
      - `instagram_url` (text) - Instagram profile URL
      - `threads_url` (text) - Threads profile URL

  2. Notes
    - Both pickers and clients can add social media links to their profiles
    - Links help build trust and allow users to verify authenticity
    - All fields are optional
*/

-- Add social media columns to profiles table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'facebook_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN facebook_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'twitter_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN twitter_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'instagram_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN instagram_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'threads_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN threads_url text;
  END IF;
END $$;