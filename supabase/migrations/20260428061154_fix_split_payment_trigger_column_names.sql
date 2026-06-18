/*
  # Fix split_payment_on_success trigger function

  ## Problems Fixed
  1. Referenced `o.shipping_cost` but column is actually `o.transportation_cost`
  2. Inserted `payment_intent_id` into payment_escrow but that column doesn't exist
  3. Used ON CONFLICT (payment_intent_id) which doesn't exist

  ## Changes
  - Fix column references to match actual schema
  - Use order_id for conflict detection instead of payment_intent_id
  - This trigger creates escrow as a safety net when payment_intents status changes to succeeded
*/

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
      COALESCE(o.transportation_cost, 0) as shipping_cost,
      (o.total_price - COALESCE(o.transportation_cost, 0)) as product_cost
    INTO v_order
    FROM orders o
    WHERE o.id = NEW.order_id;

    IF v_order.id IS NOT NULL THEN
      v_shipping_cost := v_order.shipping_cost;
      v_product_cost := v_order.product_cost;
      v_total_amount := NEW.amount;

      -- Create escrow record if it doesn't already exist
      INSERT INTO payment_escrow (
        order_id,
        amount,
        item_amount,
        product_amount,
        shipping_amount,
        currency,
        status,
        held_at
      )
      VALUES (
        NEW.order_id,
        v_total_amount,
        v_product_cost,
        v_product_cost,
        v_shipping_cost,
        NEW.currency,
        'held',
        now()
      )
      ON CONFLICT (order_id) WHERE status = 'held'
      DO NOTHING;

    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
