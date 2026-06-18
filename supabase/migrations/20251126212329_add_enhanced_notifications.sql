-- Enhanced Notification System
--
-- 1. New Tables
--    - notification_preferences: User notification settings
--    - email_notifications: Queue for email notifications
--
-- 2. Updates to existing tables
--    - Add notification channels to notifications
--
-- 3. Security
--    - Enable RLS on new tables
--    - Users can only manage their own preferences

-- Create notification_preferences table
CREATE TABLE IF NOT EXISTS notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email_new_message boolean DEFAULT true,
  email_order_status boolean DEFAULT true,
  email_payment_received boolean DEFAULT true,
  email_review_received boolean DEFAULT true,
  email_marketing boolean DEFAULT false,
  push_new_message boolean DEFAULT true,
  push_order_status boolean DEFAULT true,
  push_payment_received boolean DEFAULT true,
  sms_order_shipped boolean DEFAULT false,
  sms_order_delivered boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create email_notifications queue
CREATE TABLE IF NOT EXISTS email_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  template text,
  status text DEFAULT 'pending',
  sent_at timestamptz,
  error text,
  created_at timestamptz DEFAULT now()
);

-- Add notification channels to existing notifications table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'channels'
  ) THEN
    ALTER TABLE notifications ADD COLUMN channels text[] DEFAULT ARRAY['app'];
  END IF;
END $$;

-- Enable RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_notifications ENABLE ROW LEVEL SECURITY;

-- Policies for notification_preferences
CREATE POLICY "Users can view own preferences"
  ON notification_preferences FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own preferences"
  ON notification_preferences FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can insert own preferences"
  ON notification_preferences FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for email_notifications
CREATE POLICY "Users can view own email notifications"
  ON email_notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can manage email notifications"
  ON email_notifications FOR ALL
  TO authenticated
  WITH CHECK (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_email_notifications_user_id ON email_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_email_notifications_status ON email_notifications(status);

-- Function to create default notification preferences
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create default preferences for new users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created_notification_prefs'
  ) THEN
    CREATE TRIGGER on_auth_user_created_notification_prefs
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION create_default_notification_preferences();
  END IF;
END $$;
