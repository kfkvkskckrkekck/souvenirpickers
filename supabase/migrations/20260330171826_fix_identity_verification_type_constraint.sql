/*
  # Fix identity verification type constraint

  1. Changes
    - Update verification_type constraint to accept all document types
    - Add id_card, passport, drivers_license, utility_bill, selfie
*/

-- Drop the old constraint
ALTER TABLE identity_verifications 
DROP CONSTRAINT IF EXISTS identity_verifications_verification_type_check;

-- Add new constraint with all valid document types
ALTER TABLE identity_verifications 
ADD CONSTRAINT identity_verifications_verification_type_check 
CHECK (verification_type IN (
  'government_id',
  'selfie', 
  'address',
  'phone',
  'id_card',
  'passport',
  'drivers_license',
  'utility_bill'
));