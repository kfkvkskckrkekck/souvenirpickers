/*
  # Don't announce checkout orders until they are paid

  ## Problem
  create-payment-intent needs an existing order row, so checkout inserts the
  order at the moment the buyer presses Pay. The AFTER INSERT trigger
  notify_new_order() therefore announced the order - an in-app "Order Placed
  Successfully" to the buyer, a "New Order Received" email to the picker and an
  "Order Confirmed" email to the buyer - before any money had moved. When the
  card is declined or the buyer cancels, the unpaid order is removed again, but
  those messages have already gone out.

  ## Changes
  1. notify_new_order(): unchanged for custom orders (listing_id IS NULL - the
     buyer accepted a picker's offer, a deliberate pay-later order). For
     marketplace checkout orders (listing_id IS NOT NULL) it now does nothing
     until the order is paid.
  2. notify_order_paid(): new AFTER UPDATE trigger that sends the picker's "New
     Order Received" email once payment_status becomes 'paid' for those same
     checkout orders. The buyer already receives the in-app "Payment
     Successful" notification and the payment-confirmation email, and the
     picker already receives the in-app "New Order Received!" notification,
     from stripe-webhook, so none of those are repeated here.
  3. cleanup_unpaid_order_artifacts(): BEFORE DELETE trigger. create-payment-
     intent writes a held payment_escrow row and a pending picker_earnings row
     before payment. When an unpaid order is discarded these must go with it
     (picker_earnings.order_id is ON DELETE SET NULL, so a phantom pending
     earning would otherwise be left behind for the picker). Only unpaid
     orders (payment_status = 'pending') are touched.
  4. Delete policy: buyers may also delete their own unpaid orders whose status
     is 'unpaid' (the policy previously covered only 'pending' / 'accepted',
     so the Orders page "Cancel Order" button could not remove them).
*/

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
-- Checkout orders are announced when payment succeeds (notify_order_paid and
-- stripe-webhook), not when the unpaid row is first created.
IF NEW.listing_id IS NOT NULL AND NEW.payment_status IS DISTINCT FROM 'paid' THEN
RETURN NEW;
END IF;

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

CREATE OR REPLACE FUNCTION notify_order_paid()
RETURNS trigger AS $$
DECLARE
v_picker_email text;
v_picker_name text;
v_client_name text;
v_listing_title text;
v_supabase_url text;
BEGIN
v_supabase_url := current_setting('app.settings.supabase_url', true);
IF v_supabase_url IS NULL THEN
v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
END IF;

SELECT p.email, p.full_name
INTO v_picker_email, v_picker_name
FROM profiles p
WHERE p.id = NEW.picker_id;

SELECT p.full_name
INTO v_client_name
FROM profiles p
WHERE p.id = NEW.client_id;

SELECT l.title
INTO v_listing_title
FROM listings l
WHERE l.id = NEW.listing_id;

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
'total_amount', NEW.total_price
)
)
);
END IF;

RETURN NEW;
EXCEPTION
WHEN OTHERS THEN
RAISE WARNING 'Error sending paid-order notification: %', SQLERRM;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

DROP TRIGGER IF EXISTS trigger_order_paid_notification ON orders;
CREATE TRIGGER trigger_order_paid_notification
  AFTER UPDATE OF payment_status ON orders
  FOR EACH ROW
  WHEN (
    OLD.payment_status IS DISTINCT FROM 'paid'
    AND NEW.payment_status = 'paid'
    AND NEW.listing_id IS NOT NULL
  )
  EXECUTE FUNCTION notify_order_paid();

CREATE OR REPLACE FUNCTION cleanup_unpaid_order_artifacts()
RETURNS trigger AS $$
BEGIN
IF OLD.payment_status = 'pending' THEN
BEGIN
DELETE FROM payment_escrow
WHERE order_id = OLD.id
AND status = 'held';
EXCEPTION
WHEN OTHERS THEN
RAISE WARNING 'Could not clean up escrow for unpaid order %: %', OLD.id, SQLERRM;
END;

BEGIN
DELETE FROM picker_earnings
WHERE order_id = OLD.id
AND status = 'pending';
EXCEPTION
WHEN OTHERS THEN
RAISE WARNING 'Could not clean up earnings for unpaid order %: %', OLD.id, SQLERRM;
END;
END IF;

RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

DROP TRIGGER IF EXISTS trigger_cleanup_unpaid_order_artifacts ON orders;
CREATE TRIGGER trigger_cleanup_unpaid_order_artifacts
  BEFORE DELETE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_unpaid_order_artifacts();

DROP POLICY IF EXISTS "Collectors can delete own unpaid orders" ON orders;

CREATE POLICY "Collectors can delete own unpaid orders"
  ON orders
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = client_id
    AND status IN ('pending', 'unpaid', 'accepted')
    AND payment_status = 'pending'
  );
