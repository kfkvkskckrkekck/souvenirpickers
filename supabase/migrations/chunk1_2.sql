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

-- =========================================
-- Migration: 20251126204259_add_order_tracking_and_refunds.sql
-- =========================================

/*
  # Add Order Tracking and Refunds

  1. Changes to Existing Tables
    - Add columns to `orders` table
      - `tracking_number` (text) - Shipping tracking number
      - `carrier` (text) - Shipping carrier name
      - `estimated_delivery` (date) - Expected delivery date
      - `actual_delivery` (timestamptz) - Actual delivery timestamp
      - `refund_requested_at` (timestamptz) - When refund was requested
      - `refund_reason` (text) - Reason for refund request
      - `refunded_at` (timestamptz) - When refund was processed
      - `refund_amount` (decimal) - Amount refunded

  2. New Tables
    - `order_updates`
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `status` (text) - Order status update
      - `message` (text) - Update message
      - `created_by` (uuid, references profiles)
      - `created_at` (timestamptz)

  3. Security
    - Enable RLS on new table
    - Add policies for order participants to view updates
*/

-- Add tracking and refund columns to orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'tracking_number'
  ) THEN
    ALTER TABLE orders ADD COLUMN tracking_number text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'carrier'
  ) THEN
    ALTER TABLE orders ADD COLUMN carrier text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'estimated_delivery'
  ) THEN
    ALTER TABLE orders ADD COLUMN estimated_delivery date;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'actual_delivery'
  ) THEN
    ALTER TABLE orders ADD COLUMN actual_delivery timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_requested_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_requested_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_reason'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_reason text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refunded_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN refunded_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'refund_amount'
  ) THEN
    ALTER TABLE orders ADD COLUMN refund_amount decimal(10,2);
  END IF;
END $$;

-- Create order_updates table
CREATE TABLE IF NOT EXISTS order_updates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL,
  message text NOT NULL,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE order_updates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order participants can view updates"
  ON order_updates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_updates.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can create updates for their orders"
  ON order_updates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_updates.order_id
      AND orders.picker_id = auth.uid()
    )
    AND auth.uid() = created_by
  );

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_order_updates_order_id ON order_updates(order_id);

-- =========================================
-- Migration: 20251126204324_add_analytics_and_verification.sql
-- =========================================

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

-- =========================================
-- Migration: 20251126212228_add_stripe_payment_system.sql
-- =========================================

-- Stripe Payment Integration System
--
-- 1. New Tables
--    - payment_intents: Tracks Stripe payment intents
--    - payment_escrow: Manages escrow system for secure payments
--    - refunds: Tracks refund requests and processing
--
-- 2. Security
--    - Enable RLS on all tables
--    - Clients can view their own payment records
--    - Pickers can view payments for their orders

-- Create payment_intents table
CREATE TABLE IF NOT EXISTS payment_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  stripe_payment_intent_id text UNIQUE,
  amount numeric(10, 2) NOT NULL,
  currency text DEFAULT 'usd',
  status text NOT NULL DEFAULT 'pending',
  client_secret text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payment_escrow table
