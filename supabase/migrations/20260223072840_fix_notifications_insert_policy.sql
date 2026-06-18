/*
  # Fix Notifications Insert Policy

  1. Changes
    - Add INSERT policy for notifications table
    - Allow authenticated users to send notifications to other users
    - This is needed for custom orders, messages, and other user-to-user notifications

  2. Security
    - Only authenticated users can insert notifications
    - Users can send notifications to any user (for features like custom orders, messages, etc.)
*/

-- Drop existing insert policy if it exists
DROP POLICY IF EXISTS "Users can create notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;

-- Create new insert policy that allows authenticated users to send notifications to others
CREATE POLICY "Authenticated users can send notifications"
  ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (true);
