  UNIQUE(listing_id)
);

-- Enable RLS
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE trending_listings ENABLE ROW LEVEL SECURITY;

-- Policies for user_activity
CREATE POLICY "Users can view own activity"
  ON user_activity FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own activity"
  ON user_activity FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for listing_views
CREATE POLICY "Anyone can record listing views"
  ON listing_views FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view own listing views"
  ON listing_views FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR user_id IS NULL);

-- Policies for user_preferences
CREATE POLICY "Users can view own preferences"
  ON user_preferences FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own preferences"
  ON user_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for trending_listings
CREATE POLICY "Anyone can view trending listings"
  ON trending_listings FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_created_at ON user_activity(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_user_id ON listing_views(user_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_created_at ON listing_views(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trending_listings_score ON trending_listings(trend_score DESC);

-- Function to record listing view
CREATE OR REPLACE FUNCTION record_listing_view(
  p_listing_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_session_id text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  INSERT INTO listing_views (listing_id, user_id, session_id)
  VALUES (p_listing_id, p_user_id, p_session_id);

  IF p_user_id IS NOT NULL THEN
    INSERT INTO user_activity (user_id, activity_type, entity_type, entity_id)
    VALUES (p_user_id, 'view', 'listing', p_listing_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get personalized recommendations
CREATE OR REPLACE FUNCTION get_personalized_recommendations(
  p_user_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  listing_id uuid,
  relevance_score numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH user_prefs AS (
    SELECT 
      preferred_categories,
      preferred_regions,
      price_range_min,
      price_range_max
    FROM user_preferences
    WHERE user_id = p_user_id
  ),
  scored_listings AS (
    SELECT 
      l.id as listing_id,
      (
        CASE WHEN up.preferred_categories IS NOT NULL AND l.category = ANY(up.preferred_categories) THEN 50 ELSE 0 END +
        CASE WHEN up.preferred_regions IS NOT NULL AND l.region = ANY(up.preferred_regions) THEN 30 ELSE 0 END +
        CASE WHEN up.price_range_min IS NULL OR l.price >= up.price_range_min THEN 10 ELSE 0 END +
        CASE WHEN up.price_range_max IS NULL OR l.price <= up.price_range_max THEN 10 ELSE 0 END +
        COALESCE(pp.rating * 5, 0)
      )::numeric as relevance_score
    FROM listings l
    LEFT JOIN user_prefs up ON true
    LEFT JOIN picker_profiles pp ON pp.id = l.picker_id
    WHERE l.available = true
    AND l.id NOT IN (
      SELECT listing_id FROM orders WHERE client_id = p_user_id
    )
    ORDER BY relevance_score DESC, l.created_at DESC
    LIMIT p_limit
  )
  SELECT * FROM scored_listings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get trending listings
CREATE OR REPLACE FUNCTION get_trending_listings(p_limit integer DEFAULT 10)
RETURNS TABLE (
  listing_id uuid,
  trend_score numeric,
  view_count integer,
  order_count integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tl.listing_id,
    tl.trend_score,
    tl.view_count,
    tl.order_count
  FROM trending_listings tl
  JOIN listings l ON l.id = tl.listing_id
  WHERE l.available = true
  ORDER BY tl.trend_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user preferences based on activity
CREATE OR REPLACE FUNCTION update_user_preferences_from_activity()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT DISTINCT user_id FROM user_activity WHERE created_at > now() - interval '30 days'
  LOOP
    INSERT INTO user_preferences (user_id, preferred_categories, preferred_regions)
    SELECT 
      user_record.user_id,
      ARRAY_AGG(DISTINCT l.category) FILTER (WHERE l.category IS NOT NULL),
      ARRAY_AGG(DISTINCT l.region) FILTER (WHERE l.region IS NOT NULL)
    FROM user_activity ua
    JOIN listings l ON l.id = ua.entity_id
    WHERE ua.user_id = user_record.user_id
    AND ua.entity_type = 'listing'
    AND ua.created_at > now() - interval '30 days'
    ON CONFLICT (user_id) DO UPDATE
    SET 
      preferred_categories = EXCLUDED.preferred_categories,
      preferred_regions = EXCLUDED.preferred_regions,
      updated_at = now();
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate trending listings
CREATE OR REPLACE FUNCTION calculate_trending_listings()
RETURNS void AS $$
BEGIN
  DELETE FROM trending_listings;

  INSERT INTO trending_listings (listing_id, trend_score, view_count, order_count, share_count)
  SELECT 
    l.id,
    (
      COALESCE(view_counts.count, 0) * 1.0 +
      COALESCE(order_counts.count, 0) * 10.0 +
      COALESCE(share_counts.count, 0) * 5.0 +
      CASE WHEN l.created_at > now() - interval '7 days' THEN 20 ELSE 0 END
    )::numeric as trend_score,
    COALESCE(view_counts.count, 0)::integer,
    COALESCE(order_counts.count, 0)::integer,
    COALESCE(share_counts.count, 0)::integer
  FROM listings l
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_views
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) view_counts ON view_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM orders
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) order_counts ON order_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_shares
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) share_counts ON share_counts.listing_id = l.id
  WHERE l.available = true
  AND (
    COALESCE(view_counts.count, 0) > 0 OR
    COALESCE(order_counts.count, 0) > 0 OR
    COALESCE(share_counts.count, 0) > 0
  )
  ORDER BY trend_score DESC
  LIMIT 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251126214447_create_referral_program.sql
-- =========================================

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


-- =========================================
-- Migration: 20251127121947_generate_referral_codes_for_existing_users.sql
-- =========================================

/*
  # Generate Referral Codes for Existing Users

  1. Changes
    - Generates referral codes for all existing users who don't have one
    - Uses the existing generate_referral_code() function
    - Safe to run multiple times (uses INSERT ... ON CONFLICT DO NOTHING)

  2. Notes
    - This fixes the issue where existing users don't have referral codes
    - Only affects users who don't already have a code
*/

-- Generate referral codes for all existing users who don't have one
INSERT INTO referral_codes (user_id, code)
SELECT 
  u.id,
  generate_referral_code()
FROM auth.users u
LEFT JOIN referral_codes rc ON rc.user_id = u.id
WHERE rc.id IS NULL
ON CONFLICT (user_id) DO NOTHING;


-- =========================================
-- Migration: 20251127132056_add_escrow_automation_and_triggers.sql
-- =========================================

/*
  # Escrow Payment Protection System - Automation & Triggers

  1. New Functions
    - automatic_escrow_creation: Automatically creates escrow record when payment is confirmed
    - release_escrow_to_picker: Releases funds to picker when order is delivered
    - refund_escrow_to_client: Refunds money to client if order is cancelled/disputed
    - auto_release_escrow: Auto-release funds after delivery confirmation period
  
  2. Triggers
    - Auto-create escrow when payment intent succeeds
    - Update order status when escrow is released
    - Handle escrow timeouts
  
  3. Important Notes
    - Funds are held in escrow until order is marked as delivered
    - Client has 48 hours to dispute after delivery
    - After 48 hours, funds auto-release to picker
    - Refunds return money to client and update order status
*/

-- Function to automatically create escrow when payment succeeds
CREATE OR REPLACE FUNCTION automatic_escrow_creation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'succeeded' AND OLD.status != 'succeeded' THEN
    INSERT INTO payment_escrow (
      payment_intent_id,
      order_id,
      amount,
      status,
      held_at
    )
    VALUES (
      NEW.id,
      NEW.order_id,
      NEW.amount,
      'held',
      now()
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release escrow to picker
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'released',
    released_at = now(),
    released_to = picker_user_id,
    notes = 'Funds released to picker after delivery confirmation'
  WHERE id = escrow_id
  AND status = 'held'
  RETURNING order_id INTO v_order_id;

  -- Update order status to completed
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET 
      status = 'completed',
      updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refund escrow to client
CREATE OR REPLACE FUNCTION refund_escrow_to_client(escrow_id uuid, refund_reason text)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
  v_payment_intent_id uuid;
  v_amount numeric;
  v_client_id uuid;
BEGIN
  -- Get escrow details
  SELECT order_id, payment_intent_id, amount
  INTO v_order_id, v_payment_intent_id, v_amount
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  -- Get client ID from order
  SELECT client_id INTO v_client_id
  FROM orders
  WHERE id = v_order_id;

  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'refunded',
    released_at = now(),
    released_to = v_client_id,
    notes = refund_reason
  WHERE id = escrow_id;

  -- Create refund record
  INSERT INTO refunds (
    payment_intent_id,
    order_id,
    amount,
    reason,
    status,
    initiated_by
  )
  VALUES (
    v_payment_intent_id,
    v_order_id,
    v_amount,
    refund_reason,
    'completed',
    v_client_id
  );

  -- Update order status to cancelled
  UPDATE orders
  SET 
    status = 'cancelled',
    updated_at = now()
  WHERE id = v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-release escrow after confirmation period
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow RECORD;
BEGIN
  FOR v_escrow IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON pe.order_id = o.id
    WHERE pe.status = 'held'
    AND o.status = 'delivered'
    AND o.delivered_at IS NOT NULL
    AND o.delivered_at < now() - INTERVAL '48 hours'
  LOOP
    PERFORM release_escrow_to_picker(v_escrow.escrow_id, v_escrow.picker_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create escrow when payment succeeds
DROP TRIGGER IF EXISTS trigger_create_escrow_on_payment ON payment_intents;
CREATE TRIGGER trigger_create_escrow_on_payment
  AFTER UPDATE ON payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION automatic_escrow_creation();

-- Create a scheduled job function that can be called by an edge function
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS json AS $$
DECLARE
  v_released_count int := 0;
BEGIN
  PERFORM auto_release_escrow_after_confirmation();
  
  GET DIAGNOSTICS v_released_count = ROW_COUNT;
  
  RETURN json_build_object(
    'success', true,
    'released_count', v_released_count,
    'processed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION refund_escrow_to_client(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_escrow_releases() TO authenticated;

-- =========================================
-- Migration: 20251127133057_add_picker_subscription_payments.sql
-- =========================================

/*
  # Picker Subscription Payment System

  1. New Tables
    - picker_subscription_payments: Tracks subscription payment history for pickers
    - picker_payment_cards: Stores payment card information for pickers (tokenized)
    
  2. Changes to Profiles
    - Only pickers need to pay subscription fees
    - Add stripe_customer_id for pickers
    - Add default_payment_method reference
    
  3. Security
    - Enable RLS on all tables
    - Pickers can only view and manage their own payment methods
    - Payment card data is tokenized (only store Stripe tokens, never raw card data)
    
  4. Important Notes
    - Only pickers (user_type = 'picker') are charged subscription fees
    - Clients (user_type = 'client') use the platform for free
    - Subscription is 1 euro per month after 60-day trial
    - Payment is processed automatically via Stripe
    - Pickers must add payment method before trial ends
*/

-- Create subscription payments tracking table
CREATE TABLE IF NOT EXISTS picker_subscription_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount numeric(10, 2) NOT NULL,
  currency text DEFAULT 'eur',
  stripe_payment_intent_id text UNIQUE,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'succeeded', 'failed', 'refunded')),
  billing_period_start timestamptz NOT NULL,
  billing_period_end timestamptz NOT NULL,
  payment_method_used text,
  failure_reason text,
  paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payment cards table (stores Stripe tokens only)
CREATE TABLE IF NOT EXISTS picker_payment_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  stripe_payment_method_id text UNIQUE NOT NULL,
  card_brand text,
  card_last4 text,
  card_exp_month integer,
  card_exp_year integer,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add Stripe customer ID to profiles (only for pickers)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'stripe_customer_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stripe_customer_id text UNIQUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'default_payment_card_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN default_payment_card_id uuid REFERENCES picker_payment_cards(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_method_added'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_method_added boolean DEFAULT false;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE picker_subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Policies for picker_subscription_payments
CREATE POLICY "Pickers can view own subscription payments"
  ON picker_subscription_payments FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "System can insert subscription payments"
  ON picker_subscription_payments FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "System can update subscription payments"
  ON picker_subscription_payments FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Policies for picker_payment_cards
CREATE POLICY "Pickers can view own payment cards"
  ON picker_payment_cards FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Pickers can add own payment cards"
  ON picker_payment_cards FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can update own payment cards"
  ON picker_payment_cards FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can delete own payment cards"
  ON picker_payment_cards FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_subscription_payments_picker_id ON picker_subscription_payments(picker_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON picker_subscription_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_period ON picker_subscription_payments(billing_period_start, billing_period_end);
CREATE INDEX IF NOT EXISTS idx_payment_cards_picker_id ON picker_payment_cards(picker_id);
CREATE INDEX IF NOT EXISTS idx_payment_cards_default ON picker_payment_cards(picker_id, is_default);

-- Function to automatically set only one default payment card per picker
CREATE OR REPLACE FUNCTION set_default_payment_card()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE picker_payment_cards
    SET is_default = false
    WHERE picker_id = NEW.picker_id
    AND id != NEW.id;
    
    UPDATE profiles
    SET default_payment_card_id = NEW.id,
        payment_method_added = true
    WHERE id = NEW.picker_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to manage default payment card
DROP TRIGGER IF EXISTS trigger_set_default_payment_card ON picker_payment_cards;
CREATE TRIGGER trigger_set_default_payment_card
  AFTER INSERT OR UPDATE OF is_default ON picker_payment_cards
  FOR EACH ROW
  EXECUTE FUNCTION set_default_payment_card();

-- Function to process monthly subscription payments
CREATE OR REPLACE FUNCTION process_picker_subscription_payment(
  p_picker_id uuid,
  p_amount numeric,
  p_stripe_payment_intent_id text,
  p_payment_method_used text
)
RETURNS json AS $$
DECLARE
  v_payment_id uuid;
  v_billing_start timestamptz;
  v_billing_end timestamptz;
BEGIN
  v_billing_start := date_trunc('month', now());
  v_billing_end := v_billing_start + interval '1 month';

  INSERT INTO picker_subscription_payments (
    picker_id,
    amount,
    currency,
    stripe_payment_intent_id,
    payment_status,
    billing_period_start,
    billing_period_end,
    payment_method_used,
    paid_at
  )
  VALUES (
    p_picker_id,
    p_amount,
    'eur',
    p_stripe_payment_intent_id,
    'succeeded',
    v_billing_start,
    v_billing_end,
    p_payment_method_used,
    now()
  )
  RETURNING id INTO v_payment_id;

  UPDATE profiles
  SET 
    last_payment_date = now(),
    next_payment_due = v_billing_end,
    payment_failed = false,
    subscription_status = 'active'
  WHERE id = p_picker_id;

  RETURN json_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'next_payment_due', v_billing_end
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION process_picker_subscription_payment(uuid, numeric, text, text) TO authenticated;

-- =========================================
-- Migration: 20251127142651_create_cart_and_collector_payments.sql
-- =========================================

/*
  # Create Shopping Cart and Collector Payment Methods System

  ## Overview
  This migration creates a shopping cart system for collectors and adds payment method management.

  ## New Tables
  
  ### 1. `cart_items`
  Shopping cart for collectors to add items before checkout
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `listing_id` (uuid, references listings) - The item being added
  - `quantity` (integer) - Number of items
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. `collector_payment_methods`
  Payment methods for collectors (separate from picker payment methods)
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `method_type` (text) - credit_card, debit_card, paypal, etc.
  - `card_brand` (text) - Visa, Mastercard, etc.
  - `last_four` (text) - Last 4 digits of card
  - `cardholder_name` (text) - Name on card
  - `expiry_month` (integer) - Card expiry month
  - `expiry_year` (integer) - Card expiry year
  - `is_default` (boolean) - Whether this is the default payment method
  - `stripe_payment_method_id` (text) - Stripe payment method ID
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - RLS enabled on all tables
  - Collectors can only access their own cart items and payment methods
  - Proper indexes for performance

  ## Important Notes
  - Cart items are linked to active listings
  - Payment methods store minimal card info for display
  - Actual payment processing will use Stripe
  - First payment method is automatically default
*/

-- Create cart_items table
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT unique_cart_item UNIQUE (client_id, listing_id)
);

-- Create collector_payment_methods table
CREATE TABLE IF NOT EXISTS collector_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  method_type text NOT NULL DEFAULT 'credit_card',
  card_brand text,
  last_four text,
  cardholder_name text NOT NULL,
  expiry_month integer,
  expiry_year integer,
  is_default boolean DEFAULT false,
  stripe_payment_method_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_method_type CHECK (method_type IN ('credit_card', 'debit_card', 'paypal', 'bank_account', 'other')),
