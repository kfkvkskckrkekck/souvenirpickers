/*
  # Remove Immediate Profile Creation on Signup
  
  1. Problem
    - on_auth_user_created trigger creates profiles IMMEDIATELY on signup
    - This conflicts with email confirmation system
    - Profiles should only be created AFTER email is confirmed
    
  2. Current Triggers
    - on_auth_user_created (AFTER INSERT) → creates profile immediately ❌ REMOVE THIS
    - trigger_send_signup_confirmation (AFTER INSERT) → sends confirmation email ✓ KEEP
    - on_auth_user_confirmed (AFTER UPDATE) → creates profile after confirmation ✓ KEEP
    
  3. Solution
    - Drop the on_auth_user_created trigger
    - Profiles will now only be created AFTER email confirmation via on_auth_user_confirmed
    
  4. Impact
    - New signups will NOT have profiles until they confirm their email
    - This is correct behavior when email confirmation is enabled
*/

-- Remove the trigger that creates profiles immediately on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- The function can stay (in case we need it later), but the trigger is removed
COMMENT ON FUNCTION handle_new_user() IS 
  'DEPRECATED: No longer used. Profiles are now created after email confirmation via on_auth_user_confirmed trigger.';

-- Verify the correct triggers remain:
-- 1. trigger_send_signup_confirmation - sends confirmation email on signup
-- 2. on_auth_user_confirmed - creates profile after email is confirmed
