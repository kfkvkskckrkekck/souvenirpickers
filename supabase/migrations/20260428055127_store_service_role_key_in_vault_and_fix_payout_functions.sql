/*
  # Store Service Role Key in Vault and Fix Payout Trigger Functions

  ## Problem
  The DB functions (collector_confirm_delivery, process_pending_payouts,
  auto_release_escrow_after_confirmation) need to call the process-picker-payout
  edge function with a valid service role JWT. The key cannot be read from
  pg_catalog settings, so we store it in vault.secrets and read it from there.

  ## Solution
  - Update payout-triggering functions to read the service role key from vault
  - Functions fall back gracefully if vault key is not yet populated
  - The vault secret must be seeded once via: SELECT vault.create_secret('...key...', 'supabase_service_role_key')

  ## Notes
  - vault.decrypted_secrets view is accessible to SECURITY DEFINER functions
  - No RLS changes needed
*/

-- Helper function to get service role key from vault
CREATE OR REPLACE FUNCTION get_service_role_key()
RETURNS text AS $$
DECLARE
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_role_key'
  LIMIT 1;
  RETURN v_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

REVOKE ALL ON FUNCTION get_service_role_key() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_service_role_key() TO service_role;

-- ============================================================
-- Updated collector_confirm_delivery - reads key from vault
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
  v_service_role_key := get_service_role_key();

  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Order not found or you do not have permission');
  END IF;

  IF v_order.payment_status != 'paid' THEN
    RETURN json_build_object('success', false, 'error', 'Order must be paid before confirming delivery');
  END IF;

  IF v_order.goods_confirmed THEN
    RETURN json_build_object('success', false, 'error', 'Delivery has already been confirmed for this order');
  END IF;

  UPDATE orders
  SET
    status = 'delivered',
    actual_delivery = COALESCE(actual_delivery, now()),
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type IN ('delivery_confirmation', 'picker_mark_delivered', 'collector_confirm_delivery');

  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status IN ('held', 'processing')
  LIMIT 1;

  IF v_escrow_id IS NOT NULL THEN
    SELECT release_escrow_to_picker(v_escrow_id, v_picker_id) INTO v_release_result;

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
        RAISE NOTICE 'Payout triggered for escrow % order % (req: %)', v_escrow_id, p_order_id, v_request_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to trigger payout: %', SQLERRM;
      END;
    ELSE
      RAISE WARNING 'Vault key not set — escrow % marked processing, payout pending cron', v_escrow_id;
    END IF;
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id, 'delivery_confirmed',
    'Delivery Confirmed - Payment Processing',
    'The collector confirmed receipt. Your payment is being processed!',
    jsonb_build_object('order_id', p_order_id, 'escrow_id', v_escrow_id, 'confirmed_at', now())
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id, 'delivery_confirmed_collector',
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
-- Updated process_pending_payouts - reads key from vault
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
  v_service_role_key := get_service_role_key();

  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'process_pending_payouts: vault key not set — skipping';
    RETURN;
  END IF;

  FOR v_escrow IN
    SELECT pe.id as escrow_id, pe.picker_id, o.id as order_id
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
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to queue payout for escrow %: %', v_escrow.escrow_id, SQLERRM;
    END;
  END LOOP;

  IF v_processed_count > 0 THEN
    RAISE NOTICE 'Queued % pending payouts', v_processed_count;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION process_pending_payouts() TO service_role;

-- ============================================================
-- Updated auto_release_escrow_after_confirmation - reads key from vault
-- ============================================================
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_service_role_key text;
  v_supabase_url text := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  v_request_id bigint;
BEGIN
  v_service_role_key := get_service_role_key();

  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'auto_release_escrow: vault key not set — skipping';
    RETURN;
  END IF;

  FOR v_escrow_record IN
    SELECT pe.id as escrow_id, o.picker_id, o.id as order_id, pe.amount
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND (pe.payout_processed = false OR pe.payout_processed IS NULL)
    AND (
      (o.payment_status = 'paid' AND o.goods_confirmed = false AND pe.held_at < NOW() - INTERVAL '14 days')
      OR
      (o.status = 'delivered' AND o.actual_delivery IS NOT NULL AND o.actual_delivery < NOW() - INTERVAL '48 hours')
    )
  LOOP
    BEGIN
      UPDATE payment_escrow
      SET status = 'processing', released_at = now(), released_to = v_escrow_record.picker_id
      WHERE id = v_escrow_record.escrow_id AND status = 'held';

      UPDATE orders
      SET
        status = 'delivered',
        goods_confirmed = true,
        goods_confirmed_at = COALESCE(goods_confirmed_at, now()),
        actual_delivery = COALESCE(actual_delivery, now())
      WHERE id = v_escrow_record.order_id
        AND status NOT IN ('delivered', 'cancelled');

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
        v_escrow_record.picker_id, 'payout_initiated',
        'Automatic Payout Initiated',
        'Your earnings are being transferred to your account automatically.',
        jsonb_build_object('escrow_id', v_escrow_record.escrow_id, 'order_id', v_escrow_record.order_id, 'amount', v_escrow_record.amount)
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'auto_release failed for escrow %: %', v_escrow_record.escrow_id, SQLERRM;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auto_release_escrow_after_confirmation() TO service_role;
