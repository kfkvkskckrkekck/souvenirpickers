/*
  # Split Payment System - Immediate Shipping Payout + Product Escrow

  ## Overview
  This migration implements a specialized split payment structure where:
  - **Shipping costs** are paid immediately to the seller (or upon shipment)
  - **Product price** is held in escrow until delivery confirmation

  This improves seller cash flow while maintaining buyer protection.

  ## Changes Made

  ### 1. Updated `payment_escrow` table
  - Added `product_amount` column to track the product price separately
  - Added `shipping_amount` column to track shipping cost separately
  - Added `shipping_paid_at` timestamp for when shipping funds were released
  - Added `shipping_transfer_id` for Stripe transfer tracking
  - Updated `amount` to represent total (product + shipping)

  ### 2. Updated `picker_earnings` table
  - Added `shipping_amount` column to track shipping earnings separately
  - Added `shipping_paid_at` timestamp
  - Split earnings tracking between product and shipping

  ### 3. New workflow
  - At checkout: Total payment is captured (product + shipping)
  - Immediately after: Shipping funds transferred to picker's Stripe account
  - Product funds: Held in escrow until delivery confirmation
  - On delivery: Product funds released to picker

  ## Benefits
  - **Sellers**: Get shipping money upfront to cover courier costs
  - **Buyers**: Product investment protected until goods received
  - **Platform**: Reduced disputes and improved fulfillment rates

  ## Security
  - All RLS policies remain in effect
  - Service role required for automatic transfers
  - Audit trail maintained for all transactions
*/

-- Add split payment columns to payment_escrow
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payment_escrow' AND column_name = 'product_amount'
  ) THEN
    ALTER TABLE payment_escrow ADD COLUMN product_amount numeric(10,2);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payment_escrow' AND column_name = 'shipping_amount'
  ) THEN
    ALTER TABLE payment_escrow ADD COLUMN shipping_amount numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payment_escrow' AND column_name = 'shipping_paid_at'
  ) THEN
    ALTER TABLE payment_escrow ADD COLUMN shipping_paid_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payment_escrow' AND column_name = 'shipping_transfer_id'
  ) THEN
    ALTER TABLE payment_escrow ADD COLUMN shipping_transfer_id text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payment_escrow' AND column_name = 'product_transfer_id'
  ) THEN
    ALTER TABLE payment_escrow ADD COLUMN product_transfer_id text;
  END IF;
END $$;

