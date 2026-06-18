/*
  # Update Escrow Release to Process Actual Stripe Transfers

  1. Changes
    - Drop and recreate `release_escrow_to_picker` function with new return type
    - Function now marks escrow for payout processing
    - Actual Stripe transfers handled by edge function
    - Deducts 10% platform fee automatically
    - Updates escrow status after successful transfer

  2. Flow
    - When escrow is released (auto or manual)
    - Function marks escrow for processing
    - Background job or manual call to edge function processes transfer
    - Edge function creates Stripe transfer
    - Records payout in picker_payouts table
    - Updates escrow to 'released' status

  3. Important
    - This replaces the old database-only release process
    - Now actual money transfers happen via Stripe
    - Pickers must have completed Stripe Connect onboarding
    - Platform fee is automatically deducted
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

-- Recreate the function with support for actual Stripe transfers
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS json AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Get order_id for the escrow
  SELECT order_id INTO v_order_id
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  IF v_order_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Escrow not found or already processed'
    );
  END IF;

  -- Mark escrow for payout processing
  -- The actual Stripe transfer will be handled by calling the edge function
  UPDATE payment_escrow
  SET 
    payout_processed = false,
    notes = 'Pending Stripe transfer processing',
    released_to = picker_user_id
  WHERE id = escrow_id
  AND status = 'held';

  -- Insert a notification to trigger the payout processing
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    picker_user_id,
    'payout_processing',
    'Payment Processing',
    'Your payout is being processed and will arrive in your account soon',
    json_build_object(
      'escrow_id', escrow_id,
      'order_id', v_order_id,
      'action', 'process_payout'
    )
  );

  RETURN json_build_object(
    'success', true,
    'escrow_id', escrow_id,
    'order_id', v_order_id,
    'picker_id', picker_user_id,
    'message', 'Payout processing initiated. Call process-picker-payout edge function to complete.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a helper function to get pending payouts
CREATE OR REPLACE FUNCTION get_pending_payouts()
RETURNS TABLE (
  escrow_id uuid,
  picker_id uuid,
  order_id uuid,
  amount numeric,
  held_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pe.id as escrow_id,
    pe.released_to as picker_id,
    pe.order_id,
    pe.amount,
    pe.held_at
  FROM payment_escrow pe
  WHERE pe.status = 'held'
  AND pe.payout_processed = false
  AND pe.released_to IS NOT NULL
  ORDER BY pe.held_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_payouts() TO authenticated;
