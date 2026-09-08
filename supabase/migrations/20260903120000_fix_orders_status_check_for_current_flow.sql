/*
  # Fix orders_status_check to match the statuses the app actually writes

  The last update to this constraint (20260414065150) only allowed the old
  manual quote-workflow values (awaiting_quote, quote_provided,
  payment_pending, paid, processing, shipped, delivered, completed,
  cancelled, refunded). The app has since moved to the automatic
  Sendcloud-quoted checkout flow (OrderCheckoutModal.tsx, CartView.tsx) and
  the picker/collector order-lifecycle UI (src/lib/orderStatus.ts,
  OrdersView.tsx, CartPaymentModal.tsx, stripe-webhook, create-shipment-label),
  which write statuses ('pending', 'unpaid', 'accepted', 'in_progress',
  'label_created', 'received', 'confirmed', 'payment_failed') that were never
  added to this constraint - so every new order insert/update using them was
  silently rejected by Postgres.

  This drops and recreates the constraint as the union of the old allowed
  values (kept so historical rows stay valid) and every value currently
  written by the app.
*/

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status = ANY (ARRAY[
    'awaiting_quote',
    'quote_provided',
    'payment_pending',
    'pending',
    'unpaid',
    'accepted',
    'in_progress',
    'processing',
    'paid',
    'confirmed',
    'payment_failed',
    'label_created',
    'shipped',
    'delivered',
    'received',
    'completed',
    'cancelled',
    'refunded'
  ]));
