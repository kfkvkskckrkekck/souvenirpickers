-- Referral Program System
--
-- 1. New Tables
--    - referral_codes: Unique referral codes for each user
--    - referrals: Track who referred whom
--    - referral_rewards: Track earned rewards
--    - reward_redemptions: Track when rewards are used
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only see their own referrals and rewards

-- Create referral_codes table
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create referrals table
CREATE TABLE IF NOT EXISTS referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  status text DEFAULT 'pending',
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(referred_id)
);

-- Create referral_rewards table
CREATE TABLE IF NOT EXISTS referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_id uuid REFERENCES referrals(id) ON DELETE CASCADE,
  reward_type text NOT NULL,
  reward_value numeric(10, 2) NOT NULL,
  currency text DEFAULT 'EUR',
  expires_at timestamptz,
  redeemed boolean DEFAULT false,
  redeemed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create reward_redemptions table
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id uuid REFERENCES referral_rewards(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  amount_used numeric(10, 2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

-- Policies for referral_codes
CREATE POLICY "Users can view own referral code"
  ON referral_codes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own referral code"
  ON referral_codes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for referrals
CREATE POLICY "Users can view own referrals"
  ON referrals FOR SELECT
  TO authenticated
  USING (referrer_id = auth.uid() OR referred_id = auth.uid());

CREATE POLICY "Anyone can create referrals"
  ON referrals FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for referral_rewards
CREATE POLICY "Users can view own rewards"
  ON referral_rewards FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can create rewards"
  ON referral_rewards FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own rewards"
  ON referral_rewards FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for reward_redemptions
CREATE POLICY "Users can view own redemptions"
  ON reward_redemptions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create redemptions"
  ON reward_redemptions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_user_id ON referral_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_redeemed ON referral_rewards(redeemed) WHERE redeemed = false;

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text AS $$
DECLARE
  new_code text;
  code_exists boolean;
BEGIN
  LOOP
    new_code := upper(substring(md5(random()::text) from 1 for 8));
    
    SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = new_code) INTO code_exists;
    
    IF NOT code_exists THEN
      EXIT;
    END IF;
  END LOOP;
  
  RETURN new_code;
END;
$$ LANGUAGE plpgsql;

-- Function to create referral code for new users
CREATE OR REPLACE FUNCTION create_referral_code_for_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO referral_codes (user_id, code)
  VALUES (NEW.id, generate_referral_code())
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create referral code
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_user_created_generate_referral_code'
  ) THEN
    CREATE TRIGGER on_user_created_generate_referral_code
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION create_referral_code_for_user();
  END IF;
END $$;

-- Function to process referral completion
CREATE OR REPLACE FUNCTION process_referral_completion()
RETURNS TRIGGER AS $$
DECLARE
  referrer_reward numeric := 10.00;
  referred_reward numeric := 5.00;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO referral_rewards (user_id, referral_id, reward_type, reward_value, expires_at)
    VALUES 
      (NEW.referrer_id, NEW.id, 'referral_bonus', referrer_reward, now() + interval '90 days'),
      (NEW.referred_id, NEW.id, 'signup_bonus', referred_reward, now() + interval '90 days');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for referral completion
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_referral_completed'
  ) THEN
    CREATE TRIGGER on_referral_completed
      AFTER UPDATE ON referrals
      FOR EACH ROW
      EXECUTE FUNCTION process_referral_completion();
  END IF;
END $$;

-- Function to apply referral code
CREATE OR REPLACE FUNCTION apply_referral_code(p_code text, p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  referrer_user_id uuid;
  existing_referral uuid;
  new_referral_id uuid;
BEGIN
  SELECT user_id INTO referrer_user_id
  FROM referral_codes
  WHERE code = p_code;
  
  IF referrer_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;
  
  IF referrer_user_id = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot use your own referral code');
  END IF;
  
  SELECT id INTO existing_referral
  FROM referrals
  WHERE referred_id = p_user_id;
  
  IF existing_referral IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already used a referral code');
  END IF;
  
  INSERT INTO referrals (referrer_id, referred_id, referral_code, status)
  VALUES (referrer_user_id, p_user_id, p_code, 'pending')
  RETURNING id INTO new_referral_id;
  
  RETURN jsonb_build_object('success', true, 'referral_id', new_referral_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user referral stats
CREATE OR REPLACE FUNCTION get_referral_stats(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  total_referrals integer;
  completed_referrals integer;
  pending_referrals integer;
  total_rewards numeric;
  available_rewards numeric;
  user_code text;
BEGIN
  SELECT code INTO user_code FROM referral_codes WHERE user_id = p_user_id;
  
  SELECT COUNT(*) INTO total_referrals FROM referrals WHERE referrer_id = p_user_id;
  SELECT COUNT(*) INTO completed_referrals FROM referrals WHERE referrer_id = p_user_id AND status = 'completed';
  SELECT COUNT(*) INTO pending_referrals FROM referrals WHERE referrer_id = p_user_id AND status = 'pending';
  
  SELECT COALESCE(SUM(reward_value), 0) INTO total_rewards 
  FROM referral_rewards WHERE user_id = p_user_id;
  
  SELECT COALESCE(SUM(reward_value), 0) INTO available_rewards 
  FROM referral_rewards WHERE user_id = p_user_id AND redeemed = false AND (expires_at IS NULL OR expires_at > now());
  
  RETURN jsonb_build_object(
    'code', user_code,
    'total_referrals', total_referrals,
    'completed_referrals', completed_referrals,
    'pending_referrals', pending_referrals,
    'total_rewards', total_rewards,
    'available_rewards', available_rewards
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
