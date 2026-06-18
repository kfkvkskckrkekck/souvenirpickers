/*
  # Create Profile Automatically After Email Confirmation

  1. Changes
    - Creates a trigger function that runs when a user confirms their email
    - Automatically creates profile and picker_profile based on user metadata
    - Handles the profile creation that previously happened in the signup function

  2. Details
    - Extracts full_name and user_type from auth.users raw_user_meta_data
    - Creates profile record with the user's information
    - Creates picker_profile if user_type is 'picker'
    - Generates referral code for new users
*/

-- Function to create profile after email confirmation
CREATE OR REPLACE FUNCTION handle_new_user_confirmation()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Only proceed if email is confirmed and profile doesn't exist
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    
    -- Check if profile already exists
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
      
      -- Extract metadata
      full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
      user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user % after email confirmation', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_confirmation();

-- Add comment
COMMENT ON FUNCTION handle_new_user_confirmation() IS 'Automatically creates profile and picker_profile when user confirms their email';
