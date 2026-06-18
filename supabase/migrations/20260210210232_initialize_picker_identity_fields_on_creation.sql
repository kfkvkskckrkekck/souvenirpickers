/*
  # Initialize Picker Identity Fields on Profile Creation
  
  1. Purpose
    - Ensures new picker profiles have empty identity fields initialized
    - Prevents picker profiles from accidentally showing collector profile data
    - Maintains separation between picker and collector identities
  
  2. Changes
    - Updates the profile creation trigger to initialize picker identity fields
    - Sets full_name, bio, and avatar_url to empty strings for new picker profiles
*/

-- Update the trigger function to initialize picker identity fields
CREATE OR REPLACE FUNCTION create_profile_on_email_confirmation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_type_val text;
  full_name_val text;
BEGIN
  -- Only proceed if email was confirmed (confirmed_at was NULL and is now NOT NULL)
  IF OLD.confirmed_at IS NULL AND NEW.confirmed_at IS NOT NULL THEN
    RAISE LOG 'Email confirmed for user %', NEW.id;
    
    -- Check if profile already exists
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
      RAISE LOG 'Creating profile for user %', NEW.id;
      
      -- Extract user_type and full_name from raw_user_meta_data
      user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'collector');
      full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', '');
      
      RAISE LOG 'User type: %, Full name: %', user_type_val, full_name_val;
      
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
      
      -- Create picker profile if needed with initialized identity fields
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (
          user_id,
          full_name,
          bio,
          avatar_url,
          current_location
        )
        VALUES (
          NEW.id,
          '',
          '',
          '',
          ''
        )
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user % after email confirmation', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;

CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_profile_on_email_confirmation();
