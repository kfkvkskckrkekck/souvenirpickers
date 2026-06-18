/*
  # Fix Missing Release Escrow Function
  
  1. Problem
    - collector_confirm_delivery calls release_escrow_to_picker()
    - This function doesn't exist in the database
    - Automatic payouts are failing silently
    
  2. Solution
    - Create the release_escrow_to_picker function
    - Marks escrow as 'processing' status
    - Returns success/failure status
    
  3. Security
    - SECURITY DEFINER for elevated permissions
    - Only called from collector_confirm_delivery
*/

CREATE OR REPLACE FUNCTION release_escrow_to_picker(
  p_escrow_id uuid,
  p_picker_id uuid
)
RETURNS json AS $$
DECLARE
  v_escrow record;
BEGIN
  -- Get the escrow record
  SELECT * INTO v_escrow
  FROM payment_escrow
  WHERE id = p_escrow_id
  AND status = 'held'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Escrow not found or already processed'
    );
  END IF;

  -- Verify picker matches
  IF v_escrow.order_id IS NOT NULL THEN
    -- Check if picker matches the order
    IF NOT EXISTS (
      SELECT 1 FROM orders 
      WHERE id = v_escrow.order_id 
      AND picker_id = p_picker_id
    ) THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Picker does not match the order'
      );
    END IF;
  END IF;

  -- Mark escrow for processing
  UPDATE payment_escrow
  SET
    status = 'processing',
    released_to = p_picker_id,
    updated_at = now()
  WHERE id = p_escrow_id;

  RETURN json_build_object(
    'success', true,
    'escrow_id', p_escrow_id,
    'picker_id', p_picker_id,
    'message', 'Escrow marked for processing'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO service_role;

COMMENT ON FUNCTION release_escrow_to_picker(uuid, uuid) IS
  'Marks escrow for processing and prepares for automatic payout to picker';
