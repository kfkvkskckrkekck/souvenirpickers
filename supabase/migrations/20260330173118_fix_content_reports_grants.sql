/*
  # Fix content_reports table permissions

  1. Changes
    - Grant necessary permissions to authenticated users
    - Grant permissions to service_role
*/

-- Grant permissions to authenticated users
GRANT SELECT, INSERT ON content_reports TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON content_reports TO service_role;