/*
  # Create Referrals Table and Complete Referral System

  1. New Tables
    - `referrals`: Track who referred whom and referral status
    - Links referrer and referred users

  2. Triggers & Functions
    - Automatically creates referral rewards when referral is completed
    - Adds earnings to picker accounts for referrers who are pickers

  3. Security
    - Enable RLS on referrals table
    - Add policies for users to view own referrals
    - Functions use SECURITY DEFINER
*/

-- Create referrals table
CREATE TABLE IF NOT EXISTS referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(referred_id)
);

-- Enable RLS
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- Policies for referrals
CREATE POLICY "Users can view own referrals"
  ON referrals FOR SELECT
  TO authenticated
  USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

CREATE POLICY "System can create referrals"
  ON referrals FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update referrals"
  ON referrals FOR UPDATE
  TO authenticated
  USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status) WHERE status = 'pending';

-- Function to process referral completion and add earnings
CREATE OR REPLACE FUNCTION process_referral_completion()
RETURNS TRIGGER AS $$
DECLARE
  referrer_reward numeric := 10.00;
  referred_reward numeric := 5.00;
  v_referrer_is_picker boolean;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Create reward records in referral_rewards table
    INSERT INTO referral_rewards (user_id, referral_id, reward_type, reward_value, expires_at)
    VALUES 
      (NEW.referrer_id, NEW.id, 'referral_bonus', referrer_reward, now() + interval '90 days'),
      (NEW.referred_id, NEW.id, 'signup_bonus', referred_reward, now() + interval '90 days');

    -- Check if referrer is a picker
    SELECT EXISTS (
      SELECT 1 FROM picker_profiles WHERE user_id = NEW.referrer_id
    ) INTO v_referrer_is_picker;

    -- If referrer is a picker, add €10 to their earnings
    IF v_referrer_is_picker THEN
      -- Check if picker_earnings record exists
      INSERT INTO picker_earnings (picker_id, total_earnings, available_balance, pending_balance)
      VALUES (NEW.referrer_id, 0, 0, 0)
      ON CONFLICT (picker_id) DO NOTHING;

      -- Add €10 to available balance (can be withdrawn immediately)
      UPDATE picker_earnings
      SET 
        total_earnings = total_earnings + referrer_reward,
        available_balance = available_balance + referrer_reward,
        updated_at = now()
      WHERE picker_id = NEW.referrer_id;

      RAISE NOTICE 'Added €10 referral bonus to picker earnings for user %', NEW.referrer_id;
    ELSE
      RAISE NOTICE 'Referrer % is not a picker, bonus will be stored in referral_rewards only', NEW.referrer_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on referrals table
DROP TRIGGER IF EXISTS on_referral_completed ON referrals;
CREATE TRIGGER on_referral_completed
  AFTER UPDATE ON referrals
  FOR EACH ROW
  EXECUTE FUNCTION process_referral_completion();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON referrals TO authenticated;
GRANT EXECUTE ON FUNCTION process_referral_completion() TO authenticated;

COMMENT ON TABLE referrals IS 'Tracks referral relationships between users';
COMMENT ON FUNCTION process_referral_completion() IS 'Creates rewards and adds earnings when referral completes first order';
