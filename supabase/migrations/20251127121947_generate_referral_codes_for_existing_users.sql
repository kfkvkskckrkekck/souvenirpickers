/*
  # Generate Referral Codes for Existing Users

  1. Changes
    - Generates referral codes for all existing users who don't have one
    - Uses the existing generate_referral_code() function
    - Safe to run multiple times (uses INSERT ... ON CONFLICT DO NOTHING)

  2. Notes
    - This fixes the issue where existing users don't have referral codes
    - Only affects users who don't already have a code
*/

-- Generate referral codes for all existing users who don't have one
INSERT INTO referral_codes (user_id, code)
SELECT 
  u.id,
  generate_referral_code()
FROM auth.users u
LEFT JOIN referral_codes rc ON rc.user_id = u.id
WHERE rc.id IS NULL
ON CONFLICT (user_id) DO NOTHING;