CREATE TABLE IF NOT EXISTS payment_escrow (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_intent_id uuid REFERENCES payment_intents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  amount numeric(10, 2) NOT NULL,
  status text NOT NULL DEFAULT 'held',
  held_at timestamptz DEFAULT now(),
  released_at timestamptz,
  released_to uuid REFERENCES auth.users(id),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Create refunds table
CREATE TABLE IF NOT EXISTS refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_intent_id uuid REFERENCES payment_intents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  stripe_refund_id text UNIQUE,
  amount numeric(10, 2) NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending',
  initiated_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_escrow ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

-- Policies for payment_intents
CREATE POLICY "Users can view own payment intents"
  ON payment_intents FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payment_intents.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "System can insert payment intents"
  ON payment_intents FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update payment intents"
  ON payment_intents FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Policies for payment_escrow
CREATE POLICY "Users can view own escrow records"
  ON payment_escrow FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payment_escrow.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "System can manage escrow"
  ON payment_escrow FOR ALL
  TO authenticated
  WITH CHECK (true);

-- Policies for refunds
CREATE POLICY "Users can view own refunds"
  ON refunds FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = refunds.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can request refunds"
  ON refunds FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.client_id = auth.uid()
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payment_intents_order_id ON payment_intents(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_stripe_id ON payment_intents(stripe_payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_payment_escrow_order_id ON payment_escrow(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);


-- =========================================
-- Migration: 20251126212329_add_enhanced_notifications.sql
-- =========================================

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


-- =========================================
-- Migration: 20251126212354_add_shipping_tracking_system.sql
-- =========================================

-- Shipping and Tracking System
--
-- 1. New Tables
--    - shipping_providers: List of supported shipping carriers
--    - shipment_tracking: Track shipments with real-time updates
--    - shipping_rates: Store shipping rate quotes
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only view their own shipment information

-- Create shipping_providers table
CREATE TABLE IF NOT EXISTS shipping_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_code text UNIQUE NOT NULL,
  provider_name text NOT NULL,
  tracking_url_template text,
  supported_countries text[] DEFAULT ARRAY[]::text[],
  api_enabled boolean DEFAULT false,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Create shipment_tracking table
CREATE TABLE IF NOT EXISTS shipment_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  provider_id uuid REFERENCES shipping_providers(id),
  tracking_number text NOT NULL,
  carrier_code text,
  status text DEFAULT 'pending',
  current_location text,
  estimated_delivery timestamptz,
  actual_delivery timestamptz,
  tracking_events jsonb DEFAULT '[]'::jsonb,
  last_updated timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Create shipping_rates table
CREATE TABLE IF NOT EXISTS shipping_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  provider_id uuid REFERENCES shipping_providers(id),
  service_type text,
  rate numeric(10, 2) NOT NULL,
  currency text DEFAULT 'usd',
  estimated_days integer,
  quoted_at timestamptz DEFAULT now(),
  expires_at timestamptz,
  selected boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Insert default shipping providers
INSERT INTO shipping_providers (provider_code, provider_name, tracking_url_template, active)
VALUES 
  ('usps', 'USPS', 'https://tools.usps.com/go/TrackConfirmAction?tLabels={tracking_number}', true),
  ('ups', 'UPS', 'https://www.ups.com/track?tracknum={tracking_number}', true),
  ('fedex', 'FedEx', 'https://www.fedex.com/fedextrack/?tracknumbers={tracking_number}', true),
  ('dhl', 'DHL', 'https://www.dhl.com/en/express/tracking.html?AWB={tracking_number}', true),
  ('other', 'Other Carrier', null, true)
ON CONFLICT (provider_code) DO NOTHING;

-- Enable RLS
ALTER TABLE shipping_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipping_rates ENABLE ROW LEVEL SECURITY;

-- Policies for shipping_providers (public read)
CREATE POLICY "Anyone can view active providers"
  ON shipping_providers FOR SELECT
  TO authenticated
  USING (active = true);

-- Policies for shipment_tracking
CREATE POLICY "Users can view own shipment tracking"
  ON shipment_tracking FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can insert shipment tracking"
  ON shipment_tracking FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.picker_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update shipment tracking"
  ON shipment_tracking FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND orders.picker_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipment_tracking.order_id
      AND orders.picker_id = auth.uid()
    )
  );

-- Policies for shipping_rates
CREATE POLICY "Users can view own shipping rates"
  ON shipping_rates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = shipping_rates.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Pickers can manage shipping rates"
  ON shipping_rates FOR ALL
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_id
      AND orders.picker_id = auth.uid()
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_shipment_tracking_order_id ON shipment_tracking(order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_tracking_tracking_number ON shipment_tracking(tracking_number);
CREATE INDEX IF NOT EXISTS idx_shipping_rates_order_id ON shipping_rates(order_id);

-- Function to notify users of tracking updates
CREATE OR REPLACE FUNCTION notify_tracking_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status != OLD.status OR NEW.current_location != OLD.current_location THEN
    INSERT INTO notifications (user_id, type, title, message, link)
    SELECT 
      orders.client_id,
      'shipment_update',
      'Shipment Update',
      'Your order has been updated: ' || NEW.status,
      '/orders'
    FROM orders
    WHERE orders.id = NEW.order_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for tracking updates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_shipment_tracking_update'
  ) THEN
    CREATE TRIGGER on_shipment_tracking_update
      AFTER UPDATE ON shipment_tracking
      FOR EACH ROW
      EXECUTE FUNCTION notify_tracking_update();
  END IF;
END $$;


-- =========================================
-- Migration: 20251126212944_enhance_reviews_with_media.sql
-- =========================================

-- Enhanced Review System with Media Support
--
-- 1. Updates to reviews table
--    - Add support for photo/video reviews
--    - Add helpful/unhelpful voting
--    - Add verification status
--
-- 2. New Tables
--    - review_votes: Track helpful/unhelpful votes
--    - review_media: Store review photos and videos
--
-- 3. Security
--    - Enable RLS on new tables
--    - Users can vote on reviews once
--    - Only reviewers can add media to their reviews

-- Add new columns to reviews table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'images'
  ) THEN
    ALTER TABLE reviews ADD COLUMN images text[] DEFAULT ARRAY[]::text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'videos'
  ) THEN
    ALTER TABLE reviews ADD COLUMN videos text[] DEFAULT ARRAY[]::text[];
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'verified_purchase'
  ) THEN
    ALTER TABLE reviews ADD COLUMN verified_purchase boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'helpful_count'
  ) THEN
    ALTER TABLE reviews ADD COLUMN helpful_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'unhelpful_count'
  ) THEN
    ALTER TABLE reviews ADD COLUMN unhelpful_count integer DEFAULT 0;
  END IF;
