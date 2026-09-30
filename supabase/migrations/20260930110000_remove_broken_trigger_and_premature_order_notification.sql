/*
  # Remove broken split_payment_on_success trigger; stop premature "new order" notification

  ## split_payment_on_success (trigger on payment_intents)
  Confirmed live and via real data that this has been silently failing on
  every single payment: it INSERTs into payment_escrow using a
  payment_intent_id column that does not exist on the live table (confirmed
  against the full live column list earlier in this session). Postgres
  rejects the whole statement, and since this trigger has no exception
  handler, the failure rolls back its own triggering UPDATE too - which is
  exactly why every payment_intents row (checked: 10 most recent, spanning
  back to Sept 15) is stuck on status='pending' even for orders that were
  paid, shipped, delivered and (in some cases) already paid out
  successfully. Also confirmed live: zero orders have duplicate
  payment_escrow rows, so this has never partially succeeded either - it
  fails clean, every time.

  This trigger is also pure duplication: create-payment-intent already
  inserts the correct payment_escrow row itself, using the real Sendcloud
  product/shipping split from the request body. split_payment_on_success
  instead computes its split from orders.total_price/transportation_cost -
  legacy fields tied to the old manual-quote workflow, not the Sendcloud
  flow this app actually uses now. Fixing its column reference instead of
  removing it would risk a second, differently-computed escrow row
  appearing alongside the correct one. Dropping it only restores
  payment_intents.status bookkeeping; it does not change any money
  movement, which never reads that column at all.

  ## notify_new_order (trigger on orders, AFTER INSERT)
  Fires the moment an order row is created - before the buyer has paid,
  since OrderCheckoutModal creates the order row first and only then shows
  the Stripe payment step. Its picker-facing "New Order Received" in-app
  notification duplicates (and precedes, possibly incorrectly, if the
  buyer never completes payment) the new "New Order Received!" notification
  now sent from stripe-webhook's payment_intent.succeeded handler - the
  point at which the picker actually has something to act on.

  Removed only the picker-facing in-app notification insert here. Left
  untouched: the collector's "Order Placed Successfully" notification
  (a different, non-duplicated milestone), and both outbound emails (this
  was a request specifically about in-app notifications; the email-timing
  question is a separate decision).
*/

DROP TRIGGER IF EXISTS trigger_split_payment_on_success ON payment_intents;
DROP FUNCTION IF EXISTS split_payment_on_success();

CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS trigger AS $$
DECLARE
v_picker_email text;
v_picker_name text;
v_client_email text;
v_client_name text;
v_listing_title text;
v_supabase_url text;
v_needs_quote boolean;
BEGIN
v_supabase_url := current_setting('app.settings.supabase_url', true);
IF v_supabase_url IS NULL THEN
v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
END IF;

SELECT p.email, p.full_name
INTO v_picker_email, v_picker_name
FROM profiles p
WHERE p.id = NEW.picker_id;

SELECT p.email, p.full_name
INTO v_client_email, v_client_name
FROM profiles p
WHERE p.id = NEW.client_id;

SELECT l.title
INTO v_listing_title
FROM listings l
WHERE l.id = NEW.listing_id;

v_needs_quote := (NEW.shipping_quote_status = 'quote_requested');

-- Picker in-app notification removed here: this trigger fires on order
-- creation, before payment. The picker's actual action point is when
-- payment succeeds, which stripe-webhook now notifies separately.

INSERT INTO notifications (user_id, type, title, message, metadata)
VALUES (
NEW.client_id,
'order_placed',
'Order Placed Successfully',
'Your order for ' || v_listing_title || ' has been placed with ' || v_picker_name,
jsonb_build_object(
'order_id', NEW.id,
'listing_id', NEW.listing_id,
'picker_name', v_picker_name,
'listing_title', v_listing_title,
'needs_quote', v_needs_quote
)
);

IF v_picker_email IS NOT NULL THEN
PERFORM net.http_post(
url := v_supabase_url || '/functions/v1/send-email-notification',
headers := jsonb_build_object(
'Content-Type', 'application/json'
),
body := jsonb_build_object(
'to', v_picker_email,
'subject', 'New Order Received - Order #' || substring(NEW.id::text, 1, 8),
'type', 'new_order_picker',
'data', jsonb_build_object(
'picker_name', COALESCE(v_picker_name, 'there'),
'customer_name', COALESCE(v_client_name, 'A customer'),
'order_id', substring(NEW.id::text, 1, 8),
'item_title', COALESCE(v_listing_title, 'Item'),
'quantity', NEW.quantity,
'total_amount', NEW.total_price,
'needs_quote', v_needs_quote
)
)
);
END IF;

IF v_client_email IS NOT NULL THEN
PERFORM net.http_post(
url := v_supabase_url || '/functions/v1/send-email-notification',
headers := jsonb_build_object(
'Content-Type', 'application/json'
),
body := jsonb_build_object(
'to', v_client_email,
'subject', 'Order Confirmed - Order #' || substring(NEW.id::text, 1, 8),
'type', 'order_confirmation',
'data', jsonb_build_object(
'customer_name', COALESCE(v_client_name, 'there'),
'order_id', substring(NEW.id::text, 1, 8),
'item_title', COALESCE(v_listing_title, 'Item'),
'total_amount', NEW.total_price
)
)
);
END IF;

RETURN NEW;
EXCEPTION
WHEN OTHERS THEN
RAISE WARNING 'Error sending new order notification: %', SQLERRM;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';
