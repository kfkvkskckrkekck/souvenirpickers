/*
  # Create Mark Messages Read Function

  1. Changes
    - Create mark_messages_read RPC function
    - Resets unread count for the conversation
    - Marks all unread messages as read
  
  2. Security
    - Uses SECURITY DEFINER to allow updating messages
    - Validates user is part of the conversation
*/

CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_client boolean;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check if user is part of this conversation
  SELECT 
    CASE WHEN client_id = v_user_id THEN true ELSE false END
  INTO v_is_client
  FROM conversations
  WHERE id = p_conversation_id
    AND (client_id = v_user_id OR picker_id = v_user_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User is not part of this conversation';
  END IF;

  -- Mark all messages as read for this user
  UPDATE conversation_messages
  SET read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id != v_user_id
    AND read = false;

  -- Reset unread count for this user
  IF v_is_client THEN
    UPDATE conversations
    SET client_unread_count = 0
    WHERE id = p_conversation_id;
  ELSE
    UPDATE conversations
    SET picker_unread_count = 0
    WHERE id = p_conversation_id;
  END IF;
END;
$$;