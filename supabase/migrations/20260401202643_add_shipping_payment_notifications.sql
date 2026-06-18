/*
  # Add Shipping Payment Notifications

  ## Overview
  This migration adds automatic notifications to pickers when shipping funds are transferred to their account.

  ## Changes Made
  1. Updates `record_shipping_payout` function to create a notification
  2. Adds notification when shipping costs are paid immediately

  ## Notification Details
  - Notifies picker that shipping funds were transferred
  - Includes the shipping amount
  - Helps pickers know they have funds to cover courier costs
*/

-- Update record_shipping_payout to include notification
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
