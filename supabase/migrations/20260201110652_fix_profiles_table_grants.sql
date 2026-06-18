/*
  # Fix Profiles Table Permissions

  1. Changes
    - Grant SELECT, INSERT, UPDATE permissions to authenticated and anon roles
    - This allows users to read and update their profiles through the API
  
  2. Security
    - RLS policies are already in place to restrict access
    - Users can only access their own data as defined by existing policies
*/

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- Grant SELECT permission to anon role for public profile viewing
GRANT SELECT ON public.profiles TO anon;
