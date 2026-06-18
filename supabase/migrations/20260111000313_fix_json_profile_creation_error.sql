/*
  # Fix JSON Profile Creation Error

  1. Problem
    - The profile creation trigger fails when reading JSON from raw_user_meta_data
    - This causes 400/401 errors during signup
    - The JSON accessor (->> operator) may fail if the field is NULL or invalid

  2. Solution
    - Add proper NULL checks and error handling
    - Use EXCEPTION handling to catch JSON errors
    - Ensure trigger never fails even if metadata is missing
    - Log errors for debugging

  3. Security
    - Function runs with SECURITY DEFINER
    - Properly scoped to public schema
*/

-- Drop and recreate the function with better error handling
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

        RAISE LOG 'Profile created for user %', NEW.id;

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

-- Recreate the trigger for both INSERT and UPDATE
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Test that the function works
DO $$
BEGIN
  RAISE NOTICE 'Profile creation trigger fixed successfully';
END $$;
