/*
  # Update Trial Period to 2 Months

  1. Changes
    - Update default trial period from 90 days to 60 days (2 months)
    - Update existing trial periods for users who haven't exceeded 60 days
    
  2. Notes
    - Users who are already past 60 days will keep their current trial_ends_at
    - New users will automatically get 60 days trial
*/

-- Update the default for new users
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '60 days');

-- Update existing users who still have trial time remaining beyond 60 days
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '60 days'
WHERE trial_ends_at > trial_started_at + interval '60 days';