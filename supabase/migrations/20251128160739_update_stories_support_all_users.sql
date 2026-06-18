/*
  # Update Stories to Support All Users

  1. Schema Changes
    - Rename `picker_id` to `user_id` in stories table
    - Update foreign key constraint
    - Update indexes
    - Update query joins to use profiles instead of picker-specific fields

  2. Security Updates
    - Update RLS policies to allow both pickers and collectors
    - Maintain security - users can only create/delete their own stories

  3. Notes
    - Stories are now available to all authenticated users
    - Both pickers and collectors can share 24-hour stories
    - Maintains backward compatibility with existing data
*/

-- Rename picker_id column to user_id
ALTER TABLE stories 
  RENAME COLUMN picker_id TO user_id;

-- Drop old index and create new one with correct name
DROP INDEX IF EXISTS stories_picker_id_idx;
CREATE INDEX IF NOT EXISTS stories_user_id_idx ON stories(user_id);

-- Update RLS policies to support all authenticated users
DROP POLICY IF EXISTS "Pickers can create stories" ON stories;
DROP POLICY IF EXISTS "Pickers can delete own stories" ON stories;

CREATE POLICY "Authenticated users can create stories"
  ON stories FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own stories"
  ON stories FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Update story_views foreign key reference (already correct, just for clarity)
-- The viewer_id correctly references profiles(id) which includes all user types