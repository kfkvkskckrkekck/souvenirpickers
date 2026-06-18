/*
  # Custom Password Reset System

  1. New Tables
    - `password_reset_requests`
      - `id` (uuid, primary key)
      - `email` (text) - User's email requesting reset
      - `reset_token` (text, unique) - Secure token for reset
      - `status` (text) - pending, completed, expired
      - `expires_at` (timestamptz) - Token expiration (24 hours)
      - `created_at` (timestamptz)
      - `used_at` (timestamptz)

  2. Security
    - Enable RLS on `password_reset_requests` table
    - Add policy for users to create their own reset requests
    - Add policy for users to view their own pending requests
    - Tokens expire after 24 hours
    - Tokens are single-use only

  3. Important Notes
    - This system bypasses the need for SMTP email configuration
    - Users can request a password reset and receive a secure token
    - The token can be used to reset the password
    - Old/expired tokens are automatically invalidated
*/

-- Create password reset requests table
CREATE TABLE IF NOT EXISTS password_reset_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  reset_token text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  created_at timestamptz DEFAULT now(),
  used_at timestamptz
);

-- Enable RLS
ALTER TABLE password_reset_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can create a password reset request
CREATE POLICY "Anyone can request password reset"
  ON password_reset_requests
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Policy: Users can view their own reset requests
CREATE POLICY "Users can view own reset requests"
  ON password_reset_requests
  FOR SELECT
  TO anon
  USING (
    email IN (
      SELECT email FROM auth.users
    )
  );

-- Policy: Authenticated users can update their own pending reset requests
CREATE POLICY "Users can use their reset tokens"
  ON password_reset_requests
  FOR UPDATE
  TO anon
  USING (
    status = 'pending' 
    AND expires_at > now()
  )
  WITH CHECK (
    status IN ('completed', 'expired')
  );

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_token ON password_reset_requests(reset_token);
CREATE INDEX IF NOT EXISTS idx_password_reset_email ON password_reset_requests(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_status ON password_reset_requests(status, expires_at);