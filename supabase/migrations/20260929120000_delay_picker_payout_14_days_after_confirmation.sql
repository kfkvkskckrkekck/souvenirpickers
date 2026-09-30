/*
  # Delay picker payouts until 14 days after delivery confirmation

  ## Context
  After a buyer confirms delivery, collector_confirm_delivery has been firing
  an IMMEDIATE Stripe transfer to the picker. In live mode this fails with
  "Insufficient funds in Stripe account" because Stripe holds a newly-live
  account's charges as "pending" for several days before they become
  "available" to transfer out - confirmed directly against the account's own
  Balances page (Available was EUR 0.00; the full amount was sitting under
  Incoming with specific future release dates).

  Verified live before writing this (see chat): only one cron job exists
  (process-pending-payouts, every 5 minutes -> process_pending_payouts()).
  process_escrow_releases() and auto_release_escrow_after_confirmation() are
  NOT scheduled anywhere - confirmed dead code, left untouched here.

  Checking every 5 minutes for something that only ever changes once a day
  (a 14-day eligibility date) is unnecessary load. This migration reschedules
  the same job to run once daily instead - see step 6.

  Also discovered live: process_pending_payouts has been erroring on every
  run since it was written - it filters on pe.released_at (release_escrow_to_
  picker never sets it) and selects pe.picker_id, a column that does not
  exist on payment_escrow (only released_to does). It has never actually
  triggered a payout. This migration replaces its logic entirely.

  Also discovered live: every existing 'processing' escrow row has
  released_at = null, even ones from already-paid orders. Root cause fixed
  alongside this migration in process-picker-payout/index.ts, which was
  writing a payout_processed column that does not exist on payment_escrow -
  Postgres rejected that whole update (status/released_at included), so the
  escrow bookkeeping never reflected a completed payout even though the
  picker was actually paid.

  ## What this migration does
  1. Adds payment_escrow.payout_eligible_at.
  2. release_escrow_to_picker stamps payout_eligible_at = now() + 14 days.
  3. collector_confirm_delivery no longer fires the payout itself - it only
     releases escrow with the 14-day eligibility date; notification text is
     corrected to say the payment is scheduled, not processing now.
  4. process_pending_payouts is rewritten to trigger payouts once
     payout_eligible_at has passed. This is now the ONLY thing that triggers
     a payout, and it doubles as an automatic retry: if a transfer fails
     (e.g. still insufficient funds), the escrow stays 'processing' and the
     next day's run tries again - no more manual SQL retries needed.
  5. Backfills existing stuck 'processing' rows:
     - Ones whose linked picker_earnings is already 'paid' (the payout
       already succeeded on Stripe's side; only the bookkeeping was wrong)
       are corrected to status = 'released' so they stop being retried.
     - Ones still genuinely unpaid (the live-mode insufficient-funds orders)
       are made immediately eligible rather than waiting a fresh 14 days,
       since they already confirmed delivery days ago.
  6. Reschedules the process-pending-payouts cron job from every 5 minutes
     to once daily at 21:00 UTC. Adjust the hour below if 21:00 UTC isn't
     actually 9pm in your timezone.

  ## Safety notes
  - picker_earnings.status = 'paid' (verified to be a real, working column)
    remains the authoritative duplicate-payment guard inside
    process-picker-payout - even if a row were somehow retried twice, the
    edge function throws "Already paid out" rather than transferring again.
  - This migration only changes WHEN a payout is triggered, not how a single
    payout is executed.
*/

-- 1. New column: when a released escrow becomes eligible for payout
ALTER TABLE payment_escrow ADD COLUMN IF NOT EXISTS payout_eligible_at timestamptz;

-- 2. release_escrow_to_picker: stamp the 14-day eligibility date
CREATE OR REPLACE FUNCTION release_escrow_to_picker(
  p_escrow_id uuid,
  p_picker_id uuid
)
RETURNS json AS $$
DECLARE
  v_escrow record;
BEGIN
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

  IF v_escrow.order_id IS NOT NULL THEN
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

  UPDATE payment_escrow
  SET
    status = 'processing',
    released_to = p_picker_id,
    payout_eligible_at = now() + INTERVAL '14 days',
    updated_at = now()
  WHERE id = p_escrow_id;

  RETURN json_build_object(
    'success', true,
    'escrow_id', p_escrow_id,
    'picker_id', p_picker_id,
    'payout_eligible_at', now() + INTERVAL '14 days',
    'message', 'Escrow marked for processing; payout eligible in 14 days'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO service_role;

-- 3. collector_confirm_delivery: no longer fires the payout itself
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
BEGIN
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
  END IF;

  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    v_picker_id,
    'delivery_confirmed',
    'Delivery Confirmed - Payment Scheduled',
    'The collector confirmed they received the order. Your payment will be released to your bank account within 14 days.',
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
    'Your delivery confirmation has been received. The picker will be paid within 14 days.',
    jsonb_build_object('order_id', p_order_id)
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'picker_id', v_picker_id,
    'message', 'Delivery confirmed. Payment will be released to the picker within 14 days.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION collector_confirm_delivery(uuid, text) TO authenticated;

-- 4. process_pending_payouts: rewritten to be the sole payout trigger,
--    gated on payout_eligible_at instead of the dead released_at check,
--    and no longer referencing the nonexistent pe.picker_id column
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
    SELECT pe.id as escrow_id, pe.released_to as picker_id, o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'processing'
    AND pe.released_to IS NOT NULL
    AND pe.payout_eligible_at IS NOT NULL
    AND pe.payout_eligible_at <= now()
    ORDER BY pe.payout_eligible_at ASC
    LIMIT 500 -- runs once daily now instead of every 5 minutes, so this needs
              -- to comfortably cover a full day's worth of eligible payouts
  LOOP
    BEGIN
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', v_service_role_key
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow.escrow_id,
          'pickerId', v_escrow.picker_id,
          'orderId', v_escrow.order_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;
      v_processed_count := v_processed_count + 1;
      RAISE NOTICE 'Payout triggered for escrow % order % (req: %)', v_escrow.escrow_id, v_escrow.order_id, v_request_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to trigger payout for escrow %: %', v_escrow.escrow_id, SQLERRM;
    END;
  END LOOP;

  IF v_processed_count > 0 THEN
    RAISE NOTICE 'Triggered % eligible payouts', v_processed_count;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION process_pending_payouts() TO service_role;

-- 5a. Backfill: rows already actually paid (bookkeeping-only fix, no money moves)
UPDATE payment_escrow pe
SET
  status = 'released',
  released_at = COALESCE(pe.released_at, pk.paid_at, now())
FROM picker_earnings pk
WHERE pk.order_id = pe.order_id
  AND pe.status = 'processing'
  AND pk.status = 'paid';

-- 5b. Backfill: rows still genuinely unpaid -> eligible now, not in 14 fresh days
UPDATE payment_escrow pe
SET payout_eligible_at = now()
WHERE pe.status = 'processing'
  AND pe.payout_eligible_at IS NULL;

-- 6. Reschedule from every 5 minutes to once daily at 21:00 UTC (9pm UTC).
-- cron.unschedule() is a safe no-op if the job name isn't found, so this
-- works whether or not the job already exists under this name.
SELECT cron.unschedule('process-pending-payouts');

SELECT cron.schedule(
  'process-pending-payouts',
  '0 21 * * *',
  'SELECT process_pending_payouts();'
);
