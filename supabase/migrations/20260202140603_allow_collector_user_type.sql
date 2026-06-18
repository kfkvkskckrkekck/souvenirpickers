/*
  # Allow 'collector' as Valid User Type

  1. Problem
    - The profiles table constraint only allows 'picker' and 'client'
    - Some UI components use 'collector' terminology
    - Users signing up as collectors may have issues
    
  2. Solution
    - Update the constraint to allow 'picker', 'client', and 'collector'
    - 'client' and 'collector' are treated the same in the app
    
  3. Security
    - No security impact, just adds flexibility for user type naming
*/

-- Drop the old constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Add new constraint that allows 'picker', 'client', and 'collector'
ALTER TABLE profiles ADD CONSTRAINT profiles_user_type_check 
  CHECK (user_type IN ('picker', 'client', 'collector'));