END $$;

-- Create review_votes table
CREATE TABLE IF NOT EXISTS review_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES reviews(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  vote_type text NOT NULL CHECK (vote_type IN ('helpful', 'unhelpful')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(review_id, user_id)
);

-- Enable RLS
ALTER TABLE review_votes ENABLE ROW LEVEL SECURITY;

-- Policies for review_votes
CREATE POLICY "Users can view all votes"
  ON review_votes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can vote on reviews"
  ON review_votes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their votes"
  ON review_votes FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their votes"
  ON review_votes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_review_votes_review_id ON review_votes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_votes_user_id ON review_votes(user_id);

-- Function to update review vote counts
CREATE OR REPLACE FUNCTION update_review_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count + 1 WHERE id = NEW.review_id;
    ELSE
      UPDATE reviews SET unhelpful_count = unhelpful_count + 1 WHERE id = NEW.review_id;
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.vote_type != NEW.vote_type THEN
    IF NEW.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count + 1, unhelpful_count = unhelpful_count - 1 WHERE id = NEW.review_id;
    ELSE
      UPDATE reviews SET helpful_count = helpful_count - 1, unhelpful_count = unhelpful_count + 1 WHERE id = NEW.review_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.vote_type = 'helpful' THEN
      UPDATE reviews SET helpful_count = helpful_count - 1 WHERE id = OLD.review_id;
    ELSE
      UPDATE reviews SET unhelpful_count = unhelpful_count - 1 WHERE id = OLD.review_id;
    END IF;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update vote counts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_review_vote_change'
  ) THEN
    CREATE TRIGGER on_review_vote_change
      AFTER INSERT OR UPDATE OR DELETE ON review_votes
      FOR EACH ROW
      EXECUTE FUNCTION update_review_vote_counts();
  END IF;
END $$;

-- Function to mark verified purchases
CREATE OR REPLACE FUNCTION mark_verified_purchase()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_id IS NOT NULL THEN
    NEW.verified_purchase := true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to mark verified purchases
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_review_insert_verify'
  ) THEN
    CREATE TRIGGER on_review_insert_verify
      BEFORE INSERT ON reviews
      FOR EACH ROW
      EXECUTE FUNCTION mark_verified_purchase();
  END IF;
END $$;


-- =========================================
-- Migration: 20251126213146_add_social_features_v2.sql
-- =========================================

