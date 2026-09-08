/*
  # Restore the automatic payout trigger in collector_confirm_delivery

  History: 20260520073532_fix_payout_auth_use_apikey_header.sql added the
  actual mechanism that calls process-picker-payout automatically (via
  get_service_role_key() + net.http_post) right after releasing escrow.
  But 20260622080247_fix_picker_mark_shipped_status_mismatch.sql later
  replaced collector_confirm_delivery() again (to fix an unrelated status
  values bug) using an older copy of the function that predates the payout
  trigger - silently dropping it. This session's own
  20260903130000_sync_tracking_status_with_order_lifecycle.sql
  copied that same regressed body forward (to add tracking_status), so the
  trigger has been missing ever since: confirming delivery released escrow
  to 'processing' and then nothing ever called Stripe, leaving payouts stuck
  until the 5-minute cron backup (process_pending_payouts) happened to pick
  them up - and only then if the vault key was ever seeded (see
  seed-payout-vault-secret).

  This restores the http_post trigger, keeps this session's tracking_status
  sync and the June fix's reminder-queue cleanup, and also relaxes the
  escrow lookup to accept 'processing' (not just 'held') matching the more
  defensive version from May.
*/

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
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
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

  UPDATE orders
  SET
    status = 'delivered',
    tracking_status = 'delivered',
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
            'apikey', v_service_role_key
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
      RAISE WARNING 'Vault key not set - escrow % marked processing, payout pending cron', v_escrow_id;
    END IF;
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Processing',
    'The collector confirmed they received the order. Your payment is being processed automatically!',
    jsonb_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_order.client_id,
    'delivery_confirmed_collector',
    'Thank You for Confirming',
    'Your delivery confirmation has been received. The picker will be paid automatically.',
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
