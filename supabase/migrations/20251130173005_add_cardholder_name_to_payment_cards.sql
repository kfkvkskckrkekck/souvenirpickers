/*
  # Add cardholder name to payment cards

  1. Changes
    - Add cardholder_name column to picker_payment_cards table to store the name entered by the user
    
  2. Purpose
    - Display the cardholder name on saved payment cards for better user experience
*/

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payment_cards' AND column_name = 'cardholder_name'
  ) THEN
    ALTER TABLE picker_payment_cards ADD COLUMN cardholder_name text;
  END IF;
END $$;