-- Social Features: Follow Pickers and Share Listings
--
-- 1. New Tables
--    - listing_shares: Track when listings are shared
--
-- 2. Updates
--    - Add follower_count to picker_profiles
--
-- 3. Security
--    - Enable RLS on listing_shares

-- Create listing_shares table
CREATE TABLE IF NOT EXISTS listing_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  platform text,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE listing_shares ENABLE ROW LEVEL SECURITY;

-- Policies for listing_shares
CREATE POLICY "Anyone can record a share"
  ON listing_shares FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view all shares"
  ON listing_shares FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_listing_shares_listing_id ON listing_shares(listing_id);

-- Add follower count to picker_profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'follower_count'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN follower_count integer DEFAULT 0;
  END IF;
END $$;

-- Function to update follower count
CREATE OR REPLACE FUNCTION update_picker_follower_count()
RETURNS TRIGGER AS $$
DECLARE
  picker_profile_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT id INTO picker_profile_id FROM picker_profiles WHERE user_id = NEW.picker_id;
    IF picker_profile_id IS NOT NULL THEN
      UPDATE picker_profiles SET follower_count = follower_count + 1 WHERE id = picker_profile_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT id INTO picker_profile_id FROM picker_profiles WHERE user_id = OLD.picker_id;
    IF picker_profile_id IS NOT NULL THEN
      UPDATE picker_profiles SET follower_count = GREATEST(0, follower_count - 1) WHERE id = picker_profile_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update follower count
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_follower_change_v2'
  ) THEN
    CREATE TRIGGER on_follower_change_v2
      AFTER INSERT OR DELETE ON favorite_pickers
      FOR EACH ROW
      EXECUTE FUNCTION update_picker_follower_count();
  END IF;
END $$;

-- Function to notify picker when followed
CREATE OR REPLACE FUNCTION notify_picker_followed()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, link)
  VALUES (
    NEW.picker_id,
    'new_follower',
    'New Follower',
    'Someone started following you!',
    '/profile'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new followers
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_picker_followed_v2'
  ) THEN
    CREATE TRIGGER on_picker_followed_v2
      AFTER INSERT ON favorite_pickers
      FOR EACH ROW
      EXECUTE FUNCTION notify_picker_followed();
  END IF;
END $$;


-- =========================================
-- Migration: 20251126214120_create_realtime_chat_system.sql
-- =========================================

-- Real-Time Chat System
--
-- 1. Updates to existing tables
--    - Add read_at timestamp to conversation_messages
--    - Add last_message and unread_count to conversations
--    - Add typing indicators
--
-- 2. New Tables
--    - message_reactions: React to messages with emojis
--    - message_attachments: Store file attachments
--    - typing_indicators: Track who is typing
--
-- 3. Security
--    - Enable RLS on all tables
--    - Real-time subscriptions enabled

-- Add new columns to conversation_messages
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'read_at'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN read_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'edited_at'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN edited_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversation_messages' AND column_name = 'deleted'
  ) THEN
    ALTER TABLE conversation_messages ADD COLUMN deleted boolean DEFAULT false;
  END IF;
END $$;

-- Add columns to conversations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'last_message'
  ) THEN
    ALTER TABLE conversations ADD COLUMN last_message text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'last_message_at'
  ) THEN
    ALTER TABLE conversations ADD COLUMN last_message_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'client_unread_count'
  ) THEN
    ALTER TABLE conversations ADD COLUMN client_unread_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'conversations' AND column_name = 'picker_unread_count'
  ) THEN
    ALTER TABLE conversations ADD COLUMN picker_unread_count integer DEFAULT 0;
  END IF;
END $$;

-- Create message_reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES conversation_messages(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  reaction text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(message_id, user_id, reaction)
);

-- Create message_attachments table
CREATE TABLE IF NOT EXISTS message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES conversation_messages(id) ON DELETE CASCADE,
  file_url text NOT NULL,
  file_name text,
  file_type text,
  file_size bigint,
  created_at timestamptz DEFAULT now()
);

