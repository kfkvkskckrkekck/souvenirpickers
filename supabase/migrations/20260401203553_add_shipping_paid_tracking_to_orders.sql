/*
  # Add Shipping Payment Tracking to Orders

  ## Overview
  Adds fields to the orders table to track when shipping funds are paid to the picker.
  This provides visibility into the payment flow and helps with order status tracking.

  ## Changes Made
  1. Add `shipping_paid` boolean to track if shipping funds were transferred
  2. Add `shipping_paid_at` timestamp to record when transfer occurred
  3. Add `shipping_transfer_id` to link to Stripe transfer
  4. Update `record_shipping_payout` function to update orders table

  ## Benefits
  - Collectors can see shipping payment status in order details
  - Pickers have clear record of when they received shipping funds
  - Support team can verify payment flow
  - Order status reflects payment progression
*/

-- Add shipping payment tracking columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_paid'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_paid boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_paid_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_paid_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'shipping_transfer_id'
  ) THEN
    ALTER TABLE orders ADD COLUMN shipping_transfer_id text;
  END IF;
END $$;

-- Update record_shipping_payout to also update orders table
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

  -- Update orders table with shipping payment info
  UPDATE orders
  SET
    shipping_paid = true,
    shipping_paid_at = now(),
    shipping_transfer_id = p_transfer_id
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

  -- Create notification for picker
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    metadata
  )
  VALUES (
    v_picker_id,
    'payment',
    'Shipping Funds Received',
    'Shipping cost of €' || p_shipping_amount::text || ' has been transferred to your account. You can now cover courier expenses for this order.',
    jsonb_build_object(
      'order_id', p_order_id,
      'amount', p_shipping_amount,
      'transfer_id', p_transfer_id,
      'payment_type', 'shipping'
    )
  );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION record_shipping_payout TO authenticated, service_role;

-- Add helpful comments
COMMENT ON COLUMN orders.shipping_paid IS 'Whether shipping funds have been transferred to picker';
COMMENT ON COLUMN orders.shipping_paid_at IS 'When shipping funds were transferred to picker';
COMMENT ON COLUMN orders.shipping_transfer_id IS 'Stripe transfer ID for shipping payment';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_orders_shipping_paid 
  ON orders(picker_id, shipping_paid, shipping_paid_at) 
  WHERE shipping_paid = true;
