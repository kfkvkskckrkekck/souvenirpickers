/*
  # Add Delete Policy for Live Streams

  1. Changes
    - Add DELETE policy for live_streams table
    - Allow pickers to delete their own streams
    - This enables pickers to remove old or unwanted streams

  2. Security
    - Only the picker who created the stream can delete it
    - Must be authenticated
    - Uses auth.uid() to verify ownership
*/

-- Add DELETE policy for live streams
CREATE POLICY "Pickers can delete own streams"
  ON live_streams FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());