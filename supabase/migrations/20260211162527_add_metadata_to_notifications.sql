/*
  # Add metadata column to notifications table

  1. Changes
    - Add metadata JSONB column to store additional notification data
    - This allows message notifications to store conversation_id, message_id, and sender info

  2. Purpose
    - Fixes the bug where message notifications weren't being created
    - The trigger was trying to insert into a non-existent metadata column
*/

-- Add metadata column to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Add index for metadata queries
CREATE INDEX IF NOT EXISTS idx_notifications_metadata ON notifications USING gin(metadata);
