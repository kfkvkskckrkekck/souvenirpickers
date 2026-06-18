/*
  # Create client desires system

  ## Overview
  This migration creates a system for clients to express their souvenir desires,
  including specific items, categories, and preferred locations.

  ## 1. New Tables
    - `client_desires`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `title` (text, name of desired item)
      - `description` (text, detailed description)
      - `category` (text, item category)
      - `preferred_regions` (text[], list of desired regions/countries)
      - `preferred_locations` (text[], specific cities or places)
      - `latitude` (numeric, optional GPS latitude for specific location)
      - `longitude` (numeric, optional GPS longitude for specific location)
      - `budget_min` (numeric, minimum budget)
      - `budget_max` (numeric, maximum budget)
      - `urgency` (text, low/medium/high)
      - `active` (boolean, whether desire is still active)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ## 2. Security
    - Enable RLS on `client_desires` table
    - Clients can create, read, update, and delete their own desires
    - Authenticated pickers can view all active desires
    - Clients can only modify their own desires

  ## 3. Notes
    - Allows clients to specify what they're looking for
    - Pickers can browse desires to find matching opportunities
    - Supports location preferences and budget ranges
    - Urgency levels help prioritize requests
*/

CREATE TABLE IF NOT EXISTS client_desires (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  category text DEFAULT '',
  preferred_regions text[] DEFAULT '{}',
  preferred_locations text[] DEFAULT '{}',
  latitude numeric(10, 8),
  longitude numeric(11, 8),
  budget_min numeric(10, 2),
  budget_max numeric(10, 2),
  urgency text DEFAULT 'medium' CHECK (urgency IN ('low', 'medium', 'high')),
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE client_desires ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view own desires"
  ON client_desires FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

CREATE POLICY "Pickers can view all active desires"
  ON client_desires FOR SELECT
  TO authenticated
  USING (
    active = true AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'picker'
    )
  );

CREATE POLICY "Clients can create own desires"
  ON client_desires FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Clients can update own desires"
  ON client_desires FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Clients can delete own desires"
  ON client_desires FOR DELETE
  TO authenticated
  USING (auth.uid() = client_id);

CREATE INDEX IF NOT EXISTS idx_client_desires_client_id ON client_desires(client_id);
CREATE INDEX IF NOT EXISTS idx_client_desires_active ON client_desires(active);
CREATE INDEX IF NOT EXISTS idx_client_desires_category ON client_desires(category);