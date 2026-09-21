/*
  # Add missing notes column to payment_escrow

  picker_mark_shipped() writes a note into payment_escrow.notes when
  releasing the shipping portion of escrow (status='processing' shipping
  release path, guarded by shipping_amount > 0). That guard was never true
  before the recent fix that made shipping_amount actually get stored
  correctly, so this missing column never surfaced until now:
    column "notes" of relation "payment_escrow" does not exist
*/

ALTER TABLE payment_escrow ADD COLUMN IF NOT EXISTS notes text;
