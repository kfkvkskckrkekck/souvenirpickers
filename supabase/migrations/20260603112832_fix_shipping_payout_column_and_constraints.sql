/*
  # Fix Shipping Payout System

  ## Problems Fixed

  ### 1. Wrong column name in split_payment_on_success trigger
  - The trigger was querying `orders.shipping_cost` which does not exist
  - The actual column is `orders.transportation_cost`
  - This caused shipping_amount to always be 0, so no transfer was ever attempted

  ### 2. Missing UNIQUE constraint on picker_earnings(order_id)
  - The `record_shipping_payout` function uses ON CONFLICT (order_id) 
  - Without a unique constraint this silently fails (inserts a duplicate row or errors)
  - Added unique constraint so ON CONFLICT works correctly

  ### 3. picker_earnings status constraint too restrictive
  - Status CHECK only allowed: 'pending', 'available', 'paid'
  - The record_shipping_payout function inserts status = 'shipping_paid'
  - This caused the insert to fail with a constraint violation
  - Expanded allowed statuses to include 'shipping_paid' and 'completed'

  ## Tables Modified
  - `payment_intents` trigger function: fix column name
  - `picker_earnings`: add unique constraint on order_id, fix status check
*/

-- ===================================================
-- 1. Fix split_payment_on_success: use transportation_cost
-- ===================================================
CREATE OR REPLACE FUNCTION split_payment_on_success()
RETURNS TRIGGER AS $$
DECLARE
  v_order record;
  v_shipping_cost numeric;
  v_product_cost numeric;
  v_total_amount numeric;
BEGIN
  IF NEW.status = 'succeeded' AND (OLD.status IS NULL OR OLD.status != 'succeeded') THEN

    SELECT
      o.id,
      o.picker_id,
      o.client_id,
      o.total_price,
      COALESCE(o.transportation_cost, 0) AS shipping_cost,
      (o.total_price - COALESCE(o.transportation_cost, 0)) AS product_cost
    INTO v_order
    FROM orders o
    WHERE o.id = NEW.order_id;

    IF v_order.id IS NOT NULL THEN
      v_shipping_cost := v_order.shipping_cost;
      v_product_cost := v_order.product_cost;
      v_total_amount := NEW.amount;

      INSERT INTO payment_escrow (
        payment_intent_id,
        order_id,
        amount,
        product_amount,
        shipping_amount,
        currency,
        status,
        held_at
      )
      VALUES (
        NEW.id,
        NEW.order_id,
        v_total_amount,
        v_product_cost,
        v_shipping_cost,
        NEW.currency,
        'held',
        now()
      )
      ON CONFLICT (payment_intent_id)
      DO UPDATE SET
        amount          = EXCLUDED.amount,
        product_amount  = EXCLUDED.product_amount,
        shipping_amount = EXCLUDED.shipping_amount,
        currency        = EXCLUDED.currency,
        status          = EXCLUDED.status,
        held_at         = EXCLUDED.held_at;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===================================================
-- 2. Fix picker_earnings status constraint
--    Allow: pending, available, paid, shipping_paid, completed
-- ===================================================
ALTER TABLE picker_earnings DROP CONSTRAINT IF EXISTS picker_earnings_status_check;

ALTER TABLE picker_earnings
  ADD CONSTRAINT picker_earnings_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'available'::text,
    'paid'::text,
    'shipping_paid'::text,
    'completed'::text
  ]));

-- ===================================================
-- 3. Add UNIQUE constraint on picker_earnings(order_id)
--    so ON CONFLICT (order_id) in record_shipping_payout works
--    First deduplicate if any exist
-- ===================================================
DO $$
BEGIN
  -- Remove duplicate picker_earnings rows keeping the most recent per order_id
  DELETE FROM picker_earnings
  WHERE id NOT IN (
    SELECT DISTINCT ON (order_id) id
    FROM picker_earnings
    ORDER BY order_id, created_at DESC NULLS LAST
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Dedup of picker_earnings skipped: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'picker_earnings_order_id_unique'
  ) THEN
    ALTER TABLE picker_earnings ADD CONSTRAINT picker_earnings_order_id_unique UNIQUE (order_id);
  END IF;
END $$;

-- ===================================================
-- 4. Fix record_shipping_payout to use correct status
-- ===================================================
CREATE OR REPLACE FUNCTION record_shipping_payout(
  p_order_id uuid,
  p_transfer_id text,
  p_shipping_amount numeric
)
RETURNS void AS $$
DECLARE
  v_picker_id uuid;
BEGIN
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = p_order_id;

  -- Mark shipping as paid in escrow
  UPDATE payment_escrow
  SET
    shipping_paid_at      = now(),
    shipping_transfer_id  = p_transfer_id
  WHERE order_id = p_order_id;

  -- Upsert picker earnings: update shipping fields if row exists, insert if not
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
    shipping_amount  = EXCLUDED.shipping_amount,
    shipping_paid_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION record_shipping_payout TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION split_payment_on_success TO service_role;