-- Add split payment columns to picker_earnings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'shipping_amount'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN shipping_amount numeric(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'shipping_paid_at'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN shipping_paid_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'product_paid_at'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN product_paid_at timestamptz;
  END IF;
END $$;

-- Create function to split payment on successful charge
CREATE OR REPLACE FUNCTION split_payment_on_success()
RETURNS TRIGGER AS $$
DECLARE
  v_order record;
  v_shipping_cost numeric;
  v_product_cost numeric;
  v_total_amount numeric;
BEGIN
  -- Only process when payment succeeds
  IF NEW.status = 'succeeded' AND (OLD.status IS NULL OR OLD.status != 'succeeded') THEN

    -- Get order details including shipping cost
    SELECT
      o.id,
      o.picker_id,
      o.client_id,
      o.total_price,
      COALESCE(o.shipping_cost, 0) as shipping_cost,
      (o.total_price - COALESCE(o.shipping_cost, 0)) as product_cost
    INTO v_order
    FROM orders o
    WHERE o.id = NEW.order_id;

    IF v_order.id IS NOT NULL THEN
      v_shipping_cost := v_order.shipping_cost;
      v_product_cost := v_order.product_cost;
      v_total_amount := NEW.amount;

      -- Create or update escrow record with split amounts
      INSERT INTO payment_escrow (
        payment_intent_id,
        order_id,
        amount,
        product_amount,
        shipping_amount,
        currency,
        status,
        held_at
      )
      VALUES (
        NEW.id,
        NEW.order_id,
        v_total_amount,
        v_product_cost,
        v_shipping_cost,
        NEW.currency,
        'held',
        now()
      )
      ON CONFLICT (payment_intent_id)
      DO UPDATE SET
        amount = EXCLUDED.amount,
        product_amount = EXCLUDED.product_amount,
        shipping_amount = EXCLUDED.shipping_amount,
        currency = EXCLUDED.currency,
        status = EXCLUDED.status,
        held_at = EXCLUDED.held_at;

      -- Note: Shipping funds will be transferred via Edge Function
      -- The Edge Function will update shipping_paid_at and shipping_transfer_id

    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate trigger for split payments
DROP TRIGGER IF EXISTS trigger_split_payment_on_success ON payment_intents;
CREATE TRIGGER trigger_split_payment_on_success
  AFTER INSERT OR UPDATE ON payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION split_payment_on_success();

-- Create function to record shipping payout
CREATE OR REPLACE FUNCTION record_shipping_payout(
  p_order_id uuid,
  p_transfer_id text,
  p_shipping_amount numeric
)
RETURNS void AS $$
DECLARE
  v_picker_id uuid;
BEGIN
  -- Get picker ID from order
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = p_order_id;

  -- Update escrow record
  UPDATE payment_escrow
  SET
    shipping_paid_at = now(),
    shipping_transfer_id = p_transfer_id
  WHERE order_id = p_order_id;

  -- Create or update picker earnings for shipping
  INSERT INTO picker_earnings (
    picker_id,
    order_id,
    shipping_amount,
    shipping_paid_at,
    status
  )
  VALUES (
    v_picker_id,
    p_order_id,
    p_shipping_amount,
    now(),
    'shipping_paid'
  )
  ON CONFLICT (order_id)
  DO UPDATE SET
    shipping_amount = EXCLUDED.shipping_amount,
    shipping_paid_at = EXCLUDED.shipping_paid_at;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to record product payout (on delivery)
CREATE OR REPLACE FUNCTION record_product_payout(
  p_order_id uuid,
  p_transfer_id text,
  p_product_amount numeric,
  p_platform_fee numeric
)
RETURNS void AS $$
DECLARE
  v_picker_id uuid;
  v_net_amount numeric;
BEGIN
  -- Get picker ID from order
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = p_order_id;

  v_net_amount := p_product_amount - p_platform_fee;

  -- Update escrow record
  UPDATE payment_escrow
  SET
    status = 'released',
    released_at = now(),
    released_to = v_picker_id,
    product_transfer_id = p_transfer_id,
    notes = 'Product funds released after delivery confirmation'
  WHERE order_id = p_order_id;

  -- Update picker earnings
  UPDATE picker_earnings
  SET
    amount = v_net_amount,
    platform_fee = p_platform_fee,
    product_paid_at = now(),
    status = 'completed',
    paid_at = now()
  WHERE order_id = p_order_id;

  -- Update order status
  UPDATE orders
  SET status = 'completed'
  WHERE id = p_order_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users and service role
GRANT EXECUTE ON FUNCTION record_shipping_payout TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION record_product_payout TO authenticated, service_role;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_payment_escrow_shipping_status
  ON payment_escrow(order_id, shipping_paid_at)
  WHERE shipping_paid_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_payment_escrow_product_status
  ON payment_escrow(order_id, status)
  WHERE status = 'held';

-- Add helpful comment
COMMENT ON COLUMN payment_escrow.product_amount IS 'Amount for product, held in escrow until delivery';
COMMENT ON COLUMN payment_escrow.shipping_amount IS 'Amount for shipping, paid immediately to seller';
COMMENT ON COLUMN payment_escrow.shipping_paid_at IS 'When shipping funds were transferred to seller';
COMMENT ON COLUMN picker_earnings.shipping_amount IS 'Shipping earnings paid immediately';
COMMENT ON COLUMN picker_earnings.shipping_paid_at IS 'When shipping earnings were paid';
COMMENT ON COLUMN picker_earnings.product_paid_at IS 'When product earnings were paid after delivery';
