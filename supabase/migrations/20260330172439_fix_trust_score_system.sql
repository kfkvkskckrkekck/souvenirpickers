/*
  # Fix trust score system

  1. Changes
    - Add missing columns to trust_scores table
    - Create calculate_trust_score function
    - Add RLS policies for trust_scores
  
  2. Security
    - Users can view their own trust scores
    - Only the system can update trust scores
*/

-- Add missing columns to trust_scores table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'overall_score'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN overall_score integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'verification_score'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN verification_score integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'transaction_score'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN transaction_score integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'review_score'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN review_score integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'responsiveness_score'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN responsiveness_score integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'successful_transactions'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN successful_transactions integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'disputes_filed'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN disputes_filed integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'disputes_against'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN disputes_against integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trust_scores' AND column_name = 'last_calculated_at'
  ) THEN
    ALTER TABLE trust_scores ADD COLUMN last_calculated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Create calculate_trust_score function
CREATE OR REPLACE FUNCTION calculate_trust_score(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification_score integer := 0;
  v_transaction_score integer := 0;
  v_review_score integer := 0;
  v_responsiveness_score integer := 0;
  v_completed_orders integer := 0;
  v_successful_transactions integer := 0;
  v_disputes_filed integer := 0;
  v_disputes_against integer := 0;
  v_avg_rating numeric;
BEGIN
  -- Calculate verification score (25 points max)
  SELECT COUNT(*) INTO v_verification_score
  FROM identity_verifications
  WHERE user_id = p_user_id AND status = 'approved';
  
  v_verification_score := LEAST(v_verification_score * 25, 25);

  -- Calculate transaction score (35 points max, 3 points per order)
  SELECT COUNT(*) INTO v_completed_orders
  FROM orders
  WHERE (picker_id = p_user_id OR client_id = p_user_id)
    AND status = 'delivered';
  
  v_successful_transactions := v_completed_orders;
  v_transaction_score := LEAST(v_completed_orders * 3, 35);

  -- Calculate review score (25 points max)
  SELECT AVG(rating) INTO v_avg_rating
  FROM reviews
  WHERE reviewed_user_id = p_user_id;
  
  IF v_avg_rating IS NOT NULL THEN
    v_review_score := LEAST(ROUND((v_avg_rating / 5.0) * 25)::integer, 25);
  END IF;

  -- Calculate responsiveness score (15 points max)
  -- For now, give partial credit based on activity
  v_responsiveness_score := CASE
    WHEN v_completed_orders >= 10 THEN 15
    WHEN v_completed_orders >= 5 THEN 10
    WHEN v_completed_orders >= 1 THEN 5
    ELSE 0
  END;

  -- Count disputes
  SELECT COUNT(*) INTO v_disputes_filed
  FROM disputes
  WHERE filed_by = p_user_id;

  SELECT COUNT(*) INTO v_disputes_against
  FROM disputes
  WHERE against_user = p_user_id;

  -- Insert or update trust score
  INSERT INTO trust_scores (
    user_id,
    overall_score,
    verification_score,
    transaction_score,
    review_score,
    responsiveness_score,
    completed_orders,
    successful_transactions,
    disputes_filed,
    disputes_against,
    last_calculated_at,
    score
  ) VALUES (
    p_user_id,
    v_verification_score + v_transaction_score + v_review_score + v_responsiveness_score,
    v_verification_score,
    v_transaction_score,
    v_review_score,
    v_responsiveness_score,
    v_completed_orders,
    v_successful_transactions,
    v_disputes_filed,
    v_disputes_against,
    now(),
    v_verification_score + v_transaction_score + v_review_score + v_responsiveness_score
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    overall_score = EXCLUDED.overall_score,
    verification_score = EXCLUDED.verification_score,
    transaction_score = EXCLUDED.transaction_score,
    review_score = EXCLUDED.review_score,
    responsiveness_score = EXCLUDED.responsiveness_score,
    completed_orders = EXCLUDED.completed_orders,
    successful_transactions = EXCLUDED.successful_transactions,
    disputes_filed = EXCLUDED.disputes_filed,
    disputes_against = EXCLUDED.disputes_against,
    last_calculated_at = now(),
    score = EXCLUDED.overall_score;
END;
$$;

-- Add RLS policies
DROP POLICY IF EXISTS "Users can view own trust score" ON trust_scores;
DROP POLICY IF EXISTS "Users can insert own trust score" ON trust_scores;

CREATE POLICY "Users can view own trust score"
  ON trust_scores
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own trust score"
  ON trust_scores
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);