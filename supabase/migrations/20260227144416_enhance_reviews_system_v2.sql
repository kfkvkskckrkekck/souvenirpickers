/*
  # Enhanced Review System for Pickers
  
  1. New Tables
    - `review_votes` - Track helpful/unhelpful votes on reviews
    - `review_statistics` - Cached picker review metrics for performance
    - `review_reports` - Flag inappropriate reviews for moderation

  2. Enhancements to Existing Tables
    - Add columns to `reviews` table for voting, verification, and moderation

  3. Indexes for performance optimization

  4. Security
    - Enable RLS on all new tables
    - Add comprehensive policies for authenticated users

  5. Functions and Triggers
    - Automatic review statistics updates
    - Automatic helpful vote counting
*/

-- Add new columns to existing reviews table
DO $$
BEGIN
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

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'is_verified_purchase'
  ) THEN
    ALTER TABLE reviews ADD COLUMN is_verified_purchase boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'category_tags'
  ) THEN
    ALTER TABLE reviews ADD COLUMN category_tags text[] DEFAULT ARRAY[]::text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'is_edited'
  ) THEN
    ALTER TABLE reviews ADD COLUMN is_edited boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'edited_at'
  ) THEN
    ALTER TABLE reviews ADD COLUMN edited_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'is_flagged'
  ) THEN
    ALTER TABLE reviews ADD COLUMN is_flagged boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reviews' AND column_name = 'is_hidden'
  ) THEN
    ALTER TABLE reviews ADD COLUMN is_hidden boolean DEFAULT false;
  END IF;
END $$;

-- Create review_votes table
CREATE TABLE IF NOT EXISTS review_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  vote_type text NOT NULL CHECK (vote_type IN ('helpful', 'unhelpful')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Create review_statistics table
CREATE TABLE IF NOT EXISTS review_statistics (
  picker_id uuid PRIMARY KEY REFERENCES picker_profiles(id) ON DELETE CASCADE,
  total_reviews integer DEFAULT 0,
  average_rating numeric(3,2) DEFAULT 0.00,
  rating_1_count integer DEFAULT 0,
  rating_2_count integer DEFAULT 0,
  rating_3_count integer DEFAULT 0,
  rating_4_count integer DEFAULT 0,
  rating_5_count integer DEFAULT 0,
  verified_reviews_count integer DEFAULT 0,
  response_rate numeric(5,2) DEFAULT 0.00,
  avg_response_time_hours numeric(10,2),
  last_review_at timestamptz,
  updated_at timestamptz DEFAULT now()
);

-- Create review_reports table
CREATE TABLE IF NOT EXISTS review_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  details text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  resolved_by uuid REFERENCES profiles(id),
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_review_votes_review_id ON review_votes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_votes_user_id ON review_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_review_reports_review_id ON review_reports(review_id);
CREATE INDEX IF NOT EXISTS idx_review_reports_status ON review_reports(status);
CREATE INDEX IF NOT EXISTS idx_reviews_verified ON reviews(is_verified_purchase);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);

-- Enable RLS
ALTER TABLE review_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for reviews
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Anyone can view non-hidden reviews'
  ) THEN
    CREATE POLICY "Anyone can view non-hidden reviews"
      ON reviews FOR SELECT
      USING (is_hidden = false);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Users can create reviews for completed orders'
  ) THEN
    CREATE POLICY "Users can create reviews for completed orders"
      ON reviews FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = client_id AND
        EXISTS (
          SELECT 1 FROM orders 
          WHERE orders.id = order_id 
          AND orders.client_id = auth.uid()
          AND orders.status = 'completed'
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Users can update their own reviews within 24 hours'
  ) THEN
    CREATE POLICY "Users can update their own reviews within 24 hours"
      ON reviews FOR UPDATE
      TO authenticated
      USING (
        auth.uid() = client_id AND
        created_at > now() - interval '24 hours'
      )
      WITH CHECK (auth.uid() = client_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'reviews' AND policyname = 'Pickers can respond to their reviews'
  ) THEN
    CREATE POLICY "Pickers can respond to their reviews"
      ON reviews FOR UPDATE
      TO authenticated
      USING (
        auth.uid() = picker_id AND
        response IS NULL
      )
      WITH CHECK (
        auth.uid() = picker_id AND
        response IS NOT NULL
      );
  END IF;
END $$;

