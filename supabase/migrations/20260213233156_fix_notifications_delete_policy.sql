/*
  # Fix Notifications Delete Policy

  1. Changes
    - Add DELETE policy for notifications so users can delete their own notifications
    - Clean up orphaned notifications (notifications referencing deleted orders)

  2. Security
    - Users can only delete their own notifications
*/

-- Drop existing policy if it exists
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
EXCEPTION
  WHEN undefined_object THEN NULL;
END $$;

-- Add DELETE policy for notifications
CREATE POLICY "Users can delete own notifications"
  ON notifications
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Clean up orphaned notifications (notifications referencing deleted orders)
DELETE FROM notifications
WHERE metadata->>'order_id' IS NOT NULL
AND NOT EXISTS (
  SELECT 1 FROM orders 
  WHERE id::text = notifications.metadata->>'order_id'
);
