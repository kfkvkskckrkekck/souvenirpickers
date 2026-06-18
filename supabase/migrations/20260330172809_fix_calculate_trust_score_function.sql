/*
  # Fix calculate_trust_score function

  1. Changes
    - Update function to use correct column names from reviews table
    - Handle both picker_id and client_id reviews
*/

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
  v_is_picker boolean := false;
BEGIN
  -- Check if user is a picker
  SELECT user_type = 'picker' INTO v_is_picker
  FROM profiles
  WHERE id = p_user_id;

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
  -- Reviews are left FOR the picker, so check picker_id
  IF v_is_picker THEN
    SELECT AVG(rating) INTO v_avg_rating
    FROM reviews
    WHERE picker_id = p_user_id;
  ELSE
    -- For clients, check reviews where they are the client
    SELECT AVG(rating) INTO v_avg_rating
    FROM reviews
    WHERE client_id = p_user_id;
  END IF;
  
  IF v_avg_rating IS NOT NULL THEN
    v_review_score := LEAST(ROUND((v_avg_rating / 5.0) * 25)::integer, 25);
  END IF;

  -- Calculate responsiveness score (15 points max)
  -- Based on activity level
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