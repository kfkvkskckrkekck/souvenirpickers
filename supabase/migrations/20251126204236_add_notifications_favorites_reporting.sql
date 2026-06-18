/*
  # Add Notifications, Favorites, and Reporting Systems

  1. New Tables
    - `notifications`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles) - Who receives the notification
      - `type` (text) - Type of notification (order_status, new_message, new_review, etc.)
      - `title` (text) - Notification title
      - `message` (text) - Notification message
      - `link` (text) - Optional link to related content
      - `read` (boolean) - Whether notification has been read
      - `created_at` (timestamptz)

    - `favorites`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles) - Who favorited
      - `listing_id` (uuid, references listings) - What was favorited
      - `created_at` (timestamptz)

    - `favorite_pickers`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles) - Who favorited
      - `picker_id` (uuid, references picker_profiles) - Which picker was favorited
      - `created_at` (timestamptz)

    - `reported_users`
      - `id` (uuid, primary key)
      - `reporter_id` (uuid, references profiles) - Who reported
      - `reported_user_id` (uuid, references profiles) - Who was reported
      - `reason` (text) - Reason for report
      - `description` (text) - Detailed description
      - `status` (text) - pending, reviewed, resolved, dismissed
      - `reviewed_by` (uuid, references profiles) - Admin who reviewed
      - `reviewed_at` (timestamptz)
      - `created_at` (timestamptz)

    - `blocked_users`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles) - Who blocked
      - `blocked_user_id` (uuid, references profiles) - Who was blocked
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users to manage their own data
    - Restrict report viewing to admins and reporters
*/

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  link text,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can create notifications"
  ON notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create favorites table
CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(client_id, listing_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own favorites"
  ON favorites FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

CREATE POLICY "Users can create own favorites"
  ON favorites FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can delete own favorites"
  ON favorites FOR DELETE
  TO authenticated
  USING (auth.uid() = client_id);

-- Create favorite_pickers table
CREATE TABLE IF NOT EXISTS favorite_pickers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  picker_id uuid REFERENCES picker_profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(client_id, picker_id)
);

ALTER TABLE favorite_pickers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own favorite pickers"
  ON favorite_pickers FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

CREATE POLICY "Users can create own favorite pickers"
  ON favorite_pickers FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can delete own favorite pickers"
  ON favorite_pickers FOR DELETE
  TO authenticated
  USING (auth.uid() = client_id);

-- Create reported_users table
CREATE TABLE IF NOT EXISTS reported_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  reported_user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  reason text NOT NULL,
  description text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE reported_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reports"
  ON reported_users FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_id);

CREATE POLICY "Users can create reports"
  ON reported_users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- Create blocked_users table
CREATE TABLE IF NOT EXISTS blocked_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, blocked_user_id)
);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own blocked list"
  ON blocked_users FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can block users"
  ON blocked_users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unblock users"
  ON blocked_users FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_favorites_client_id ON favorites(client_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);
CREATE INDEX IF NOT EXISTS idx_favorite_pickers_client_id ON favorite_pickers(client_id);
CREATE INDEX IF NOT EXISTS idx_reported_users_status ON reported_users(status);
CREATE INDEX IF NOT EXISTS idx_blocked_users_user_id ON blocked_users(user_id);