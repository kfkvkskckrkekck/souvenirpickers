/*
  # Fix Collections Table Permissions

  1. Grants
    - Grant all necessary permissions to authenticated users for collections table
    - Grant all necessary permissions to authenticated users for collection_items table
    - Ensure service_role has full access

  2. Security
    - Maintains existing RLS policies
    - Allows authenticated users to perform all operations subject to RLS
*/

-- Grant permissions on collections table
GRANT ALL ON collections TO authenticated;
GRANT ALL ON collections TO service_role;

-- Grant permissions on collection_items table
GRANT ALL ON collection_items TO authenticated;
GRANT ALL ON collection_items TO service_role;

-- Grant usage on sequences if they exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename LIKE 'collections_%') THEN
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;
  END IF;
END $$;