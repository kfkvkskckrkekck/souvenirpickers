/*
  # Fix Picker Profile Creation on Signup

  1. Problem
    - When users sign up as pickers, only the basic profile is created
    - The picker_profiles record is missing, preventing them from listing items
    
  2. Solution
    - Update the handle_new_user trigger to also create picker_profiles for picker users
    - Backfill any existing pickers who are missing picker_profiles
    
  3. Security
    - Maintains existing security definer context
*/

-- Drop and recreate with picker_profiles support
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Only create profile when email is confirmed
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      BEGIN
        -- Safely extract metadata with NULL checks
        IF NEW.raw_user_meta_data IS NOT NULL THEN
          full_name_val := NEW.raw_user_meta_data->>'full_name';
          user_type_val := NEW.raw_user_meta_data->>'user_type';
        END IF;

        -- Apply defaults if extraction failed or returned NULL
        full_name_val := COALESCE(full_name_val, 'User');
        user_type_val := COALESCE(user_type_val, 'client');

        -- Validate user_type
        IF user_type_val NOT IN ('client', 'picker') THEN
          user_type_val := 'client';
        END IF;

        -- Create profile
        INSERT INTO profiles (id, email, full_name, user_type, created_at)
        VALUES (
          NEW.id,
          NEW.email,
          full_name_val,
          user_type_val,
          NOW()
        )
        ON CONFLICT (id) DO NOTHING;

        -- Create picker_profiles if user is a picker
        IF user_type_val = 'picker' THEN
          INSERT INTO picker_profiles (user_id, verified, created_at)
          VALUES (NEW.id, false, NOW())
          ON CONFLICT (user_id) DO NOTHING;
          
          RAISE LOG 'Picker profile created for user %', NEW.id;
        END IF;

        RAISE LOG 'Profile created for user % as %', NEW.id, user_type_val;

      EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail the trigger
        RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
        
        -- Create profile with defaults as fallback
        INSERT INTO profiles (id, email, full_name, user_type, created_at)
        VALUES (
          NEW.id,
          COALESCE(NEW.email, 'unknown@example.com'),
          'User',
          'client',
          NOW()
        )
        ON CONFLICT (id) DO NOTHING;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Backfill: Create picker_profiles for existing pickers who don't have one
INSERT INTO picker_profiles (user_id, verified, created_at)
SELECT id, false, NOW()
FROM profiles
WHERE user_type = 'picker'
  AND NOT EXISTS (
    SELECT 1 FROM picker_profiles WHERE user_id = profiles.id
  );
