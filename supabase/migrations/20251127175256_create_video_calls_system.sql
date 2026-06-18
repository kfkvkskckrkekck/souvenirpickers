/*
  # Create Video Call System

  1. New Tables
    - `video_calls`
      - `id` (uuid, primary key)
      - `conversation_id` (uuid, references conversations)
      - `initiator_id` (uuid, references profiles)
      - `receiver_id` (uuid, references profiles)
      - `room_name` (text, unique identifier for the call)
      - `status` (text: 'initiated', 'ringing', 'active', 'ended', 'missed', 'declined')
      - `started_at` (timestamptz, when call started)
      - `ended_at` (timestamptz, when call ended)
      - `duration_seconds` (integer, call duration)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `video_calls` table
    - Add policies for authenticated users to manage their own video calls
    - Add policies to view calls they are part of

  3. Indexes
    - Index on conversation_id for faster lookups
    - Index on initiator_id and receiver_id
    - Index on status for filtering active calls

  4. Functions
    - Trigger to update conversation's updated_at on new call
    - Function to generate unique room names
*/

-- Create video_calls table
CREATE TABLE IF NOT EXISTS video_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  initiator_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  room_name text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'active', 'ended', 'missed', 'declined')),
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_video_calls_conversation_id ON video_calls(conversation_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_initiator_id ON video_calls(initiator_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_receiver_id ON video_calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_status ON video_calls(status);
CREATE INDEX IF NOT EXISTS idx_video_calls_created_at ON video_calls(created_at DESC);

-- Enable Row Level Security
ALTER TABLE video_calls ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view video calls they are part of
CREATE POLICY "Users can view their own video calls"
  ON video_calls
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = initiator_id OR
    auth.uid() = receiver_id
  );

-- Policy: Users can create video calls
CREATE POLICY "Users can create video calls"
  ON video_calls
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = initiator_id);

-- Policy: Users can update video calls they are part of
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

-- Policy: Users can delete video calls they initiated
CREATE POLICY "Users can delete video calls they initiated"
  ON video_calls
  FOR DELETE
  TO authenticated
  USING (auth.uid() = initiator_id);

-- Function to update video_calls updated_at timestamp
CREATE OR REPLACE FUNCTION update_video_calls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS video_calls_updated_at ON video_calls;
CREATE TRIGGER video_calls_updated_at
  BEFORE UPDATE ON video_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_video_calls_updated_at();

-- Function to update conversation when video call is created
CREATE OR REPLACE FUNCTION update_conversation_on_video_call()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update conversation on new video call
DROP TRIGGER IF EXISTS update_conversation_on_video_call ON video_calls;
CREATE TRIGGER update_conversation_on_video_call
  AFTER INSERT ON video_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_video_call();
