/*
  # Fix payment_escrow_status_check to allow 'processing'

  payment_escrow_status_check isn't defined in any tracked migration (it was
  added directly on the live database at some point, outside this history),
  and only allows the original values from when the table was created: held,
  released, refunded. Since then, release_escrow_to_picker()
  (20260308204158_fix_missing_release_escrow_function.sql) and the picker
  payout flow (process-picker-payout, 20260428054954 / 20260520073532) both
  started setting status = 'processing' as an intermediate state before a
  transfer completes - so every call to release_escrow_to_picker (clicking
  "Confirm Delivery") was failing with:
    new row for relation "payment_escrow" violates check constraint
    "payment_escrow_status_check"

  This drops and recreates the constraint as the union of every value
  currently written to payment_escrow.status.
*/

ALTER TABLE payment_escrow DROP CONSTRAINT IF EXISTS payment_escrow_status_check;

ALTER TABLE payment_escrow ADD CONSTRAINT payment_escrow_status_check
  CHECK (status = ANY (ARRAY[
    'held',
    'processing',
    'released',
    'refunded',
    'paid'
  ]));
