/*
  # Fix content_reports content_id column type

  1. Changes
    - Change content_id from UUID to TEXT
    - This allows reporting any content with flexible ID formats
*/

-- Change content_id column from UUID to TEXT
ALTER TABLE content_reports 
ALTER COLUMN content_id TYPE text USING content_id::text;