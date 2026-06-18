/*
  # Update Picker Earnings to Account for Platform Fees

  1. Changes
    - Update picker_earnings table to track gross vs net earnings
    - Add platform_fees_paid column
    - Update earnings calculation functions
    - Deduct 10% platform fee from all earnings
    - Show transparent fee breakdown to pickers

  2. New Columns
    - `total_gross_earned` - Total before fees (replaces total_earned)
    - `platform_fees_paid` - Total fees paid to platform (10%)
    - `total_net_earned` - Total after fees (what picker actually receives)

  3. Important
    - Platform takes 10% of all earnings
    - Pickers see both gross and net amounts
    - Available balance is net amount minus payouts
*/

-- Add new columns to picker_earnings table
DO $$
BEGIN
  -- Add total_gross_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_gross_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_gross_earned numeric DEFAULT 0 CHECK (total_gross_earned >= 0);
  END IF;

  -- Add platform_fees_paid if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'platform_fees_paid'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN platform_fees_paid numeric DEFAULT 0 CHECK (platform_fees_paid >= 0);
  END IF;

  -- Add total_net_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_net_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_net_earned numeric DEFAULT 0 CHECK (total_net_earned >= 0);
  END IF;
END $$;

-- Migrate existing data: total_earned becomes total_gross_earned
UPDATE picker_earnings
SET 
  total_gross_earned = COALESCE(total_earned, 0),
  platform_fees_paid = ROUND(COALESCE(total_earned, 0) * 0.10, 2),
  total_net_earned = ROUND(COALESCE(total_earned, 0) * 0.90, 2)
WHERE total_gross_earned = 0;

-- Update available_balance to reflect net earnings
UPDATE picker_earnings
SET available_balance = GREATEST(
  (total_net_earned - COALESCE(total_paid_out, 0)),
  0
);

-- Create or replace the earnings update function with fee calculation
CREATE OR REPLACE FUNCTION update_earnings_on_escrow_held()
RETURNS TRIGGER AS $$
DECLARE
  v_picker_id uuid;
  v_platform_fee numeric;
  v_net_amount numeric;
BEGIN
  -- Get picker_id from the order
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = NEW.order_id;

  IF v_picker_id IS NOT NULL THEN
    -- Calculate platform fee (10%) and net amount (90%)
    v_platform_fee := ROUND(NEW.amount * 0.10, 2);
    v_net_amount := NEW.amount - v_platform_fee;

    -- Update or insert picker earnings
    INSERT INTO picker_earnings (
      picker_id,
      total_gross_earned,
      platform_fees_paid,
      total_net_earned,
      pending_payout,
      available_balance
    )
    VALUES (
      v_picker_id,
      NEW.amount,
      v_platform_fee,
      v_net_amount,
      v_net_amount,
      0
    )
    ON CONFLICT (picker_id) DO UPDATE SET
      total_gross_earned = picker_earnings.total_gross_earned + NEW.amount,
      platform_fees_paid = picker_earnings.platform_fees_paid + v_platform_fee,
      total_net_earned = picker_earnings.total_net_earned + v_net_amount,
      pending_payout = picker_earnings.pending_payout + v_net_amount,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update earnings when payout is completed
CREATE OR REPLACE FUNCTION update_earnings_on_payout_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Move from pending to paid out
    UPDATE picker_earnings
    SET
      pending_payout = GREATEST(pending_payout - COALESCE(NEW.net_amount, NEW.amount), 0),
      total_paid_out = total_paid_out + COALESCE(NEW.net_amount, NEW.amount),
      available_balance = GREATEST(total_net_earned - (total_paid_out + COALESCE(NEW.net_amount, NEW.amount)), 0),
      last_payout_at = NEW.processed_at,
      updated_at = now()
    WHERE picker_id = NEW.picker_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for payout completion
DROP TRIGGER IF EXISTS trigger_update_earnings_on_payout ON picker_payouts;
CREATE TRIGGER trigger_update_earnings_on_payout
  AFTER UPDATE ON picker_payouts
  FOR EACH ROW
  EXECUTE FUNCTION update_earnings_on_payout_completed();

-- Create a comprehensive view for picker dashboard
CREATE OR REPLACE VIEW picker_earnings_dashboard AS
SELECT
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at,
  COUNT(pp.id) as total_payouts,
  COUNT(CASE WHEN pp.status = 'completed' THEN 1 END) as successful_payouts,
  COUNT(CASE WHEN pp.status = 'failed' THEN 1 END) as failed_payouts,
  COUNT(DISTINCT o.id) as total_orders_completed,
  AVG(CASE WHEN pp.status = 'completed' THEN pp.net_amount END) as avg_payout_amount
FROM picker_earnings pe
LEFT JOIN picker_payouts pp ON pp.picker_id = pe.picker_id
LEFT JOIN orders o ON o.picker_id = pe.picker_id AND o.status = 'completed'
GROUP BY 
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at;

-- Grant access to the views
GRANT SELECT ON picker_earnings_dashboard TO authenticated;

-- Add comment to clarify the old total_earned column (if it still exists)
COMMENT ON COLUMN picker_earnings.total_earned IS 'DEPRECATED: Use total_gross_earned instead. This column may be removed in a future update.';
