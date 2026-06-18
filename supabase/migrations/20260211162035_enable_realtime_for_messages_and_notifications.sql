/*
  # Enable Realtime for Messages and Notifications

  1. Changes
    - Enable Realtime subscriptions for conversation_messages table
    - Enable Realtime subscriptions for notifications table
    - This allows the Header component to receive live updates when new messages arrive

  2. Purpose
    - Fixes the issue where unread message badges don't update in real-time
    - Allows users to see instant notification when they receive a new message
*/

-- Enable Realtime for conversation_messages
ALTER PUBLICATION supabase_realtime ADD TABLE conversation_messages;

-- Enable Realtime for notifications
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
