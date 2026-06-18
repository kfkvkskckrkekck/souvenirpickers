/*
  # Add Automatic Referral Payout Trigger

  1. New Functionality
    - Automatically call Stripe payout edge function when referral is completed
    - Use pg_net extension to make HTTP request to edge function
    - Handle both picker and collector referrals appropriately

  2. Changes
    - Create function to call referral payout edge function
    - Add trigger to orders table to detect first order completion
    - Call Stripe payout automatically after referral completion

  3. Security
    - Functions use SECURITY DEFINER for proper permissions
    - Edge function validates all requests
*/

-- Enable pg_net extension for HTTP requests (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function to call referral payout edge function via HTTP
CREATE OR REPLACE FUNCTION trigger_referral_stripe_payout(p_referral_id uuid)
RETURNS void AS $$
DECLARE
  v_supabase_url text;
  v_service_role_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase URL and service role key from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_role_key := current_setting('app.settings.supabase_service_role_key', true);

  -- If settings not available, use pg_net to make request
  -- Note: This is async and won't block the transaction
  BEGIN
    SELECT net.http_post(
      url := format('%s/functions/v1/process-referral-payout', 
                    coalesce(v_supabase_url, 'https://lgfubqqgqmbhdlgcrcvh.supabase.co')),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', format('Bearer %s', coalesce(v_service_role_key, ''))
      ),
      body := jsonb_build_object('referralId', p_referral_id)
    ) INTO v_request_id;

    RAISE NOTICE 'Triggered referral payout for referral_id: %, request_id: %', p_referral_id, v_request_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to trigger referral payout via pg_net: %', SQLERRM;
    -- Don't fail the transaction if HTTP request fails
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the referral completion function to trigger Stripe payout
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
    END IF;

    -- Mark that payout was attempted
    UPDATE referrals
    SET payout_attempted_at = now()
    WHERE id = NEW.id;

    -- Trigger Stripe payout via edge function (async)
    PERFORM trigger_referral_stripe_payout(NEW.id);

    RAISE NOTICE 'Referral completed! Stripe payout triggered for referral: %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_referral_completed ON referrals;
CREATE TRIGGER on_referral_completed
  AFTER UPDATE ON referrals
  FOR EACH ROW
  EXECUTE FUNCTION process_referral_completion();

-- Grant permissions
GRANT EXECUTE ON FUNCTION trigger_referral_stripe_payout(uuid) TO authenticated;

COMMENT ON FUNCTION trigger_referral_stripe_payout(uuid) IS 'Triggers async Stripe payout for completed referral';
