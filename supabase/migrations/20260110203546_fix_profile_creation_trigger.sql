/*
  # Fix Profile Creation Trigger for All Cases

  1. Changes
    - Updates trigger to handle both auto-confirm and email confirmation cases
    - Creates profile immediately if email is already confirmed (auto-confirm enabled)
    - Creates profile when email gets confirmed (email confirmation enabled)
    - Ensures profile is always created regardless of confirmation setting

  2. Security
    - Function runs with SECURITY DEFINER to access auth schema
    - Properly scoped to public schema
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user_confirmation();

-- Create improved trigger function
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
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
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
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';