-- RLS Policies for review_votes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_votes' AND policyname = 'Anyone can view vote counts'
  ) THEN
    CREATE POLICY "Anyone can view vote counts"
      ON review_votes FOR SELECT
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_votes' AND policyname = 'Authenticated users can vote on reviews'
  ) THEN
    CREATE POLICY "Authenticated users can vote on reviews"
      ON review_votes FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_votes' AND policyname = 'Users can update their own votes'
  ) THEN
    CREATE POLICY "Users can update their own votes"
      ON review_votes FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_votes' AND policyname = 'Users can delete their own votes'
  ) THEN
    CREATE POLICY "Users can delete their own votes"
      ON review_votes FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- RLS Policies for review_statistics
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_statistics' AND policyname = 'Anyone can view review statistics'
  ) THEN
    CREATE POLICY "Anyone can view review statistics"
      ON review_statistics FOR SELECT
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_statistics' AND policyname = 'System can insert review statistics'
  ) THEN
    CREATE POLICY "System can insert review statistics"
      ON review_statistics FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_statistics' AND policyname = 'System can modify review statistics'
  ) THEN
    CREATE POLICY "System can modify review statistics"
      ON review_statistics FOR UPDATE
      TO authenticated
      USING (true);
  END IF;
END $$;

-- RLS Policies for review_reports
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_reports' AND policyname = 'Users can view their own reports'
  ) THEN
    CREATE POLICY "Users can view their own reports"
      ON review_reports FOR SELECT
      TO authenticated
      USING (auth.uid() = reporter_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'review_reports' AND policyname = 'Authenticated users can report reviews'
  ) THEN
    CREATE POLICY "Authenticated users can report reviews"
      ON review_reports FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

-- Function to update review statistics
CREATE OR REPLACE FUNCTION update_review_statistics()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO review_statistics (
    picker_id,
    total_reviews,
    average_rating,
    rating_1_count,
    rating_2_count,
    rating_3_count,
    rating_4_count,
    rating_5_count,
    verified_reviews_count,
    response_rate,
    avg_response_time_hours,
    last_review_at,
    updated_at
  )
  SELECT 
    picker_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating)::numeric, 2) as average_rating,
    COUNT(*) FILTER (WHERE rating = 1) as rating_1_count,
    COUNT(*) FILTER (WHERE rating = 2) as rating_2_count,
    COUNT(*) FILTER (WHERE rating = 3) as rating_3_count,
    COUNT(*) FILTER (WHERE rating = 4) as rating_4_count,
    COUNT(*) FILTER (WHERE rating = 5) as rating_5_count,
    COUNT(*) FILTER (WHERE is_verified_purchase = true) as verified_reviews_count,
    ROUND((COUNT(*) FILTER (WHERE response IS NOT NULL)::numeric / NULLIF(COUNT(*), 0) * 100), 2) as response_rate,
    ROUND(AVG(EXTRACT(EPOCH FROM (response_at - created_at)) / 3600)::numeric, 2) as avg_response_time_hours,
    MAX(created_at) as last_review_at,
    now() as updated_at
  FROM reviews
  WHERE picker_id = COALESCE(NEW.picker_id, OLD.picker_id)
  GROUP BY picker_id
  ON CONFLICT (picker_id) 
  DO UPDATE SET
    total_reviews = EXCLUDED.total_reviews,
    average_rating = EXCLUDED.average_rating,
    rating_1_count = EXCLUDED.rating_1_count,
    rating_2_count = EXCLUDED.rating_2_count,
    rating_3_count = EXCLUDED.rating_3_count,
    rating_4_count = EXCLUDED.rating_4_count,
    rating_5_count = EXCLUDED.rating_5_count,
    verified_reviews_count = EXCLUDED.verified_reviews_count,
    response_rate = EXCLUDED.response_rate,
    avg_response_time_hours = EXCLUDED.avg_response_time_hours,
    last_review_at = EXCLUDED.last_review_at,
    updated_at = now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update review statistics
DROP TRIGGER IF EXISTS trigger_update_review_statistics ON reviews;
CREATE TRIGGER trigger_update_review_statistics
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_review_statistics();

-- Function to update helpful counts
CREATE OR REPLACE FUNCTION update_review_helpful_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE reviews
    SET 
      helpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = NEW.review_id AND vote_type = 'helpful'),
      unhelpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = NEW.review_id AND vote_type = 'unhelpful')
    WHERE id = NEW.review_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE reviews
    SET 
      helpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = OLD.review_id AND vote_type = 'helpful'),
      unhelpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = OLD.review_id AND vote_type = 'unhelpful')
    WHERE id = OLD.review_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update helpful counts
DROP TRIGGER IF EXISTS trigger_update_helpful_counts ON review_votes;
CREATE TRIGGER trigger_update_helpful_counts
  AFTER INSERT OR UPDATE OR DELETE ON review_votes
  FOR EACH ROW
  EXECUTE FUNCTION update_review_helpful_counts();
