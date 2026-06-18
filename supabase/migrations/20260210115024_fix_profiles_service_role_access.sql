/*
  # Fix Profiles Table Service Role Access

  1. Changes
    - Grant explicit SELECT, INSERT, UPDATE permissions to service_role on profiles table
    - Add a policy to allow service_role to bypass RLS entirely
    - Ensure authenticated users can still access profiles normally

  2. Security
    - Service role can access all profiles (needed for edge functions)
    - Authenticated users maintain their existing access patterns
*/

-- Grant explicit permissions to service_role
GRANT SELECT, INSERT, UPDATE ON profiles TO service_role;

-- Create a policy for service_role to bypass RLS
DO $$ 
BEGIN
  -- Drop if exists to avoid conflicts
  DROP POLICY IF EXISTS "Service role can manage all profiles" ON profiles;
  
  -- Create policy for service role
  CREATE POLICY "Service role can manage all profiles"
    ON profiles
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END $$;
