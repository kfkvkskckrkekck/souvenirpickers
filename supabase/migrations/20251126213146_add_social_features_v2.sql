-- Social Features: Follow Pickers and Share Listings
--
-- 1. New Tables
--    - listing_shares: Track when listings are shared
--
-- 2. Updates
--    - Add follower_count to picker_profiles
--
-- 3. Security
--    - Enable RLS on listing_shares

-- Create listing_shares table
CREATE TABLE IF NOT EXISTS listing_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  platform text,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE listing_shares ENABLE ROW LEVEL SECURITY;

-- Policies for listing_shares
CREATE POLICY "Anyone can record a share"
  ON listing_shares FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view all shares"
  ON listing_shares FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_listing_shares_listing_id ON listing_shares(listing_id);

-- Add follower count to picker_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'follower_count'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN follower_count integer DEFAULT 0;
  END IF;
END $$;

-- Function to update follower count
CREATE OR REPLACE FUNCTION update_picker_follower_count()
RETURNS TRIGGER AS $$
DECLARE
  picker_profile_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT id INTO picker_profile_id FROM picker_profiles WHERE user_id = NEW.picker_id;
    IF picker_profile_id IS NOT NULL THEN
      UPDATE picker_profiles SET follower_count = follower_count + 1 WHERE id = picker_profile_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT id INTO picker_profile_id FROM picker_profiles WHERE user_id = OLD.picker_id;
    IF picker_profile_id IS NOT NULL THEN
      UPDATE picker_profiles SET follower_count = GREATEST(0, follower_count - 1) WHERE id = picker_profile_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update follower count
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_follower_change_v2'
  ) THEN
    CREATE TRIGGER on_follower_change_v2
      AFTER INSERT OR DELETE ON favorite_pickers
      FOR EACH ROW
      EXECUTE FUNCTION update_picker_follower_count();
  END IF;
END $$;

-- Function to notify picker when followed
CREATE OR REPLACE FUNCTION notify_picker_followed()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, link)
  VALUES (
    NEW.picker_id,
    'new_follower',
    'New Follower',
    'Someone started following you!',
    '/profile'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new followers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_picker_followed_v2'
  ) THEN
    CREATE TRIGGER on_picker_followed_v2
      AFTER INSERT ON favorite_pickers
      FOR EACH ROW
      EXECUTE FUNCTION notify_picker_followed();
  END IF;
END $$;
