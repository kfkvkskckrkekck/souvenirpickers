/*
  # Add missing updated_at column to payment_escrow

  release_escrow_to_picker() (20260308204158_fix_missing_release_escrow_function.sql)
  sets `updated_at = now()` when marking an escrow record for processing, but
  payment_escrow was created (20251126212228_add_stripe_payment_system.sql)
  without an updated_at column - only created_at, held_at, released_at. Every
  call to release_escrow_to_picker (invoked from collector_confirm_delivery,
  i.e. clicking "Confirm Delivery") was failing with:
    column "updated_at" of relation "payment_escrow" does not exist

  This adds the column so the existing function works as written.
*/

ALTER TABLE payment_escrow ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
