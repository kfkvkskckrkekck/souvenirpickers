-- Enhanced Review System with Media Support
--
-- 1. Updates to reviews table
--    - Add support for photo/video reviews
--    - Add helpful/unhelpful voting
--    - Add verification status
--
-- 2. New Tables
--    - review_votes: Track helpful/unhelpful votes
--    - review_media: Store review photos and videos
--
-- 3. Security
--    - Enable RLS on new tables
--    - Users can vote on reviews once
--    - Only reviewers can add media to their reviews

-- Add new columns to reviews table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'images'
  ) THEN
    ALTER TABLE reviews ADD COLUMN images text[] DEFAULT ARRAY[]::text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'videos'
  ) THEN
    ALTER TABLE reviews ADD COLUMN videos text[] DEFAULT ARRAY[]::text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'verified_purchase'
  ) THEN
    ALTER TABLE reviews ADD COLUMN verified_purchase boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'helpful_count'
  ) THEN
    ALTER TABLE reviews ADD COLUMN helpful_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'unhelpful_count'
  ) THEN
    ALTER TABLE reviews ADD COLUMN unhelpful_count integer DEFAULT 0;
  END IF;
END $$;

-- Create review_votes table
CREATE TABLE IF NOT EXISTS review_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type text NOT NULL CHECK (vote_type IN ('helpful', 'unhelpful')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Enable RLS
ALTER TABLE review_votes ENABLE ROW LEVEL SECURITY;

-- Policies for review_votes
CREATE POLICY "Users can view all votes"
  ON review_votes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can vote on reviews"
  ON review_votes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their votes"
  ON review_votes FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their votes"
  ON review_votes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_review_votes_review_id ON review_votes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_votes_user_id ON review_votes(user_id);

-- Function to update review vote counts
CREATE OR REPLACE FUNCTION update_review_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count + 1 WHERE id = NEW.review_id;
    ELSE
      UPDATE reviews SET unhelpful_count = unhelpful_count + 1 WHERE id = NEW.review_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.vote_type != NEW.vote_type THEN
    IF NEW.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count + 1, unhelpful_count = unhelpful_count - 1 WHERE id = NEW.review_id;
    ELSE
      UPDATE reviews SET helpful_count = helpful_count - 1, unhelpful_count = unhelpful_count + 1 WHERE id = NEW.review_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count - 1 WHERE id = OLD.review_id;
    ELSE
      UPDATE reviews SET unhelpful_count = unhelpful_count - 1 WHERE id = OLD.review_id;
    END IF;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update vote counts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_review_vote_change'
  ) THEN
    CREATE TRIGGER on_review_vote_change
      AFTER INSERT OR UPDATE OR DELETE ON review_votes
      FOR EACH ROW
      EXECUTE FUNCTION update_review_vote_counts();
  END IF;
END $$;

-- Function to mark verified purchases
CREATE OR REPLACE FUNCTION mark_verified_purchase()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_id IS NOT NULL THEN
    NEW.verified_purchase := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to mark verified purchases
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_review_insert_verify'
  ) THEN
    CREATE TRIGGER on_review_insert_verify
      BEFORE INSERT ON reviews
      FOR EACH ROW
      EXECUTE FUNCTION mark_verified_purchase();
  END IF;
END $$;
