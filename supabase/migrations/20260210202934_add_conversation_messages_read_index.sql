/*
  # Add index for conversation_messages read status

  1. Performance Optimization
    - Add index on (conversation_id, read) for faster unread message queries
    - This improves the performance of counting unread messages

  2. Notes
    - Index helps with queries filtering by conversation_id and read status
    - Significantly speeds up unread message count calculations
*/

-- Add index for efficient unread message queries
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation_read
  ON conversation_messages(conversation_id, read)
  WHERE read = false;

-- Add index for sender queries
CREATE INDEX IF NOT EXISTS idx_conversation_messages_sender_read
  ON conversation_messages(sender_id, read)
  WHERE read = false;
