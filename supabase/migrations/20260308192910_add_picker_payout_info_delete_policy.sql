/*
  # Add DELETE policy for picker_payout_info

  1. Changes
    - Add DELETE policy to allow pickers to delete their own payout information
    - This enables the "Delete & Re-setup with Full Verification" button to work properly

  2. Security
    - Policy ensures pickers can only delete their own payout info (picker_id = auth.uid())
    - Maintains data security while allowing account cleanup
*/

-- Add DELETE policy for picker_payout_info
CREATE POLICY "Pickers can delete own payout info"
  ON picker_payout_info
  FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());
