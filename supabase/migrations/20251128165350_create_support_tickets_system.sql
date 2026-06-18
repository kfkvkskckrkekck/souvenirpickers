/*
  # Create Support Tickets System

  1. New Tables
    - `support_tickets`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `subject` (text)
      - `message` (text)
      - `category` (text)
      - `status` (text) - open, in_progress, resolved, closed
      - `priority` (text) - low, medium, high, urgent
      - `assigned_to` (uuid, nullable, for admin assignment)
      - `resolved_at` (timestamptz, nullable)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `support_tickets` table
    - Add policy for users to create their own tickets
    - Add policy for users to view their own tickets
    - Add policy for users to update their own open tickets
*/

CREATE TABLE IF NOT EXISTS support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  status text NOT NULL DEFAULT 'open',
  priority text NOT NULL DEFAULT 'medium',
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create their own support tickets"
  ON support_tickets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own support tickets"
  ON support_tickets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own open support tickets"
  ON support_tickets
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'open')
  WITH CHECK (auth.uid() = user_id AND status = 'open');

CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created_at ON support_tickets(created_at DESC);

CREATE OR REPLACE FUNCTION update_support_ticket_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_support_tickets_updated_at
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION update_support_ticket_updated_at();
