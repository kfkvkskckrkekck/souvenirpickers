/*
  # Disable Email Confirmation Completely
  
  This migration removes the email confirmation requirement and trigger that's causing signup failures.
  
  Changes:
  - Drop the email confirmation trigger and function
  - Users will be automatically confirmed on signup
*/

-- Drop the function with CASCADE to remove dependent triggers
DROP FUNCTION IF EXISTS public.send_signup_confirmation_email() CASCADE;
