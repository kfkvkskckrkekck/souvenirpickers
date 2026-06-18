/*
  # Add Goods Confirmation System for Collectors

  1. New Columns to orders table
    - `goods_confirmed` (boolean) - Whether collector confirmed receipt
    - `goods_confirmed_at` (timestamptz) - When confirmation happened
    - `confirmation_notes` (text) - Optional feedback from collector

  2. New Function
    - `confirm_goods_receipt(order_id, notes)` - Collector confirms receipt
    - Triggers immediate escrow release process
    - Updates order status to confirmed

  3. Flow
    - Collector receives order
    - Collector clicks "Confirm Receipt" button
    - System marks goods_confirmed = true
    - Escrow released immediately (no 48-hour wait)
    - Picker gets paid faster when collector is satisfied

  4. Benefits
    - Pickers get paid faster when collectors are happy
    - 48-hour auto-release still exists as backup
    - Builds trust between pickers and collectors
*/

-- Add confirmation columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'confirmation_notes'
  ) THEN
    ALTER TABLE orders ADD COLUMN confirmation_notes text;
  END IF;
END $$;

-- Create function for collectors to confirm receipt of goods
CREATE OR REPLACE FUNCTION confirm_goods_receipt(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
    );
  END IF;

  -- Check if order is in a state that can be confirmed
  IF v_order.status NOT IN ('in_progress', 'delivered') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  -- Check if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been confirmed'
    );
  END IF;

  -- Update order with confirmation
  UPDATE orders
  SET
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    status = CASE 
      WHEN status != 'delivered' THEN 'delivered'
      ELSE status
    END,
    actual_delivery = CASE
      WHEN actual_delivery IS NULL THEN now()
      ELSE actual_delivery
    END,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- If escrow exists, release it immediately
  IF v_escrow_id IS NOT NULL THEN
    PERFORM release_escrow_to_picker(v_escrow_id, v_picker_id);
  END IF;

  -- Notify picker that goods were confirmed and payment is being processed
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Order Confirmed - Payment Processing',
    'The collector confirmed receipt of the order. Your payment is being processed now!',
    json_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  -- Notify collector that their confirmation was received
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'confirmation_received',
    'Thank You for Confirming',
    'Your confirmation has been received. The picker will be paid shortly.',
    json_build_object(
      'order_id', p_order_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'message', 'Receipt confirmed. Payment will be processed immediately.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the auto-release function to prioritize confirmed orders
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_supabase_url text;
  v_supabase_anon_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase configuration
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  SELECT current_setting('app.settings.supabase_anon_key', true) INTO v_supabase_anon_key;
  
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Find escrows that need to be released
  -- Priority 1: Orders confirmed by collector (immediate release)
  -- Priority 2: Orders delivered 48+ hours ago (auto release)
  FOR v_escrow_record IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount,
      o.goods_confirmed,
      o.goods_confirmed_at
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND pe.payout_processed = false
    AND (
      -- Confirmed by collector (immediate release)
      (o.goods_confirmed = true AND o.goods_confirmed_at IS NOT NULL)
      OR
      -- Auto-release after 48 hours
      (
        o.status = 'delivered'
        AND o.actual_delivery IS NOT NULL
        AND o.actual_delivery < (NOW() - INTERVAL '48 hours')
      )
    )
    ORDER BY 
      o.goods_confirmed DESC,  -- Confirmed orders first
      o.goods_confirmed_at ASC, -- Earlier confirmations first
      o.actual_delivery ASC     -- Then oldest deliveries
  LOOP
    BEGIN
      -- Call the edge function to process the Stripe transfer
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(v_supabase_anon_key, '')
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      -- Log payout initiation
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'Payment Processing (Confirmed)'
          ELSE 'Automatic Payout Initiated'
        END,
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'The collector confirmed receipt. Your payment is being transferred now!'
          ELSE 'Your earnings from a completed order are being transferred to your account'
        END,
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount,
          'confirmed', v_escrow_record.goods_confirmed,
          'request_id', v_request_id
        )
      );

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_error',
        'Payout Processing Error',
        'There was an issue processing your payout. Our team will resolve this shortly.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'error', SQLERRM
        )
      );
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION confirm_goods_receipt(uuid, text) TO authenticated;

-- Create index for faster confirmation queries
CREATE INDEX IF NOT EXISTS idx_orders_goods_confirmed 
  ON orders(goods_confirmed, goods_confirmed_at) 
  WHERE goods_confirmed = true;
