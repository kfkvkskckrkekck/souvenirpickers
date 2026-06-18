/*
  # Create Transportation Quotes System

  1. New Tables
    - `transportation_quotes`
      - `id` (uuid, primary key)
      - `conversation_id` (uuid, references conversations)
      - `picker_id` (uuid, references profiles)
      - `client_id` (uuid, references profiles)
      - `from_location` (text)
      - `to_location` (text)
      - `item_description` (text)
      - `transportation_cost` (numeric)
      - `estimated_delivery_days` (integer, nullable)
      - `notes` (text, nullable)
      - `status` (text: pending, accepted, rejected, expired)
      - `accepted_at` (timestamptz, nullable)
      - `expires_at` (timestamptz, defaults to 7 days from creation)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `transportation_quotes` table
    - Add policies for pickers to create quotes
    - Add policies for clients to view and accept/reject quotes
    - Add policies for both parties to view their quotes

  3. Indexes
    - Add index on conversation_id for fast lookups
    - Add index on picker_id and client_id for filtering
    - Add index on status for filtering
*/

-- Create transportation quotes table
CREATE TABLE IF NOT EXISTS transportation_quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  from_location text NOT NULL,
  to_location text NOT NULL,
  item_description text NOT NULL,
  transportation_cost numeric(10, 2) NOT NULL CHECK (transportation_cost >= 0),
  estimated_delivery_days integer CHECK (estimated_delivery_days > 0),
  notes text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  accepted_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_transportation_quotes_conversation_id ON transportation_quotes(conversation_id);
CREATE INDEX IF NOT EXISTS idx_transportation_quotes_picker_id ON transportation_quotes(picker_id);
CREATE INDEX IF NOT EXISTS idx_transportation_quotes_client_id ON transportation_quotes(client_id);
CREATE INDEX IF NOT EXISTS idx_transportation_quotes_status ON transportation_quotes(status);
CREATE INDEX IF NOT EXISTS idx_transportation_quotes_created_at ON transportation_quotes(created_at DESC);

-- Enable RLS
ALTER TABLE transportation_quotes ENABLE ROW LEVEL SECURITY;

-- Policy: Pickers can create transportation quotes
CREATE POLICY "Pickers can create transportation quotes"
  ON transportation_quotes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = picker_id
    AND EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.user_id = auth.uid()
    )
  );

-- Policy: Pickers can view their own quotes
CREATE POLICY "Pickers can view their own quotes"
  ON transportation_quotes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Policy: Clients can view quotes sent to them
CREATE POLICY "Clients can view quotes sent to them"
  ON transportation_quotes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- Policy: Clients can update quotes sent to them (accept/reject)
CREATE POLICY "Clients can update quotes sent to them"
  ON transportation_quotes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (
    auth.uid() = client_id
    AND status IN ('pending', 'accepted', 'rejected')
  );

-- Policy: Pickers can update their own pending quotes
CREATE POLICY "Pickers can update their own pending quotes"
  ON transportation_quotes
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = picker_id
    AND status = 'pending'
  )
  WITH CHECK (
    auth.uid() = picker_id
    AND status = 'pending'
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_transportation_quotes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_transportation_quotes_updated_at_trigger ON transportation_quotes;
CREATE TRIGGER update_transportation_quotes_updated_at_trigger
  BEFORE UPDATE ON transportation_quotes
  FOR EACH ROW
  EXECUTE FUNCTION update_transportation_quotes_updated_at();

-- Function to send notification when quote is accepted
CREATE OR REPLACE FUNCTION notify_quote_accepted()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, title, message, link)
    VALUES (
      NEW.picker_id,
      'quote_accepted',
      'Transportation Quote Accepted',
      'Your transportation quote has been accepted by the collector',
      '/messages'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for quote acceptance notifications
DROP TRIGGER IF EXISTS notify_quote_accepted_trigger ON transportation_quotes;
CREATE TRIGGER notify_quote_accepted_trigger
  AFTER UPDATE ON transportation_quotes
  FOR EACH ROW
  WHEN (NEW.status = 'accepted' AND OLD.status = 'pending')
  EXECUTE FUNCTION notify_quote_accepted();

-- Function to automatically expire old quotes
CREATE OR REPLACE FUNCTION expire_old_transportation_quotes()
RETURNS void AS $$
BEGIN
  UPDATE transportation_quotes
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON transportation_quotes TO authenticated;
GRANT SELECT ON transportation_quotes TO service_role;
