/*
  # Add Phone and Account Recovery Options

  1. Changes to profiles table
    - Add `phone_number` column for SMS-based authentication
    - Add `phone_verified` boolean flag
    - Add `phone_verified_at` timestamp
    - Add `backup_email` for alternative recovery email
    - Add `backup_email_verified` boolean flag
    - Add `preferred_recovery_method` enum
    - Add `last_recovery_attempt` timestamp for rate limiting

  2. Security
    - Existing RLS policies remain in place
    - Users can only modify their own recovery options
    - Phone numbers are stored with country code format

  3. Notes
    - Phone numbers should be in E.164 format (+1234567890)
    - SMS functionality requires external service integration
    - Backup email must be different from primary email
*/

-- Add new columns to profiles table
DO $$
BEGIN
  -- Add phone number support
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'phone_number'
  ) THEN
    ALTER TABLE profiles ADD COLUMN phone_number text;
    ALTER TABLE profiles ADD COLUMN phone_verified boolean DEFAULT false;
    ALTER TABLE profiles ADD COLUMN phone_verified_at timestamptz;
  END IF;

  -- Add backup email support
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'backup_email'
  ) THEN
    ALTER TABLE profiles ADD COLUMN backup_email text;
    ALTER TABLE profiles ADD COLUMN backup_email_verified boolean DEFAULT false;
  END IF;

  -- Add recovery preferences
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'preferred_recovery_method'
  ) THEN
    ALTER TABLE profiles ADD COLUMN preferred_recovery_method text DEFAULT 'email' CHECK (preferred_recovery_method IN ('email', 'phone', 'magic_link'));
    ALTER TABLE profiles ADD COLUMN last_recovery_attempt timestamptz;
  END IF;

  -- Add auth method tracking
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'linked_auth_providers'
  ) THEN
    ALTER TABLE profiles ADD COLUMN linked_auth_providers text[] DEFAULT ARRAY[]::text[];
    ALTER TABLE profiles ADD COLUMN last_login_method text;
    ALTER TABLE profiles ADD COLUMN last_login_at timestamptz;
  END IF;
END $$;

-- Create index on phone numbers for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number ON profiles(phone_number) WHERE phone_number IS NOT NULL;

-- Create index on backup emails
CREATE INDEX IF NOT EXISTS idx_profiles_backup_email ON profiles(backup_email) WHERE backup_email IS NOT NULL;

-- Add constraint to ensure backup email is different from primary email
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'backup_email_different_from_primary'
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT backup_email_different_from_primary
    CHECK (backup_email IS NULL OR backup_email != email);
  END IF;
END $$;

-- Create a function to update last login tracking
CREATE OR REPLACE FUNCTION update_last_login()
RETURNS TRIGGER AS $$
BEGIN
  -- This would be called from application code when user logs in
  -- Just creating the structure here
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create recovery attempts table for rate limiting
CREATE TABLE IF NOT EXISTS recovery_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  email text NOT NULL,
  phone_number text,
  recovery_method text NOT NULL CHECK (recovery_method IN ('email', 'phone', 'magic_link')),
  attempted_at timestamptz DEFAULT now(),
  success boolean DEFAULT false,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on recovery_attempts
ALTER TABLE recovery_attempts ENABLE ROW LEVEL SECURITY;

-- Users can view their own recovery attempts
CREATE POLICY "Users can view own recovery attempts"
  ON recovery_attempts
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Only authenticated users can insert recovery attempts
CREATE POLICY "Users can log own recovery attempts"
  ON recovery_attempts
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create index on recovery attempts for rate limiting queries
CREATE INDEX IF NOT EXISTS idx_recovery_attempts_user_time
  ON recovery_attempts(user_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_recovery_attempts_email_time
  ON recovery_attempts(email, attempted_at DESC);

-- Function to check rate limiting for recovery attempts
CREATE OR REPLACE FUNCTION check_recovery_rate_limit(
  p_identifier text,
  p_method text,
  p_time_window interval DEFAULT '1 hour'::interval,
  p_max_attempts integer DEFAULT 5
)
RETURNS boolean AS $$
DECLARE
  attempt_count integer;
BEGIN
  SELECT COUNT(*)
  INTO attempt_count
  FROM recovery_attempts
  WHERE (email = p_identifier OR phone_number = p_identifier)
    AND recovery_method = p_method
    AND attempted_at > (now() - p_time_window);

  RETURN attempt_count < p_max_attempts;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;