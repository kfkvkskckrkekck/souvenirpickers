/*
  # Fix Picker Profiles Table Permissions

  1. Problem
    - The picker_profiles table has RLS policies but no grants for authenticated users
    - This causes "permission denied" errors when trying to update picker profiles
    
  2. Solution
    - Grant necessary permissions to authenticated users
    - Ensure RLS is enabled (already is)
    
  3. Security
    - Grants are safe because RLS policies control actual access
    - Users can only update their own picker profiles per existing RLS policies
*/

-- Grant necessary permissions to authenticated users
GRANT SELECT ON picker_profiles TO authenticated;
GRANT INSERT ON picker_profiles TO authenticated;
GRANT UPDATE ON picker_profiles TO authenticated;
GRANT DELETE ON picker_profiles TO authenticated;

-- Verify RLS is enabled (should already be)
ALTER TABLE picker_profiles ENABLE ROW LEVEL SECURITY;

-- Ensure the policies are properly in place
DO $$
BEGIN
  -- Drop and recreate policies to ensure they're correct
  DROP POLICY IF EXISTS "Anyone can view picker profiles" ON picker_profiles;
  DROP POLICY IF EXISTS "Pickers can insert own profile" ON picker_profiles;
  DROP POLICY IF EXISTS "Pickers can update own profile" ON picker_profiles;
  
  -- SELECT policy - anyone can view
  CREATE POLICY "Anyone can view picker profiles"
    ON picker_profiles
    FOR SELECT
    TO authenticated
    USING (true);
  
  -- INSERT policy - users can create their own profile
  CREATE POLICY "Pickers can insert own profile"
    ON picker_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());
  
  -- UPDATE policy - users can update their own profile
  CREATE POLICY "Pickers can update own profile"
    ON picker_profiles
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
END $$;
