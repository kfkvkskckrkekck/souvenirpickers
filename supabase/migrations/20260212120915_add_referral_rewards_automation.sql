/*
  # Add Referral Rewards Automation

  1. New Functionality
    - Automatically detects when a user completes their first order
    - Marks the referral relationship as 'completed'
    - Triggers creation of rewards (€10 for referrer, €5 for referred)
    - Stores referral discount in user's profile for use at checkout

  2. Changes
    - Add `has_referral_discount` and `referral_discount_amount` to profiles table
    - Create trigger on orders table to detect first completed order
    - Create function to mark referral as completed and grant discount

  3. Security
    - All functions use SECURITY DEFINER for proper permissions
    - RLS policies remain in place for data protection
*/

-- Add referral discount fields to profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS has_referral_discount boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS referral_discount_amount numeric(10, 2) DEFAULT 0.00;

-- Function to handle first order completion and activate referral rewards
CREATE OR REPLACE FUNCTION handle_first_order_referral_completion()
RETURNS TRIGGER AS $$
DECLARE
  v_is_first_order boolean;
  v_referral_id uuid;
  v_referrer_id uuid;
BEGIN
  -- Only process if order is marked as 'delivered' (which means completed in our system)
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    
    -- Check if this is the user's first completed order
    SELECT COUNT(*) = 1 INTO v_is_first_order
    FROM orders
    WHERE (client_id = NEW.client_id OR picker_id = NEW.picker_id)
    AND status = 'delivered';

    -- If this is their first order, check if they have a pending referral
    IF v_is_first_order THEN
      -- Find pending referral for this user
      SELECT id, referrer_id INTO v_referral_id, v_referrer_id
      FROM referrals
      WHERE referred_id IN (NEW.client_id, NEW.picker_id)
      AND status = 'pending'
      LIMIT 1;

      -- If referral exists, mark it as completed
      IF v_referral_id IS NOT NULL THEN
        UPDATE referrals
        SET 
          status = 'completed',
          completed_at = now()
        WHERE id = v_referral_id;

        -- The 'on_referral_completed' trigger will automatically create the rewards

        -- Grant €5 discount to the referred user for their NEXT order
        UPDATE profiles
        SET 
          has_referral_discount = true,
          referral_discount_amount = 5.00
        WHERE user_id IN (NEW.client_id, NEW.picker_id);

        RAISE NOTICE 'Referral completed! Rewards granted.';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS on_first_order_completed_check_referral ON orders;
CREATE TRIGGER on_first_order_completed_check_referral
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION handle_first_order_referral_completion();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION handle_first_order_referral_completion() TO authenticated;

COMMENT ON FUNCTION handle_first_order_referral_completion() IS 'Detects first order completion and activates referral rewards';
COMMENT ON COLUMN profiles.has_referral_discount IS 'Whether user has an unused referral discount';
COMMENT ON COLUMN profiles.referral_discount_amount IS 'Amount of referral discount available (EUR)';
