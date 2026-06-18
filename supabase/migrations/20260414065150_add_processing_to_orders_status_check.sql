/*
  # Add 'processing' to orders status check constraint

  The orders table was missing 'processing' as a valid status value,
  causing a constraint violation when pickers tried to accept and start orders.

  This migration drops the existing status check constraint and recreates it
  with 'processing' included.
*/

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

ALTER TABLE orders ADD CONSTRAINT orders_status_check
  CHECK (status = ANY (ARRAY[
    'awaiting_quote',
    'quote_provided',
    'payment_pending',
    'paid',
    'processing',
    'shipped',
    'delivered',
    'completed',
    'cancelled',
    'refunded'
  ]));
