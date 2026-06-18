/*
  # Remove Custom Signup Confirmation Trigger

  1. Purpose
    - Removes the trigger that attempted to send custom confirmation emails
    - The correct approach is to configure Custom SMTP in Supabase Dashboard

  2. Changes
    - Drops the trigger and function
*/

-- Drop the trigger
DROP TRIGGER IF EXISTS on_auth_user_created_send_confirmation ON auth.users;

-- Drop the function
DROP FUNCTION IF EXISTS send_custom_signup_confirmation();
