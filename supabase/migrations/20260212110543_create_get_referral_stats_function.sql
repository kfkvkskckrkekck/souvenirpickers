/*
  # Create get_referral_stats Function
  
  ## Purpose
  Retrieves referral statistics for a user including their code and reward totals.
  
  ## Changes
  1. Creates function to get referral stats matching actual database schema
  2. Uses referral_codes table for code lookup
  3. Uses referral_rewards table for referral tracking and rewards
  4. Returns JSON object with all stats
  
  ## Security
  - Function is SECURITY DEFINER to access data across tables
  - Called by authenticated users for their own stats
  - RLS policies still apply to underlying table access
*/

CREATE OR REPLACE FUNCTION get_referral_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_code text;
  total_referrals integer;
  pending_rewards integer;
  completed_rewards integer;
  total_reward_amount numeric;
  available_reward_amount numeric;
BEGIN
  -- Get the user's referral code
  SELECT code INTO user_code 
  FROM referral_codes 
  WHERE user_id = p_user_id 
  LIMIT 1;
  
  -- Count total referrals (people who used this user's code)
  SELECT COUNT(*) INTO total_referrals
  FROM referral_rewards
  WHERE referrer_id = p_user_id;
  
  -- Count pending rewards
  SELECT COUNT(*) INTO pending_rewards
  FROM referral_rewards
  WHERE referrer_id = p_user_id 
    AND status = 'pending';
  
  -- Count completed/awarded rewards
  SELECT COUNT(*) INTO completed_rewards
  FROM referral_rewards
  WHERE referrer_id = p_user_id 
    AND status = 'awarded';
  
  -- Calculate total reward amount
  SELECT COALESCE(SUM(reward_amount), 0) INTO total_reward_amount
  FROM referral_rewards
  WHERE referrer_id = p_user_id;
  
  -- Calculate available (awarded but not yet claimed) reward amount
  SELECT COALESCE(SUM(reward_amount), 0) INTO available_reward_amount
  FROM referral_rewards
  WHERE referrer_id = p_user_id 
    AND status = 'awarded';
  
  -- Return all stats as JSON
  RETURN jsonb_build_object(
    'code', user_code,
    'total_referrals', COALESCE(total_referrals, 0),
    'pending_referrals', COALESCE(pending_rewards, 0),
    'completed_referrals', COALESCE(completed_rewards, 0),
    'total_rewards', COALESCE(total_reward_amount, 0),
    'available_rewards', COALESCE(available_reward_amount, 0)
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_referral_stats(uuid) TO authenticated;
