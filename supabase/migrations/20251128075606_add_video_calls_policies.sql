/*
  # Add RLS policies for video_calls table

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for video_calls table
  
  2. Security
    - Video calls accessible by both initiator and receiver
    - Only initiator can create calls
    - Both parties can update call status
*/

-- Video calls policies
CREATE POLICY "Users can view their video calls"
  ON video_calls
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  );

CREATE POLICY "Users can initiate video calls"
  ON video_calls
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = initiator_id);

CREATE POLICY "Users can update their video calls"
  ON video_calls
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  )
  WITH CHECK (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  );
