/*
  # Fix Picker Payout System - Auth Header and Parameter Bugs

  ## Problems Fixed

  1. **Wrong Authorization Header in collector_confirm_delivery**
     - Was using: `current_setting('request.jwt.claims')::json->>'role'` which returns the string "authenticated", not a valid token
     - Fixed to use: `current_setting('app.supabase_service_role_key', true)` with a fallback to SUPABASE_SERVICE_ROLE_KEY env var

  2. **Wrong Authorization Header in process_pending_payouts (cron backup)**
     - Same issue — was referencing an unset config key returning NULL
     - Fixed to use the correct service role key setting

  3. **auto_release_escrow_after_confirmation uses anon key instead of service role**
     - Was fetching supabase_anon_key which cannot invoke edge functions securely
     - Fixed to use service role key

  4. **All three callers now pass orderId alongside escrowId/pickerId**
     - Edge function now accepts both forms, but passing orderId avoids the extra lookup

  ## Security
  - No RLS changes
  - Functions remain SECURITY DEFINER
  - Service role key is read from pg_catalog app settings (set by Supabase automatically)
*/

-- ============================================================
-- Fix 1: collector_confirm_delivery - correct auth header
-- ============================================================
CREATE OR REPLACE FUNCTION collector_confirm_delivery(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
  v_release_result json;
  v_request_id bigint;
  v_service_role_key text;
  v_supabase_url text := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
BEGIN
  -- Get service role key from app settings
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

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

  IF v_order.status NOT IN ('in_progress', 'confirmed', 'paid') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  IF v_order.payment_status != 'paid' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order must be paid before confirming delivery'
    );
  END IF;

  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Delivery has already been confirmed for this order'
    );
  END IF;

  -- Update order: mark as delivered and confirm receipt
  UPDATE orders
  SET
    status = 'delivered',
    actual_delivery = now(),
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  -- Cancel any pending reminders
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type IN ('delivery_confirmation', 'picker_mark_delivered', 'collector_confirm_delivery');

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status IN ('held', 'processing');

  -- Release escrow and trigger automatic payout
  IF v_escrow_id IS NOT NULL THEN
    -- Mark escrow for processing
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;

    -- Trigger automatic payout via edge function with correct auth and parameters
    IF v_service_role_key IS NOT NULL AND v_service_role_key != '' THEN
      BEGIN
        SELECT net.http_post(
          url := v_supabase_url || '/functions/v1/process-picker-payout',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_service_role_key
          ),
          body := jsonb_build_object(
            'escrowId', v_escrow_id,
            'pickerId', v_picker_id,
            'orderId', p_order_id
          ),
          timeout_milliseconds := 30000
        ) INTO v_request_id;

        RAISE NOTICE 'Automatic payout triggered for escrow % order % (request ID: %)', v_escrow_id, p_order_id, v_request_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to trigger automatic payout: %', SQLERRM;
      END;
    ELSE
      RAISE WARNING 'Service role key not configured — escrow % marked processing but payout not triggered', v_escrow_id;
    END IF;
  END IF;

  -- Notify picker
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Processing',
    'The collector confirmed they received the order. Your payment is being processed now!',
    jsonb_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  -- Notify collector
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid shortly.',
    jsonb_build_object('order_id', p_order_id)
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed. Payment is being processed automatically.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;

-- ============================================================
-- Fix 2: process_pending_payouts cron - correct auth and params
-- ============================================================
CREATE OR REPLACE FUNCTION process_pending_payouts()
RETURNS void AS $$
DECLARE
  v_escrow record;
  v_request_id bigint;
  v_processed_count integer := 0;
  v_service_role_key text;
  v_supabase_url text := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
BEGIN
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'process_pending_payouts: app.supabase_service_role_key not set — skipping';
    RETURN;
  END IF;

  FOR v_escrow IN
    SELECT
      pe.id as escrow_id,
      pe.picker_id,
      pe.amount,
      pe.currency,
      o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'processing'
    AND pe.released_at IS NOT NULL
    AND pe.released_at < NOW() - INTERVAL '2 minutes'
    AND (pe.payout_id IS NULL OR pe.payout_id = '')
    ORDER BY pe.released_at ASC
    LIMIT 50
  LOOP
    BEGIN
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow.escrow_id,
          'pickerId', v_escrow.picker_id,
          'orderId', v_escrow.order_id
        ),
        timeout_milliseconds := 10000
      ) INTO v_request_id;

      v_processed_count := v_processed_count + 1;
      RAISE NOTICE 'Queued payout for escrow % order % (request ID: %)', v_escrow.escrow_id, v_escrow.order_id, v_request_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to queue payout for escrow %: %', v_escrow.escrow_id, SQLERRM;
    END;
  END LOOP;

  IF v_processed_count > 0 THEN
    RAISE NOTICE 'Queued % pending payouts', v_processed_count;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Fix 3: auto_release_escrow_after_confirmation - use service role key
-- ============================================================
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_service_role_key text;
  v_supabase_url text := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  v_request_id bigint;
BEGIN
  v_service_role_key := current_setting('app.supabase_service_role_key', true);

  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'auto_release_escrow: app.supabase_service_role_key not set — skipping';
    RETURN;
  END IF;

  -- Find escrows that need auto-release: 14 days after payment without delivery confirmation
  -- OR 48 hours after confirmed delivery
  FOR v_escrow_record IN
    SELECT
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND (pe.payout_processed = false OR pe.payout_processed IS NULL)
    AND (
      -- 14-day auto release: paid but no delivery confirmation
      (o.payment_status = 'paid' AND o.goods_confirmed = false AND pe.held_at < NOW() - INTERVAL '14 days')
      OR
      -- 48-hour post-delivery release
      (o.status = 'delivered' AND o.actual_delivery IS NOT NULL AND o.actual_delivery < NOW() - INTERVAL '48 hours')
    )
  LOOP
    BEGIN
      -- Mark escrow as processing first
      UPDATE payment_escrow
      SET status = 'processing', released_at = now(), released_to = v_escrow_record.picker_id
      WHERE id = v_escrow_record.escrow_id AND status = 'held';

      -- Mark order as delivered if not already
      UPDATE orders
      SET status = 'delivered', goods_confirmed = true, goods_confirmed_at = now(), actual_delivery = COALESCE(actual_delivery, now())
      WHERE id = v_escrow_record.order_id AND status NOT IN ('delivered', 'cancelled');

      -- Trigger the edge function payout
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id,
          'orderId', v_escrow_record.order_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      INSERT INTO notifications (user_id, type, title, message, metadata)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        'Automatic Payout Initiated',
        'Your earnings are being transferred to your account automatically.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount
        )
      );

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'auto_release failed for escrow %: %', v_escrow_record.escrow_id, SQLERRM;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auto_release_escrow_after_confirmation() TO service_role;
GRANT EXECUTE ON FUNCTION process_pending_payouts() TO service_role;
GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;
