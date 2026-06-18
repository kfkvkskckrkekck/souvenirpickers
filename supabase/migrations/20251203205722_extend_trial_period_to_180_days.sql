/*
  # Extend Trial Period to 6 Months

  1. Changes
    - Update default trial period from 60 days to 180 days (6 months)
    - Extend trial for all existing users to 180 days from their trial start date
    - This ensures adequate testing time and prevents disruption
    
  2. Notes
    - All users get extended to 180 days total trial period
    - New users will automatically get 180 days trial
    - Existing users close to expiration get extended
*/

-- Update the default for new users to 180 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '180 days');

-- Extend trial for ALL existing users to 180 days from their trial start
-- This ensures everyone gets adequate testing time
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '180 days'
WHERE trial_started_at IS NOT NULL;