-- Create typing_indicators table
CREATE TABLE IF NOT EXISTS typing_indicators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  is_typing boolean DEFAULT true,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Enable RLS
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- Policies for message_reactions
CREATE POLICY "Users can view reactions in their conversations"
  ON message_reactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.id = message_reactions.message_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can add reactions"
  ON message_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove their reactions"
  ON message_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Policies for message_attachments
CREATE POLICY "Users can view attachments in their conversations"
  ON message_attachments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.id = message_attachments.message_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can add attachments to their messages"
  ON message_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversation_messages cm
      WHERE cm.id = message_id
      AND cm.sender_id = auth.uid()
    )
  );

-- Policies for typing_indicators
CREATE POLICY "Users can view typing in their conversations"
  ON typing_indicators FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations c
      WHERE c.id = typing_indicators.conversation_id
      AND (c.client_id = auth.uid() OR c.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their typing status"
  ON typing_indicators FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_attachments_message_id ON message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_conversation_id ON typing_indicators(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_read ON conversation_messages(conversation_id, read_at);

-- Function to update conversation last message
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET 
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    updated_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update last message
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_message_sent_update_conversation'
  ) THEN
    CREATE TRIGGER on_message_sent_update_conversation
      AFTER INSERT ON conversation_messages
      FOR EACH ROW
      EXECUTE FUNCTION update_conversation_last_message();
  END IF;
END $$;

-- Function to update unread counts
CREATE OR REPLACE FUNCTION update_unread_counts()
RETURNS TRIGGER AS $$
DECLARE
  conv_client_id uuid;
  conv_picker_id uuid;
BEGIN
  SELECT client_id, picker_id INTO conv_client_id, conv_picker_id
  FROM conversations
  WHERE id = NEW.conversation_id;

  IF NEW.sender_id = conv_client_id THEN
    UPDATE conversations
    SET picker_unread_count = picker_unread_count + 1
    WHERE id = NEW.conversation_id;
  ELSE
    UPDATE conversations
    SET client_unread_count = client_unread_count + 1
    WHERE id = NEW.conversation_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for unread counts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_message_sent_update_unread'
  ) THEN
    CREATE TRIGGER on_message_sent_update_unread
      AFTER INSERT ON conversation_messages
      FOR EACH ROW
      EXECUTE FUNCTION update_unread_counts();
  END IF;
END $$;

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE conversation_messages
  SET read_at = now()
  WHERE conversation_id = p_conversation_id
  AND sender_id != auth.uid()
  AND read_at IS NULL;

  UPDATE conversations
  SET 
    client_unread_count = CASE WHEN client_id = auth.uid() THEN 0 ELSE client_unread_count END,
    picker_unread_count = CASE WHEN picker_id = auth.uid() THEN 0 ELSE picker_unread_count END
  WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251126214309_create_smart_recommendations_system.sql
-- =========================================

-- Smart Recommendations System
--
-- 1. New Tables
--    - user_activity: Track user browsing behavior
--    - listing_views: Track which listings users view
--    - user_preferences: Store inferred user preferences
--    - trending_listings: Cache trending listings
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only see their own activity

-- Create user_activity table
CREATE TABLE IF NOT EXISTS user_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL,
  entity_type text,
  entity_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create listing_views table
CREATE TABLE IF NOT EXISTS listing_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id text,
  duration_seconds integer,
  created_at timestamptz DEFAULT now()
);

-- Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  preferred_categories text[] DEFAULT ARRAY[]::text[],
  preferred_regions text[] DEFAULT ARRAY[]::text[],
  price_range_min numeric(10, 2),
  price_range_max numeric(10, 2),
  favorite_pickers text[] DEFAULT ARRAY[]::text[],
  browsing_patterns jsonb DEFAULT '{}'::jsonb,
  updated_at timestamptz DEFAULT now()
);

-- Create trending_listings table
CREATE TABLE IF NOT EXISTS trending_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  trend_score numeric(10, 2) NOT NULL,
  view_count integer DEFAULT 0,
  order_count integer DEFAULT 0,
  share_count integer DEFAULT 0,
  calculated_at timestamptz DEFAULT now(),
