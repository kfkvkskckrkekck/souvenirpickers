/*
  # Add Analytics and Verification System

  1. Changes to Existing Tables
    - Add columns to `picker_profiles` table
      - `verification_status` (text) - unverified, pending, verified, rejected
      - `verification_documents` (text[]) - Array of document URLs
      - `verification_notes` (text) - Admin notes on verification
      - `verified_at` (timestamptz) - When verification was approved
      - `total_sales` (integer) - Total number of sales
      - `total_revenue` (decimal) - Total revenue earned
      - `last_active_at` (timestamptz) - Last activity timestamp

  2. New Tables
    - `picker_analytics`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references picker_profiles)
      - `date` (date) - Analytics date
      - `views` (integer) - Profile views
      - `messages_received` (integer) - Messages received
      - `orders_received` (integer) - Orders received
      - `revenue` (decimal) - Revenue for the day
      - `created_at` (timestamptz)

  3. Security
    - Enable RLS on new table
    - Add policies for pickers to view their own analytics
*/

-- Add columns to picker_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'verification_status'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN verification_status text DEFAULT 'unverified' CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'verification_documents'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN verification_documents text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'verification_notes'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN verification_notes text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'verified_at'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN verified_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'total_sales'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN total_sales integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'total_revenue'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN total_revenue decimal(10,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'last_active_at'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN last_active_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Create picker_analytics table
CREATE TABLE IF NOT EXISTS picker_analytics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES picker_profiles(id) ON DELETE CASCADE NOT NULL,
  date date NOT NULL DEFAULT CURRENT_DATE,
  views integer DEFAULT 0,
  messages_received integer DEFAULT 0,
  orders_received integer DEFAULT 0,
  revenue decimal(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(picker_id, date)
);

ALTER TABLE picker_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pickers can view own analytics"
  ON picker_analytics FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_analytics.picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "System can create analytics"
  ON picker_analytics FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_analytics.picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "System can update analytics"
  ON picker_analytics FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_analytics.picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_analytics.picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_picker_analytics_picker_id ON picker_analytics(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_analytics_date ON picker_analytics(date);