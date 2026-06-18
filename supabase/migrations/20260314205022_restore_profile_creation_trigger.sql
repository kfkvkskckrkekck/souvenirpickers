/*
  # Restore Profile Creation Trigger

  This trigger automatically creates a profile when a new user signs up.
  Without this, users can create auth accounts but have no profile record.

  1. Changes
    - Recreate handle_new_user function
    - Recreate trigger on auth.users
    
  2. Security
    - Function runs as SECURITY DEFINER to access auth.users
    - Creates profiles and picker_profiles based on user metadata
*/

-- Create function to handle new user registration
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_type text;
  v_full_name text;
BEGIN
  -- Extract user metadata
  v_user_type := COALESCE(NEW.raw_user_meta_data->>'user_type', 'collector');
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));

  -- Create profile
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    user_type,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    v_full_name,
    v_user_type,
    NOW(),
    NOW()
  );

  -- If user is a picker, create picker_profile
  IF v_user_type = 'picker' THEN
    INSERT INTO public.picker_profiles (
      id,
      bio,
      specialties,
      languages,
      response_time_hours,
      created_at,
      updated_at,
      total_earnings,
      is_identity_verified,
      is_address_verified,
      verification_documents_submitted
    ) VALUES (
      NEW.id,
      '',
      ARRAY[]::text[],
      ARRAY['English'],
      24,
      NOW(),
      NOW(),
      0,
      false,
      false,
      false
    );

    -- Generate referral code for picker
    INSERT INTO public.referral_codes (user_id, code)
    VALUES (NEW.id, UPPER(SUBSTRING(MD5(NEW.id::text || NEW.email) FROM 1 FOR 8)))
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  -- Generate referral code for all users
  INSERT INTO public.referral_codes (user_id, code)
  VALUES (NEW.id, UPPER(SUBSTRING(MD5(NEW.id::text || NEW.email) FROM 1 FOR 8)))
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
