/*
  # AI Media Verification System

  1. New Tables
    - `media_verification_records`
      - `id` (uuid, primary key)
      - `media_url` (text) - URL of the media being verified
      - `media_type` (enum: 'image' or 'video')
      - `storage_bucket` (text) - Which storage bucket (listing-images, listing-videos, profile-avatars)
      - `storage_path` (text) - Path in storage bucket
      - `uploader_id` (uuid, references profiles)
      - `verification_status` (enum: 'pending', 'processing', 'verified', 'suspicious', 'rejected')
      - `confidence_score` (decimal 0-100) - AI confidence in authenticity
      - `ai_provider` (text) - Which AI service was used
      - `ai_response` (jsonb) - Full API response
      - `rejection_reason` (text) - Why media was flagged
      - `reviewed_by` (uuid, nullable) - Admin who manually reviewed
      - `reviewed_at` (timestamp)
      - `verified_at` (timestamp)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on media_verification_records
    - Users can view their own verification records
    - Admins can view all records and update review status
    - System (service role) can create and update records

  3. Indexes
    - Index on uploader_id for fast user queries
    - Index on verification_status for admin filtering
    - Index on created_at for chronological queries

  4. Notes
    - AI verification happens asynchronously after upload
    - Users can see if their media is pending verification
    - Admins can manually review suspicious content
    - Verified media gets displayed with trust badge
*/

-- Create enum for media types
DO $$ BEGIN
  CREATE TYPE media_verification_type AS ENUM ('image', 'video');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create enum for verification status
DO $$ BEGIN
  CREATE TYPE media_verification_status AS ENUM ('pending', 'processing', 'verified', 'suspicious', 'rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create media verification records table
CREATE TABLE IF NOT EXISTS media_verification_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_url text NOT NULL,
  media_type media_verification_type NOT NULL,
  storage_bucket text NOT NULL,
  storage_path text NOT NULL,
  uploader_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  verification_status media_verification_status DEFAULT 'pending' NOT NULL,
  confidence_score decimal(5,2) CHECK (confidence_score >= 0 AND confidence_score <= 100),
  ai_provider text,
  ai_response jsonb,
  rejection_reason text,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  verified_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_media_verification_uploader 
  ON media_verification_records(uploader_id);

CREATE INDEX IF NOT EXISTS idx_media_verification_status 
  ON media_verification_records(verification_status);

CREATE INDEX IF NOT EXISTS idx_media_verification_created 
  ON media_verification_records(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_verification_storage_path 
  ON media_verification_records(storage_path);

-- Enable RLS
ALTER TABLE media_verification_records ENABLE ROW LEVEL SECURITY;

-- Users can view their own verification records
CREATE POLICY "Users can view own verification records"
  ON media_verification_records
  FOR SELECT
  TO authenticated
  USING (auth.uid() = uploader_id);

-- System can create verification records (via service role)
CREATE POLICY "System can create verification records"
  ON media_verification_records
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = uploader_id);

-- System can update verification records (via service role for AI results)
CREATE POLICY "System can update verification records"
  ON media_verification_records
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = uploader_id OR EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.user_type = 'admin'
  ));

-- Admins can view all verification records
CREATE POLICY "Admins can view all verification records"
  ON media_verification_records
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.user_type = 'admin'
  ));

-- Admins can update verification records (for manual review)
CREATE POLICY "Admins can update verification records"
  ON media_verification_records
  FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.user_type = 'admin'
  ));

-- Function to get verification status for media
CREATE OR REPLACE FUNCTION get_media_verification_status(p_storage_path text)
RETURNS TABLE (
  status media_verification_status,
  confidence_score decimal,
  verified_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mvr.verification_status,
    mvr.confidence_score,
    mvr.verified_at
  FROM media_verification_records mvr
  WHERE mvr.storage_path = p_storage_path
  ORDER BY mvr.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set search path for the function
ALTER FUNCTION get_media_verification_status(text) SET search_path = public, pg_temp;
