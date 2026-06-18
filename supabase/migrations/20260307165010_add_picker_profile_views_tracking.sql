/*
  # Add Picker Profile Views Tracking

  1. New Tables
    - `picker_profile_views`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references picker_profiles)
      - `viewer_id` (uuid, references profiles, nullable for anonymous)
      - `view_type` (text - 'profile', 'listing', 'search_result')
      - `listing_id` (uuid, nullable, references listings)
      - `created_at` (timestamptz)
  
  2. Security
    - Enable RLS on `picker_profile_views` table
    - Add policy for authenticated users to insert their own views
    - Add policy for pickers to read views of their own profile
  
  3. Changes
    - Adds comprehensive view tracking for analytics
    - Tracks profile views, listing views, and search result impressions
*/

-- Create picker profile views table
CREATE TABLE IF NOT EXISTS picker_profile_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES picker_profiles(id) ON DELETE CASCADE NOT NULL,
  viewer_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  view_type text NOT NULL CHECK (view_type IN ('profile', 'listing', 'search_result')),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_picker_profile_views_picker_id ON picker_profile_views(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_profile_views_viewer_id ON picker_profile_views(viewer_id);
CREATE INDEX IF NOT EXISTS idx_picker_profile_views_created_at ON picker_profile_views(created_at);
CREATE INDEX IF NOT EXISTS idx_picker_profile_views_picker_date ON picker_profile_views(picker_id, created_at);

-- Enable RLS
ALTER TABLE picker_profile_views ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone (including anonymous) can insert views
CREATE POLICY "Anyone can insert profile views"
  ON picker_profile_views FOR INSERT
  WITH CHECK (true);

-- Policy: Pickers can read views of their own profile
CREATE POLICY "Pickers can read own profile views"
  ON picker_profile_views FOR SELECT
  TO authenticated
  USING (
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  );

-- Policy: Service role has full access
CREATE POLICY "Service role has full access to profile views"
  ON picker_profile_views FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
