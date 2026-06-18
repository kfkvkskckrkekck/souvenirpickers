/*
  # Update Trial Period to 30 Days (1 Month)

  1. Changes
    - Update default trial period from 180 days to 30 days (1 month)
    - Update existing users' trial period to 30 days from their trial start date
    - This aligns with standard monthly subscription model
    
  2. Notes
    - All new users will automatically get 30 days trial
    - Existing users will have their trials adjusted to 30 days total
*/

-- Update the default for new users to 30 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '30 days');

-- Update trial for ALL existing users to 30 days from their trial start
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '30 days'
WHERE trial_started_at IS NOT NULL;