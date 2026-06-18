/*
  # Update Escrow Release to Use 'delivered' Status

  1. Changes
    - Update release_escrow_to_picker() to keep order status as 'delivered' instead of changing to 'completed'
    - 'delivered' is now the final status for successfully finished orders
    - No need to change status after payment release
*/

-- Drop and recreate the function to not change status to 'completed'
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

CREATE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
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

  -- No need to update order status - it should already be 'delivered'
  -- Just update the updated_at timestamp
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
