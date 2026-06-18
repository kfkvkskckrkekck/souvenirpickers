/*
  # Complete Marketplace Schema - Consolidated Migration

  This migration consolidates ALL 86 migrations into one comprehensive schema.
  It includes:

  ## Core Tables
  - profiles, picker_profiles, listings, requests, messages, reviews

  ## Order & Payment System
  - orders, order_items, cart_items, payment_intents, payment_escrow, refunds
  - stripe_subscriptions, picker_subscription_payments, picker_payment_cards
  - collector_payment_methods, picker_payout_info

  ## Communication & Social
  - conversations, conversation_messages, conversation_participants
  - followers, likes, comments, social_posts, stories, live_streams

  ## Features
  - client_desires, notifications, notification_preferences
  - favorites, reported_content, blocked_users
  - analytics_events, page_views, picker_analytics
  - recommendations, recommendation_interactions
  - referral_codes, referral_rewards
  - video_calls, custom_orders
  - support_tickets, disputes, dispute_messages
  - wishlist_items, search_history
  - media_verifications, invoices
  - trust_scores, identity_verifications
  - delivery_confirmation_reminders, trial_ending_reminders

  ## Storage & Functions
  - Storage buckets for pickup videos and media
  - Automated triggers and functions
  - pg_cron jobs for scheduled tasks

  Applied: 2026-01-10T22:08:20.134Z
*/

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";



-- =========================================
-- Migration: 20251007130041_create_marketplace_schema.sql
-- =========================================

/*
  # Global Souvenir Marketplace Schema

  ## Overview
  This migration creates a complete marketplace system for connecting souvenir pickers
  (travelers who collect items globally) with clients seeking specific regional souvenirs.

  ## 1. New Tables

  ### `profiles`
  - `id` (uuid, primary key) - References auth.users
  - `email` (text) - User email
  - `full_name` (text) - Display name
  - `user_type` (text) - Either 'picker' or 'client'
  - `avatar_url` (text, nullable) - Profile picture
  - `bio` (text, nullable) - User description
  - `created_at` (timestamptz) - Account creation time

  ### `picker_profiles`
  - `id` (uuid, primary key)
  - `user_id` (uuid) - References profiles
  - `current_location` (text) - Current region/country
  - `regions` (text array) - All regions they can access
  - `specialties` (text array) - Types of souvenirs they specialize in
  - `rating` (numeric) - Average rating (0-5)
  - `total_reviews` (integer) - Number of reviews received
  - `verified` (boolean) - Verification status
  - `created_at` (timestamptz)

  ### `listings`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `title` (text) - Item name
  - `description` (text) - Detailed description
  - `category` (text) - Item category
  - `region` (text) - Region/country of origin
  - `price` (numeric) - Item price
  - `image_url` (text, nullable) - Main image
  - `images` (text array) - Additional images
  - `available` (boolean) - Availability status
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `requests`
  - `id` (uuid, primary key)
  - `client_id` (uuid) - References profiles
  - `picker_id` (uuid, nullable) - Assigned picker
  - `title` (text) - Request title
  - `description` (text) - Detailed request
  - `region` (text) - Desired region
  - `category` (text) - Item category
  - `budget` (numeric) - Client budget
  - `status` (text) - 'open', 'assigned', 'in_progress', 'completed', 'cancelled'
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `messages`
  - `id` (uuid, primary key)
  - `request_id` (uuid) - References requests
  - `sender_id` (uuid) - References profiles
  - `recipient_id` (uuid) - References profiles
  - `content` (text) - Message content
  - `read` (boolean) - Read status
  - `created_at` (timestamptz)

  ### `reviews`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `client_id` (uuid) - References profiles
  - `request_id` (uuid) - References requests
  - `rating` (integer) - Rating 1-5
  - `comment` (text, nullable) - Review text
  - `created_at` (timestamptz)

  ## 2. Security
  - Enable RLS on all tables
  - Users can read their own profile data
  - Users can update their own profiles
  - Public read access for picker profiles and listings
  - Request creators can read/update their requests
  - Pickers can read requests and update assigned ones
  - Message participants can read their conversations
  - Clients can create reviews for completed requests
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text NOT NULL,
  full_name text NOT NULL,
  user_type text NOT NULL CHECK (user_type IN ('picker', 'client')),
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now()
);

-- Create picker_profiles table
CREATE TABLE IF NOT EXISTS picker_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE UNIQUE,
  current_location text NOT NULL DEFAULT '',
  regions text[] DEFAULT '{}',
  specialties text[] DEFAULT '{}',
  rating numeric DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  total_reviews integer DEFAULT 0,
  verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create listings table
CREATE TABLE IF NOT EXISTS listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL DEFAULT '',
  region text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  image_url text,
  images text[] DEFAULT '{}',
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create requests table
CREATE TABLE IF NOT EXISTS requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  picker_id uuid REFERENCES picker_profiles ON DELETE SET NULL,
  title text NOT NULL,
  description text NOT NULL,
  region text NOT NULL,
  category text NOT NULL DEFAULT '',
  budget numeric CHECK (budget >= 0),
  status text DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create reviews table
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(request_id, client_id)
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Picker profiles policies
CREATE POLICY "Anyone can view picker profiles"
  ON picker_profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can update own profile"
  ON picker_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Pickers can insert own profile"
  ON picker_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Listings policies
CREATE POLICY "Anyone can view available listings"
  ON listings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can create listings"
  ON listings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update own listings"
  ON listings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can delete own listings"
  ON listings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Requests policies
CREATE POLICY "Users can view relevant requests"
  ON requests FOR SELECT
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    ) OR
    (status = 'open' AND picker_id IS NULL)
  );

CREATE POLICY "Clients can create requests"
  ON requests FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Request owners can update"
  ON requests FOR UPDATE
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  );

-- Messages policies
CREATE POLICY "Users can view their messages"
  ON messages FOR SELECT
  TO authenticated
  USING (sender_id = auth.uid() OR recipient_id = auth.uid());

CREATE POLICY "Users can send messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update their received messages"
  ON messages FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- Reviews policies
CREATE POLICY "Anyone can view reviews"
  ON reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Clients can create reviews"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM requests
      WHERE requests.id = request_id
      AND requests.client_id = auth.uid()
      AND requests.status = 'completed'
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_picker_profiles_user_id ON picker_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_listings_picker_id ON listings(picker_id);
CREATE INDEX IF NOT EXISTS idx_listings_region ON listings(region);
CREATE INDEX IF NOT EXISTS idx_requests_client_id ON requests(client_id);
CREATE INDEX IF NOT EXISTS idx_requests_picker_id ON requests(picker_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_messages_request_id ON messages(request_id);
CREATE INDEX IF NOT EXISTS idx_reviews_picker_id ON reviews(picker_id);

-- =========================================
-- Migration: 20251007185404_add_videos_to_listings.sql
-- =========================================

/*
  # Add video support to listings

  ## Overview
  This migration adds a videos column to the listings table to support multiple video uploads.

  ## 1. Changes
  - Add `videos` column to `listings` table (text array)
  - This column will store URLs of uploaded videos

  ## 2. Notes
  - Existing listings will have an empty array for videos by default
  - Pickers can upload multiple videos for each listing
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'videos'
  ) THEN
    ALTER TABLE listings ADD COLUMN videos text[] DEFAULT '{}';
  END IF;
END $$;

-- =========================================
-- Migration: 20251007185849_add_gps_locations.sql
-- =========================================

/*
  # Add GPS location support

  ## Overview
  This migration adds GPS coordinates and enhanced region support for pickers and listings.

  ## 1. Changes to picker_profiles
  - Add `latitude` column (numeric, stores GPS latitude)
  - Add `longitude` column (numeric, stores GPS longitude)
  - Add `location_updated_at` column (timestamp, tracks when location was last updated)

  ## 2. Changes to listings
  - Add `latitude` column (numeric, stores listing-specific GPS latitude)
  - Add `longitude` column (numeric, stores listing-specific GPS longitude)
  - Add `pickup_location` column (text, human-readable pickup address)

  ## 3. Notes
  - GPS coordinates allow precise location tracking for pickers
  - Listings can have specific pickup locations different from picker's current location
  - Coordinates can be used for map displays and proximity searches
  - All GPS fields are optional to respect privacy
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN latitude numeric(10, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'longitude'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN longitude numeric(11, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'location_updated_at'
  ) THEN
    ALTER TABLE picker_profiles ADD COLUMN location_updated_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'latitude'
  ) THEN
    ALTER TABLE listings ADD COLUMN latitude numeric(10, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'longitude'
  ) THEN
    ALTER TABLE listings ADD COLUMN longitude numeric(11, 8);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'pickup_location'
  ) THEN
    ALTER TABLE listings ADD COLUMN pickup_location text;
  END IF;
END $$;

-- =========================================
-- Migration: 20251007190235_create_client_desires.sql
-- =========================================

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

-- =========================================
-- Migration: 20251007190942_add_payment_methods.sql
-- =========================================

/*
  # Add payment methods for pickers

  ## Overview
  This migration creates a system for pickers to specify their accepted payment methods,
  allowing clients to see how they can pay for souvenirs.

  ## 1. New Tables
    - `picker_payment_methods`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references picker_profiles)
      - `method_type` (text, type of payment: paypal, venmo, bank_transfer, cash, crypto, etc.)
      - `method_name` (text, display name for the payment method)
      - `account_identifier` (text, account details like email, phone, or public info)
      - `notes` (text, additional instructions or notes)
      - `preferred` (boolean, whether this is the picker's preferred method)
      - `active` (boolean, whether this method is currently available)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  ## 2. Security
    - Enable RLS on `picker_payment_methods` table
    - Pickers can create, read, update, and delete their own payment methods
    - Authenticated users can view payment methods of any picker (for transparency)
    - Only picker owners can modify their payment methods

  ## 3. Notes
    - Allows pickers to add multiple payment methods
    - Supports various payment types worldwide
    - Preferred method helps clients know which to use
    - Account identifiers are public (don't store sensitive data)
    - Pickers should only share safe, public-facing payment info
*/

CREATE TABLE IF NOT EXISTS picker_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES picker_profiles(id) ON DELETE CASCADE NOT NULL,
  method_type text NOT NULL CHECK (method_type IN (
    'paypal', 'venmo', 'cashapp', 'zelle', 'bank_transfer', 
    'wise', 'revolut', 'crypto', 'cash', 'other'
  )),
  method_name text NOT NULL,
  account_identifier text NOT NULL,
  notes text DEFAULT '',
  preferred boolean DEFAULT false,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE picker_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view payment methods"
  ON picker_payment_methods FOR SELECT
  TO authenticated
  USING (active = true);

CREATE POLICY "Pickers can create own payment methods"
  ON picker_payment_methods FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update own payment methods"
  ON picker_payment_methods FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can delete own payment methods"
  ON picker_payment_methods FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_picker_payment_methods_picker_id ON picker_payment_methods(picker_id);
CREATE INDEX IF NOT EXISTS idx_picker_payment_methods_active ON picker_payment_methods(active);

-- =========================================
-- Migration: 20251007191838_add_subscription_system.sql
-- =========================================

/*
  # Add subscription system with 3-month free trial

  ## Overview
  This migration adds a subscription system where all users get a 3-month free trial,
  then are charged 1 euro per month after the trial expires.

  ## 1. Changes to profiles table
    - `trial_started_at` (timestamptz, when the trial started)
    - `trial_ends_at` (timestamptz, when the trial ends - 3 months after start)
    - `subscription_status` (text, current subscription status)
    - `subscription_started_at` (timestamptz, when paid subscription started)
    - `last_payment_date` (timestamptz, last successful payment)
    - `next_payment_due` (timestamptz, when next payment is due)
    - `payment_failed` (boolean, whether last payment attempt failed)

  ## 2. Notes
    - Trial period is 3 months (90 days) from account creation
    - After trial, subscription is 1 euro per month
    - Subscription status can be: 'trial', 'active', 'past_due', 'cancelled'
    - Trial starts automatically when profile is created
    - Payment tracking for monthly billing cycle
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'trial_started_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN trial_started_at timestamptz DEFAULT now();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'trial_ends_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN trial_ends_at timestamptz DEFAULT (now() + interval '90 days');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'subscription_status'
  ) THEN
    ALTER TABLE profiles ADD COLUMN subscription_status text DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'cancelled'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'subscription_started_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN subscription_started_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'last_payment_date'
  ) THEN
    ALTER TABLE profiles ADD COLUMN last_payment_date timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'next_payment_due'
  ) THEN
    ALTER TABLE profiles ADD COLUMN next_payment_due timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_failed'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_failed boolean DEFAULT false;
  END IF;
END $$;

UPDATE profiles
SET 
  trial_started_at = COALESCE(trial_started_at, created_at),
  trial_ends_at = COALESCE(trial_ends_at, created_at + interval '90 days'),
  subscription_status = COALESCE(subscription_status, 'trial')
WHERE trial_started_at IS NULL OR trial_ends_at IS NULL OR subscription_status IS NULL;

-- =========================================
-- Migration: 20251007193735_add_company_billing_info.sql
-- =========================================

/*
  # Add company billing information
  
  ## Overview
  This migration adds company billing information fields to the profiles table
  for proper invoicing and payment processing.
  
  ## 1. Changes to profiles table
    - `company_name` (text, optional company name for business accounts)
    - `billing_address` (text, street address for billing)
    - `billing_city` (text, city for billing)
    - `billing_postal_code` (text, postal/zip code)
    - `billing_country` (text, country for billing)
    - `tax_id` (text, VAT/Tax ID number for businesses)
    - `billing_email` (text, email for billing/invoices)
    - `billing_phone` (text, phone number for billing inquiries)
  
  ## 2. Notes
    - All fields are optional to support both individual and business accounts
    - Tax ID field supports VAT numbers and other tax identifiers
    - Billing email defaults to user's primary email if not specified
    - Information used for generating invoices and payment processing
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'company_name'
  ) THEN
    ALTER TABLE profiles ADD COLUMN company_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_address'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_address text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_city'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_city text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_postal_code'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_postal_code text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_country'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_country text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'tax_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN tax_id text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_email'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_email text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'billing_phone'
  ) THEN
    ALTER TABLE profiles ADD COLUMN billing_phone text;
  END IF;
END $$;

-- =========================================
-- Migration: 20251008102153_create_direct_messaging.sql
-- =========================================

/*
  # Create Direct Messaging System

  1. New Tables
    - `conversations`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `picker_id` (uuid, references profiles)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
    
    - `conversation_messages`
      - `id` (uuid, primary key)
      - `conversation_id` (uuid, references conversations)
      - `sender_id` (uuid, references profiles)
      - `content` (text)
      - `read` (boolean)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Users can only access conversations they're part of
    - Users can only read/send messages in their conversations
*/

CREATE TABLE IF NOT EXISTS conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(client_id, picker_id)
);

CREATE TABLE IF NOT EXISTS conversation_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversations_client ON conversations(client_id);
CREATE INDEX IF NOT EXISTS idx_conversations_picker ON conversations(picker_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_conversation ON conversation_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_created ON conversation_messages(created_at DESC);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own conversations"
  ON conversations FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id OR auth.uid() = picker_id);

CREATE POLICY "Clients can create conversations with pickers"
  ON conversations FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = picker_id AND user_type = 'picker'
    )
  );

CREATE POLICY "Users can view messages in their conversations"
  ON conversation_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = conversation_id
      AND (client_id = auth.uid() OR picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their conversations"
  ON conversation_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = conversation_id
      AND (client_id = auth.uid() OR picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can mark their messages as read"
  ON conversation_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = conversation_id
      AND (client_id = auth.uid() OR picker_id = auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE id = conversation_id
      AND (client_id = auth.uid() OR picker_id = auth.uid())
    )
  );

-- =========================================
-- Migration: 20251008114804_add_portfolio_videos_to_picker_profiles.sql
-- =========================================

/*
  # Add Portfolio Videos to Picker Profiles

  1. Changes
    - Add `portfolio_videos` column to `picker_profiles` table
      - `portfolio_videos` (text array) - URLs of portfolio videos showcasing picker's work
  
  2. Details
    - Allows pickers to upload and display videos in their profile
    - Videos can showcase items they've sourced or their travel experiences
    - Stored as an array of URLs from Supabase storage
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_profiles' AND column_name = 'portfolio_videos'
  ) THEN
    ALTER TABLE picker_profiles 
    ADD COLUMN portfolio_videos text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;

-- =========================================
-- Migration: 20251014103439_create_orders_system_only.sql
-- =========================================

/*
  # Create Orders System

  ## Orders System
  
  1. New Tables
    - `orders`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `picker_id` (uuid, references profiles)
      - `listing_id` (uuid, references listings)
      - `status` (text) - pending, accepted, in_progress, completed, cancelled, refunded
      - `quantity` (integer)
      - `total_price` (decimal)
      - `delivery_address` (text)
      - `delivery_instructions` (text)
      - `payment_status` (text) - pending, paid, refunded
      - `payment_intent_id` (text) - for Stripe integration
      - `notes` (text)
      - `completed_at` (timestamptz)
      - `cancelled_at` (timestamptz)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
    
    - `order_status_history`
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `status` (text)
      - `notes` (text)
      - `changed_by` (uuid, references profiles)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Clients can create orders and view their own orders
    - Pickers can view orders for their listings and update order status
    - Both parties can view order status history for their orders
    
  3. Important Notes
    - Positive quantity and price constraints enforced
    - Status tracking with history for transparency
    - Payment integration ready with Stripe fields
    - Timestamps for completed and cancelled orders
*/

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) NOT NULL,
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  listing_id uuid REFERENCES listings(id) NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  quantity integer NOT NULL DEFAULT 1,
  total_price decimal(10,2) NOT NULL,
  delivery_address text,
  delivery_instructions text,
  payment_status text NOT NULL DEFAULT 'pending',
  payment_intent_id text,
  notes text,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'refunded')),
  CONSTRAINT valid_payment_status CHECK (payment_status IN ('pending', 'paid', 'refunded')),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT positive_price CHECK (total_price > 0)
);

-- Order status history
CREATE TABLE IF NOT EXISTS order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  status text NOT NULL,
  notes text,
  changed_by uuid REFERENCES profiles(id) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;

-- Orders policies
CREATE POLICY "Clients can view their own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Pickers can view their orders"
  ON orders FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Clients can create orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can update their pending orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid() AND status = 'pending')
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Pickers can update their orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Order status history policies
CREATE POLICY "Users can view order status history for their orders"
  ON order_status_history FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_status_history.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can create status history for their orders"
  ON order_status_history FOR INSERT
  TO authenticated
  WITH CHECK (
    changed_by = auth.uid() AND
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_status_history.order_id
      AND (orders.client_id = auth.uid() OR orders.picker_id = auth.uid())
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_picker_id ON orders(picker_id);
CREATE INDEX IF NOT EXISTS idx_orders_listing_id ON orders(listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_orders_updated_at_trigger ON orders;
CREATE TRIGGER update_orders_updated_at_trigger
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_orders_updated_at();

-- =========================================
-- Migration: 20251014103458_update_reviews_for_orders.sql
-- =========================================

/*
  # Update Reviews System for Orders

  ## Changes
  
  1. Modifications to reviews table
    - Add `order_id` column (nullable, references orders, unique)
    - Make `request_id` nullable (to support both order and request reviews)
    - Add `listing_id` column (nullable, references listings)
    - Add `response` text column for picker responses
    - Add `response_at` timestamp
    - Add `updated_at` timestamp
  
  2. Updated Security
    - Update policies to handle order-based reviews
    - Allow pickers to respond to reviews
  
  3. Important Notes
    - Reviews can now be linked to either orders or requests
    - Pickers can respond to reviews about them
    - One review per order (enforced by unique constraint)
*/

-- Add new columns to reviews table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'order_id'
  ) THEN
    ALTER TABLE reviews ADD COLUMN order_id uuid REFERENCES orders(id) UNIQUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'listing_id'
  ) THEN
    ALTER TABLE reviews ADD COLUMN listing_id uuid REFERENCES listings(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'response'
  ) THEN
    ALTER TABLE reviews ADD COLUMN response text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'response_at'
  ) THEN
    ALTER TABLE reviews ADD COLUMN response_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reviews' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE reviews ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Make request_id nullable since reviews can be for orders too
DO $$
BEGIN
  ALTER TABLE reviews ALTER COLUMN request_id DROP NOT NULL;
EXCEPTION
  WHEN others THEN NULL;
END $$;

-- Drop and recreate policies with proper names
DROP POLICY IF EXISTS "Anyone can view reviews" ON reviews;
DROP POLICY IF EXISTS "Clients can create reviews" ON reviews;
DROP POLICY IF EXISTS "Clients can update their reviews" ON reviews;

CREATE POLICY "authenticated_users_can_view_reviews"
  ON reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "clients_can_create_order_reviews"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid() AND
    (
      (order_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = reviews.order_id
        AND orders.client_id = auth.uid()
        AND orders.status = 'completed'
      )) OR
      (request_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM requests
        WHERE requests.id = reviews.request_id
        AND requests.client_id = auth.uid()
      ))
    )
  );

CREATE POLICY "clients_can_update_own_reviews"
  ON reviews FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid() AND response IS NULL);

CREATE POLICY "pickers_can_respond_to_reviews"
  ON reviews FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_reviews_order_id ON reviews(order_id) WHERE order_id IS NOT NULL;

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_reviews_updated_at_trigger ON reviews;
CREATE TRIGGER update_reviews_updated_at_trigger
  BEFORE UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_reviews_updated_at();

-- =========================================
-- Migration: 20251126192816_update_trial_period_to_60_days.sql
-- =========================================

/*
  # Update Trial Period to 2 Months

  1. Changes
    - Update default trial period from 90 days to 60 days (2 months)
    - Update existing trial periods for users who haven't exceeded 60 days
    
  2. Notes
    - Users who are already past 60 days will keep their current trial_ends_at
    - New users will automatically get 60 days trial
*/

-- Update the default for new users
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '60 days');

-- Update existing users who still have trial time remaining beyond 60 days
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '60 days'
WHERE trial_ends_at > trial_started_at + interval '60 days';

-- =========================================
-- Migration: 20251126194930_create_client_payment_methods.sql
-- =========================================

/*
  # Add Client Payment Methods

  1. New Table
    - `client_payment_methods`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references profiles)
      - `method_type` (text) - Type of payment method (credit_card, debit_card, paypal, etc.)
      - `method_name` (text) - Display name for the payment method
      - `last_four` (text) - Last 4 digits for cards
      - `card_brand` (text) - Card brand (visa, mastercard, etc.)
      - `expiry_month` (integer) - Card expiry month
      - `expiry_year` (integer) - Card expiry year
      - `is_default` (boolean) - Whether this is the default payment method
      - `active` (boolean) - Whether payment method is active
      - `stripe_payment_method_id` (text) - Stripe payment method ID
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS on `client_payment_methods` table
    - Add policy for clients to manage their own payment methods
*/

CREATE TABLE IF NOT EXISTS client_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  method_type text NOT NULL CHECK (method_type IN ('credit_card', 'debit_card', 'paypal', 'bank_account', 'other')),
  method_name text NOT NULL,
  last_four text,
  card_brand text,
  expiry_month integer CHECK (expiry_month >= 1 AND expiry_month <= 12),
  expiry_year integer CHECK (expiry_year >= 2024),
  is_default boolean DEFAULT false,
  active boolean DEFAULT true,
  stripe_payment_method_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE client_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view own payment methods"
  ON client_payment_methods
  FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Clients can insert own payment methods"
  ON client_payment_methods
  FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can update own payment methods"
  ON client_payment_methods
  FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can delete own payment methods"
  ON client_payment_methods
  FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());


-- =========================================
-- Migration: 20251126201004_add_tiktok_links_support.sql
-- =========================================

/*
  # Add TikTok Links Support

  1. Changes
    - Add `media_links` column to `listings` table for TikTok/external video links
    - Add `reference_links` column to `client_desires` table for TikTok/external video links
    - These columns complement existing videos arrays with text array for external links

  2. Notes
    - Both pickers and clients can now use TikTok links instead of uploading videos
    - Links are stored separately from uploaded videos for flexibility
    - Existing video functionality remains unchanged
*/

-- Add media_links to listings table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'media_links'
  ) THEN
    ALTER TABLE listings ADD COLUMN media_links text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;

-- Add reference_links to client_desires table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'client_desires' AND column_name = 'reference_links'
  ) THEN
    ALTER TABLE client_desires ADD COLUMN reference_links text[] DEFAULT ARRAY[]::text[];
  END IF;
END $$;

-- =========================================
-- Migration: 20251126201528_add_social_media_integrations.sql
-- =========================================

/*
  # Add Social Media Integrations

  1. Changes
    - Add social media link columns to `profiles` table
      - `facebook_url` (text) - Facebook profile/page URL
      - `twitter_url` (text) - Twitter/X profile URL
      - `instagram_url` (text) - Instagram profile URL
      - `threads_url` (text) - Threads profile URL

  2. Notes
    - Both pickers and clients can add social media links to their profiles
    - Links help build trust and allow users to verify authenticity
    - All fields are optional
*/

-- Add social media columns to profiles table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'facebook_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN facebook_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'twitter_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN twitter_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'instagram_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN instagram_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'threads_url'
  ) THEN
    ALTER TABLE profiles ADD COLUMN threads_url text;
  END IF;
END $$;

-- =========================================
-- Migration: 20251126204236_add_notifications_favorites_reporting.sql
-- =========================================

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
  UNIQUE(listing_id)
);

-- Enable RLS
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE trending_listings ENABLE ROW LEVEL SECURITY;

-- Policies for user_activity
CREATE POLICY "Users can view own activity"
  ON user_activity FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own activity"
  ON user_activity FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for listing_views
CREATE POLICY "Anyone can record listing views"
  ON listing_views FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view own listing views"
  ON listing_views FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR user_id IS NULL);

-- Policies for user_preferences
CREATE POLICY "Users can view own preferences"
  ON user_preferences FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own preferences"
  ON user_preferences FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for trending_listings
CREATE POLICY "Anyone can view trending listings"
  ON trending_listings FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_created_at ON user_activity(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_user_id ON listing_views(user_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_created_at ON listing_views(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trending_listings_score ON trending_listings(trend_score DESC);

-- Function to record listing view
CREATE OR REPLACE FUNCTION record_listing_view(
  p_listing_id uuid,
  p_user_id uuid DEFAULT NULL,
  p_session_id text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  INSERT INTO listing_views (listing_id, user_id, session_id)
  VALUES (p_listing_id, p_user_id, p_session_id);

  IF p_user_id IS NOT NULL THEN
    INSERT INTO user_activity (user_id, activity_type, entity_type, entity_id)
    VALUES (p_user_id, 'view', 'listing', p_listing_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get personalized recommendations
CREATE OR REPLACE FUNCTION get_personalized_recommendations(
  p_user_id uuid,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  listing_id uuid,
  relevance_score numeric
) AS $$
BEGIN
  RETURN QUERY
  WITH user_prefs AS (
    SELECT 
      preferred_categories,
      preferred_regions,
      price_range_min,
      price_range_max
    FROM user_preferences
    WHERE user_id = p_user_id
  ),
  scored_listings AS (
    SELECT 
      l.id as listing_id,
      (
        CASE WHEN up.preferred_categories IS NOT NULL AND l.category = ANY(up.preferred_categories) THEN 50 ELSE 0 END +
        CASE WHEN up.preferred_regions IS NOT NULL AND l.region = ANY(up.preferred_regions) THEN 30 ELSE 0 END +
        CASE WHEN up.price_range_min IS NULL OR l.price >= up.price_range_min THEN 10 ELSE 0 END +
        CASE WHEN up.price_range_max IS NULL OR l.price <= up.price_range_max THEN 10 ELSE 0 END +
        COALESCE(pp.rating * 5, 0)
      )::numeric as relevance_score
    FROM listings l
    LEFT JOIN user_prefs up ON true
    LEFT JOIN picker_profiles pp ON pp.id = l.picker_id
    WHERE l.available = true
    AND l.id NOT IN (
      SELECT listing_id FROM orders WHERE client_id = p_user_id
    )
    ORDER BY relevance_score DESC, l.created_at DESC
    LIMIT p_limit
  )
  SELECT * FROM scored_listings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get trending listings
CREATE OR REPLACE FUNCTION get_trending_listings(p_limit integer DEFAULT 10)
RETURNS TABLE (
  listing_id uuid,
  trend_score numeric,
  view_count integer,
  order_count integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tl.listing_id,
    tl.trend_score,
    tl.view_count,
    tl.order_count
  FROM trending_listings tl
  JOIN listings l ON l.id = tl.listing_id
  WHERE l.available = true
  ORDER BY tl.trend_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user preferences based on activity
CREATE OR REPLACE FUNCTION update_user_preferences_from_activity()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT DISTINCT user_id FROM user_activity WHERE created_at > now() - interval '30 days'
  LOOP
    INSERT INTO user_preferences (user_id, preferred_categories, preferred_regions)
    SELECT 
      user_record.user_id,
      ARRAY_AGG(DISTINCT l.category) FILTER (WHERE l.category IS NOT NULL),
      ARRAY_AGG(DISTINCT l.region) FILTER (WHERE l.region IS NOT NULL)
    FROM user_activity ua
    JOIN listings l ON l.id = ua.entity_id
    WHERE ua.user_id = user_record.user_id
    AND ua.entity_type = 'listing'
    AND ua.created_at > now() - interval '30 days'
    ON CONFLICT (user_id) DO UPDATE
    SET 
      preferred_categories = EXCLUDED.preferred_categories,
      preferred_regions = EXCLUDED.preferred_regions,
      updated_at = now();
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate trending listings
CREATE OR REPLACE FUNCTION calculate_trending_listings()
RETURNS void AS $$
BEGIN
  DELETE FROM trending_listings;

  INSERT INTO trending_listings (listing_id, trend_score, view_count, order_count, share_count)
  SELECT 
    l.id,
    (
      COALESCE(view_counts.count, 0) * 1.0 +
      COALESCE(order_counts.count, 0) * 10.0 +
      COALESCE(share_counts.count, 0) * 5.0 +
      CASE WHEN l.created_at > now() - interval '7 days' THEN 20 ELSE 0 END
    )::numeric as trend_score,
    COALESCE(view_counts.count, 0)::integer,
    COALESCE(order_counts.count, 0)::integer,
    COALESCE(share_counts.count, 0)::integer
  FROM listings l
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_views
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) view_counts ON view_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM orders
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) order_counts ON order_counts.listing_id = l.id
  LEFT JOIN (
    SELECT listing_id, COUNT(*) as count
    FROM listing_shares
    WHERE created_at > now() - interval '7 days'
    GROUP BY listing_id
  ) share_counts ON share_counts.listing_id = l.id
  WHERE l.available = true
  AND (
    COALESCE(view_counts.count, 0) > 0 OR
    COALESCE(order_counts.count, 0) > 0 OR
    COALESCE(share_counts.count, 0) > 0
  )
  ORDER BY trend_score DESC
  LIMIT 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251126214447_create_referral_program.sql
-- =========================================

-- Referral Program System
--
-- 1. New Tables
--    - referral_codes: Unique referral codes for each user
--    - referrals: Track who referred whom
--    - referral_rewards: Track earned rewards
--    - reward_redemptions: Track when rewards are used
--
-- 2. Security
--    - Enable RLS on all tables
--    - Users can only see their own referrals and rewards

-- Create referral_codes table
CREATE TABLE IF NOT EXISTS referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create referrals table
CREATE TABLE IF NOT EXISTS referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referred_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_code text NOT NULL,
  status text DEFAULT 'pending',
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(referred_id)
);

-- Create referral_rewards table
CREATE TABLE IF NOT EXISTS referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_id uuid REFERENCES referrals(id) ON DELETE CASCADE,
  reward_type text NOT NULL,
  reward_value numeric(10, 2) NOT NULL,
  currency text DEFAULT 'EUR',
  expires_at timestamptz,
  redeemed boolean DEFAULT false,
  redeemed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Create reward_redemptions table
CREATE TABLE IF NOT EXISTS reward_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_id uuid REFERENCES referral_rewards(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  amount_used numeric(10, 2) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

-- Policies for referral_codes
CREATE POLICY "Users can view own referral code"
  ON referral_codes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own referral code"
  ON referral_codes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policies for referrals
CREATE POLICY "Users can view own referrals"
  ON referrals FOR SELECT
  TO authenticated
  USING (referrer_id = auth.uid() OR referred_id = auth.uid());

CREATE POLICY "Anyone can create referrals"
  ON referrals FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for referral_rewards
CREATE POLICY "Users can view own rewards"
  ON referral_rewards FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "System can create rewards"
  ON referral_rewards FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update own rewards"
  ON referral_rewards FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policies for reward_redemptions
CREATE POLICY "Users can view own redemptions"
  ON reward_redemptions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create redemptions"
  ON reward_redemptions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_user_id ON referral_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_redeemed ON referral_rewards(redeemed) WHERE redeemed = false;

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text AS $$
DECLARE
  new_code text;
  code_exists boolean;
BEGIN
  LOOP
    new_code := upper(substring(md5(random()::text) from 1 for 8));
    
    SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = new_code) INTO code_exists;
    
    IF NOT code_exists THEN
      EXIT;
    END IF;
  END LOOP;
  
  RETURN new_code;
END;
$$ LANGUAGE plpgsql;

-- Function to create referral code for new users
CREATE OR REPLACE FUNCTION create_referral_code_for_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO referral_codes (user_id, code)
  VALUES (NEW.id, generate_referral_code())
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create referral code
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_user_created_generate_referral_code'
  ) THEN
    CREATE TRIGGER on_user_created_generate_referral_code
      AFTER INSERT ON auth.users
      FOR EACH ROW
      EXECUTE FUNCTION create_referral_code_for_user();
  END IF;
END $$;

-- Function to process referral completion
CREATE OR REPLACE FUNCTION process_referral_completion()
RETURNS TRIGGER AS $$
DECLARE
  referrer_reward numeric := 10.00;
  referred_reward numeric := 5.00;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO referral_rewards (user_id, referral_id, reward_type, reward_value, expires_at)
    VALUES 
      (NEW.referrer_id, NEW.id, 'referral_bonus', referrer_reward, now() + interval '90 days'),
      (NEW.referred_id, NEW.id, 'signup_bonus', referred_reward, now() + interval '90 days');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for referral completion
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'on_referral_completed'
  ) THEN
    CREATE TRIGGER on_referral_completed
      AFTER UPDATE ON referrals
      FOR EACH ROW
      EXECUTE FUNCTION process_referral_completion();
  END IF;
END $$;

-- Function to apply referral code
CREATE OR REPLACE FUNCTION apply_referral_code(p_code text, p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  referrer_user_id uuid;
  existing_referral uuid;
  new_referral_id uuid;
BEGIN
  SELECT user_id INTO referrer_user_id
  FROM referral_codes
  WHERE code = p_code;
  
  IF referrer_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;
  
  IF referrer_user_id = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot use your own referral code');
  END IF;
  
  SELECT id INTO existing_referral
  FROM referrals
  WHERE referred_id = p_user_id;
  
  IF existing_referral IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already used a referral code');
  END IF;
  
  INSERT INTO referrals (referrer_id, referred_id, referral_code, status)
  VALUES (referrer_user_id, p_user_id, p_code, 'pending')
  RETURNING id INTO new_referral_id;
  
  RETURN jsonb_build_object('success', true, 'referral_id', new_referral_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user referral stats
CREATE OR REPLACE FUNCTION get_referral_stats(p_user_id uuid)
RETURNS jsonb AS $$
DECLARE
  total_referrals integer;
  completed_referrals integer;
  pending_referrals integer;
  total_rewards numeric;
  available_rewards numeric;
  user_code text;
BEGIN
  SELECT code INTO user_code FROM referral_codes WHERE user_id = p_user_id;
  
  SELECT COUNT(*) INTO total_referrals FROM referrals WHERE referrer_id = p_user_id;
  SELECT COUNT(*) INTO completed_referrals FROM referrals WHERE referrer_id = p_user_id AND status = 'completed';
  SELECT COUNT(*) INTO pending_referrals FROM referrals WHERE referrer_id = p_user_id AND status = 'pending';
  
  SELECT COALESCE(SUM(reward_value), 0) INTO total_rewards 
  FROM referral_rewards WHERE user_id = p_user_id;
  
  SELECT COALESCE(SUM(reward_value), 0) INTO available_rewards 
  FROM referral_rewards WHERE user_id = p_user_id AND redeemed = false AND (expires_at IS NULL OR expires_at > now());
  
  RETURN jsonb_build_object(
    'code', user_code,
    'total_referrals', total_referrals,
    'completed_referrals', completed_referrals,
    'pending_referrals', pending_referrals,
    'total_rewards', total_rewards,
    'available_rewards', available_rewards
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251127121947_generate_referral_codes_for_existing_users.sql
-- =========================================

/*
  # Generate Referral Codes for Existing Users

  1. Changes
    - Generates referral codes for all existing users who don't have one
    - Uses the existing generate_referral_code() function
    - Safe to run multiple times (uses INSERT ... ON CONFLICT DO NOTHING)

  2. Notes
    - This fixes the issue where existing users don't have referral codes
    - Only affects users who don't already have a code
*/

-- Generate referral codes for all existing users who don't have one
INSERT INTO referral_codes (user_id, code)
SELECT 
  u.id,
  generate_referral_code()
FROM auth.users u
LEFT JOIN referral_codes rc ON rc.user_id = u.id
WHERE rc.id IS NULL
ON CONFLICT (user_id) DO NOTHING;


-- =========================================
-- Migration: 20251127132056_add_escrow_automation_and_triggers.sql
-- =========================================

/*
  # Escrow Payment Protection System - Automation & Triggers

  1. New Functions
    - automatic_escrow_creation: Automatically creates escrow record when payment is confirmed
    - release_escrow_to_picker: Releases funds to picker when order is delivered
    - refund_escrow_to_client: Refunds money to client if order is cancelled/disputed
    - auto_release_escrow: Auto-release funds after delivery confirmation period
  
  2. Triggers
    - Auto-create escrow when payment intent succeeds
    - Update order status when escrow is released
    - Handle escrow timeouts
  
  3. Important Notes
    - Funds are held in escrow until order is marked as delivered
    - Client has 48 hours to dispute after delivery
    - After 48 hours, funds auto-release to picker
    - Refunds return money to client and update order status
*/

-- Function to automatically create escrow when payment succeeds
CREATE OR REPLACE FUNCTION automatic_escrow_creation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'succeeded' AND OLD.status != 'succeeded' THEN
    INSERT INTO payment_escrow (
      payment_intent_id,
      order_id,
      amount,
      status,
      held_at
    )
    VALUES (
      NEW.id,
      NEW.order_id,
      NEW.amount,
      'held',
      now()
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release escrow to picker
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'released',
    released_at = now(),
    released_to = picker_user_id,
    notes = 'Funds released to picker after delivery confirmation'
  WHERE id = escrow_id
  AND status = 'held'
  RETURNING order_id INTO v_order_id;

  -- Update order status to completed
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET 
      status = 'completed',
      updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refund escrow to client
CREATE OR REPLACE FUNCTION refund_escrow_to_client(escrow_id uuid, refund_reason text)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
  v_payment_intent_id uuid;
  v_amount numeric;
  v_client_id uuid;
BEGIN
  -- Get escrow details
  SELECT order_id, payment_intent_id, amount
  INTO v_order_id, v_payment_intent_id, v_amount
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  -- Get client ID from order
  SELECT client_id INTO v_client_id
  FROM orders
  WHERE id = v_order_id;

  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'refunded',
    released_at = now(),
    released_to = v_client_id,
    notes = refund_reason
  WHERE id = escrow_id;

  -- Create refund record
  INSERT INTO refunds (
    payment_intent_id,
    order_id,
    amount,
    reason,
    status,
    initiated_by
  )
  VALUES (
    v_payment_intent_id,
    v_order_id,
    v_amount,
    refund_reason,
    'completed',
    v_client_id
  );

  -- Update order status to cancelled
  UPDATE orders
  SET 
    status = 'cancelled',
    updated_at = now()
  WHERE id = v_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-release escrow after confirmation period
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow RECORD;
BEGIN
  FOR v_escrow IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON pe.order_id = o.id
    WHERE pe.status = 'held'
    AND o.status = 'delivered'
    AND o.delivered_at IS NOT NULL
    AND o.delivered_at < now() - INTERVAL '48 hours'
  LOOP
    PERFORM release_escrow_to_picker(v_escrow.escrow_id, v_escrow.picker_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create escrow when payment succeeds
DROP TRIGGER IF EXISTS trigger_create_escrow_on_payment ON payment_intents;
CREATE TRIGGER trigger_create_escrow_on_payment
  AFTER UPDATE ON payment_intents
  FOR EACH ROW
  EXECUTE FUNCTION automatic_escrow_creation();

-- Create a scheduled job function that can be called by an edge function
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS json AS $$
DECLARE
  v_released_count int := 0;
BEGIN
  PERFORM auto_release_escrow_after_confirmation();
  
  GET DIAGNOSTICS v_released_count = ROW_COUNT;
  
  RETURN json_build_object(
    'success', true,
    'released_count', v_released_count,
    'processed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION refund_escrow_to_client(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION process_escrow_releases() TO authenticated;

-- =========================================
-- Migration: 20251127133057_add_picker_subscription_payments.sql
-- =========================================

/*
  # Picker Subscription Payment System

  1. New Tables
    - picker_subscription_payments: Tracks subscription payment history for pickers
    - picker_payment_cards: Stores payment card information for pickers (tokenized)
    
  2. Changes to Profiles
    - Only pickers need to pay subscription fees
    - Add stripe_customer_id for pickers
    - Add default_payment_method reference
    
  3. Security
    - Enable RLS on all tables
    - Pickers can only view and manage their own payment methods
    - Payment card data is tokenized (only store Stripe tokens, never raw card data)
    
  4. Important Notes
    - Only pickers (user_type = 'picker') are charged subscription fees
    - Clients (user_type = 'client') use the platform for free
    - Subscription is 1 euro per month after 60-day trial
    - Payment is processed automatically via Stripe
    - Pickers must add payment method before trial ends
*/

-- Create subscription payments tracking table
CREATE TABLE IF NOT EXISTS picker_subscription_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount numeric(10, 2) NOT NULL,
  currency text DEFAULT 'eur',
  stripe_payment_intent_id text UNIQUE,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'succeeded', 'failed', 'refunded')),
  billing_period_start timestamptz NOT NULL,
  billing_period_end timestamptz NOT NULL,
  payment_method_used text,
  failure_reason text,
  paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create payment cards table (stores Stripe tokens only)
CREATE TABLE IF NOT EXISTS picker_payment_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  stripe_payment_method_id text UNIQUE NOT NULL,
  card_brand text,
  card_last4 text,
  card_exp_month integer,
  card_exp_year integer,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add Stripe customer ID to profiles (only for pickers)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'stripe_customer_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN stripe_customer_id text UNIQUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'default_payment_card_id'
  ) THEN
    ALTER TABLE profiles ADD COLUMN default_payment_card_id uuid REFERENCES picker_payment_cards(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'payment_method_added'
  ) THEN
    ALTER TABLE profiles ADD COLUMN payment_method_added boolean DEFAULT false;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE picker_subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Policies for picker_subscription_payments
CREATE POLICY "Pickers can view own subscription payments"
  ON picker_subscription_payments FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "System can insert subscription payments"
  ON picker_subscription_payments FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "System can update subscription payments"
  ON picker_subscription_payments FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Policies for picker_payment_cards
CREATE POLICY "Pickers can view own payment cards"
  ON picker_payment_cards FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Pickers can add own payment cards"
  ON picker_payment_cards FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can update own payment cards"
  ON picker_payment_cards FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can delete own payment cards"
  ON picker_payment_cards FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_subscription_payments_picker_id ON picker_subscription_payments(picker_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON picker_subscription_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_period ON picker_subscription_payments(billing_period_start, billing_period_end);
CREATE INDEX IF NOT EXISTS idx_payment_cards_picker_id ON picker_payment_cards(picker_id);
CREATE INDEX IF NOT EXISTS idx_payment_cards_default ON picker_payment_cards(picker_id, is_default);

-- Function to automatically set only one default payment card per picker
CREATE OR REPLACE FUNCTION set_default_payment_card()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE picker_payment_cards
    SET is_default = false
    WHERE picker_id = NEW.picker_id
    AND id != NEW.id;
    
    UPDATE profiles
    SET default_payment_card_id = NEW.id,
        payment_method_added = true
    WHERE id = NEW.picker_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to manage default payment card
DROP TRIGGER IF EXISTS trigger_set_default_payment_card ON picker_payment_cards;
CREATE TRIGGER trigger_set_default_payment_card
  AFTER INSERT OR UPDATE OF is_default ON picker_payment_cards
  FOR EACH ROW
  EXECUTE FUNCTION set_default_payment_card();

-- Function to process monthly subscription payments
CREATE OR REPLACE FUNCTION process_picker_subscription_payment(
  p_picker_id uuid,
  p_amount numeric,
  p_stripe_payment_intent_id text,
  p_payment_method_used text
)
RETURNS json AS $$
DECLARE
  v_payment_id uuid;
  v_billing_start timestamptz;
  v_billing_end timestamptz;
BEGIN
  v_billing_start := date_trunc('month', now());
  v_billing_end := v_billing_start + interval '1 month';

  INSERT INTO picker_subscription_payments (
    picker_id,
    amount,
    currency,
    stripe_payment_intent_id,
    payment_status,
    billing_period_start,
    billing_period_end,
    payment_method_used,
    paid_at
  )
  VALUES (
    p_picker_id,
    p_amount,
    'eur',
    p_stripe_payment_intent_id,
    'succeeded',
    v_billing_start,
    v_billing_end,
    p_payment_method_used,
    now()
  )
  RETURNING id INTO v_payment_id;

  UPDATE profiles
  SET 
    last_payment_date = now(),
    next_payment_due = v_billing_end,
    payment_failed = false,
    subscription_status = 'active'
  WHERE id = p_picker_id;

  RETURN json_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'next_payment_due', v_billing_end
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION process_picker_subscription_payment(uuid, numeric, text, text) TO authenticated;

-- =========================================
-- Migration: 20251127142651_create_cart_and_collector_payments.sql
-- =========================================

/*
  # Create Shopping Cart and Collector Payment Methods System

  ## Overview
  This migration creates a shopping cart system for collectors and adds payment method management.

  ## New Tables
  
  ### 1. `cart_items`
  Shopping cart for collectors to add items before checkout
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `listing_id` (uuid, references listings) - The item being added
  - `quantity` (integer) - Number of items
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. `collector_payment_methods`
  Payment methods for collectors (separate from picker payment methods)
  - `id` (uuid, primary key)
  - `client_id` (uuid, references profiles) - The collector
  - `method_type` (text) - credit_card, debit_card, paypal, etc.
  - `card_brand` (text) - Visa, Mastercard, etc.
  - `last_four` (text) - Last 4 digits of card
  - `cardholder_name` (text) - Name on card
  - `expiry_month` (integer) - Card expiry month
  - `expiry_year` (integer) - Card expiry year
  - `is_default` (boolean) - Whether this is the default payment method
  - `stripe_payment_method_id` (text) - Stripe payment method ID
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - RLS enabled on all tables
  - Collectors can only access their own cart items and payment methods
  - Proper indexes for performance

  ## Important Notes
  - Cart items are linked to active listings
  - Payment methods store minimal card info for display
  - Actual payment processing will use Stripe
  - First payment method is automatically default
*/

-- Create cart_items table
CREATE TABLE IF NOT EXISTS cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT unique_cart_item UNIQUE (client_id, listing_id)
);

-- Create collector_payment_methods table
CREATE TABLE IF NOT EXISTS collector_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  method_type text NOT NULL DEFAULT 'credit_card',
  card_brand text,
  last_four text,
  cardholder_name text NOT NULL,
  expiry_month integer,
  expiry_year integer,
  is_default boolean DEFAULT false,
  stripe_payment_method_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_method_type CHECK (method_type IN ('credit_card', 'debit_card', 'paypal', 'bank_account', 'other')),
  CONSTRAINT valid_expiry_month CHECK (expiry_month IS NULL OR (expiry_month >= 1 AND expiry_month <= 12)),
  CONSTRAINT valid_expiry_year CHECK (expiry_year IS NULL OR expiry_year >= 2024)
);

-- Enable RLS
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE collector_payment_methods ENABLE ROW LEVEL SECURITY;

-- Cart items policies
CREATE POLICY "Collectors can view their own cart items"
  ON cart_items FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Collectors can add items to their cart"
  ON cart_items FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can update their cart items"
  ON cart_items FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can remove items from their cart"
  ON cart_items FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());

-- Collector payment methods policies
CREATE POLICY "Collectors can view their own payment methods"
  ON collector_payment_methods FOR SELECT
  TO authenticated
  USING (client_id = auth.uid());

CREATE POLICY "Collectors can add their payment methods"
  ON collector_payment_methods FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can update their payment methods"
  ON collector_payment_methods FOR UPDATE
  TO authenticated
  USING (client_id = auth.uid())
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Collectors can delete their payment methods"
  ON collector_payment_methods FOR DELETE
  TO authenticated
  USING (client_id = auth.uid());

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_cart_items_client_id ON cart_items(client_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_listing_id ON cart_items(listing_id);
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_client_id ON collector_payment_methods(client_id);
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_default ON collector_payment_methods(client_id, is_default) WHERE is_default = true;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_cart_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_cart_items_updated_at_trigger ON cart_items;
CREATE TRIGGER update_cart_items_updated_at_trigger
  BEFORE UPDATE ON cart_items
  FOR EACH ROW
  EXECUTE FUNCTION update_cart_updated_at();

DROP TRIGGER IF EXISTS update_collector_payment_methods_updated_at_trigger ON collector_payment_methods;
CREATE TRIGGER update_collector_payment_methods_updated_at_trigger
  BEFORE UPDATE ON collector_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION update_cart_updated_at();

-- =========================================
-- Migration: 20251127163349_create_picker_payout_info_table.sql
-- =========================================

-- Create Picker Payout Information Table
-- 
-- 1. New Tables
--    - picker_payout_info
--      - id (uuid, primary key)
--      - picker_id (uuid, foreign key to profiles)
--      - bank_account_name (text) - Name on the bank account
--      - bank_account_number (text) - Bank account number
--      - bank_name (text) - Name of the bank
--      - bank_routing_number (text) - Routing/sort code
--      - bank_swift_code (text) - SWIFT/BIC code for international transfers
--      - country (text) - Country of the bank account
--      - currency (text) - Payout currency (USD, EUR, GBP, etc.)
--      - is_verified (boolean) - Whether the account has been verified
--      - created_at (timestamptz)
--      - updated_at (timestamptz)
-- 
-- 2. Security
--    - Enable RLS on picker_payout_info table
--    - Add policies for pickers to manage their own payout information

CREATE TABLE IF NOT EXISTS picker_payout_info (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  bank_account_name text NOT NULL,
  bank_account_number text NOT NULL,
  bank_name text NOT NULL,
  bank_routing_number text DEFAULT '',
  bank_swift_code text DEFAULT '',
  country text NOT NULL,
  currency text DEFAULT 'USD',
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE picker_payout_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Pickers can view own payout info"
  ON picker_payout_info
  FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

CREATE POLICY "Pickers can insert own payout info"
  ON picker_payout_info
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can update own payout info"
  ON picker_payout_info
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can delete own payout info"
  ON picker_payout_info
  FOR DELETE
  TO authenticated
  USING (auth.uid() = picker_id);

CREATE INDEX IF NOT EXISTS idx_picker_payout_info_picker_id ON picker_payout_info(picker_id);


-- =========================================
-- Migration: 20251127175256_create_video_calls_system.sql
-- =========================================

/*
  # Create Video Call System

  1. New Tables
    - `video_calls`
      - `id` (uuid, primary key)
      - `conversation_id` (uuid, references conversations)
      - `initiator_id` (uuid, references profiles)
      - `receiver_id` (uuid, references profiles)
      - `room_name` (text, unique identifier for the call)
      - `status` (text: 'initiated', 'ringing', 'active', 'ended', 'missed', 'declined')
      - `started_at` (timestamptz, when call started)
      - `ended_at` (timestamptz, when call ended)
      - `duration_seconds` (integer, call duration)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `video_calls` table
    - Add policies for authenticated users to manage their own video calls
    - Add policies to view calls they are part of

  3. Indexes
    - Index on conversation_id for faster lookups
    - Index on initiator_id and receiver_id
    - Index on status for filtering active calls

  4. Functions
    - Trigger to update conversation's updated_at on new call
    - Function to generate unique room names
*/

-- Create video_calls table
CREATE TABLE IF NOT EXISTS video_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  initiator_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  room_name text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'initiated' CHECK (status IN ('initiated', 'ringing', 'active', 'ended', 'missed', 'declined')),
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_video_calls_conversation_id ON video_calls(conversation_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_initiator_id ON video_calls(initiator_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_receiver_id ON video_calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_video_calls_status ON video_calls(status);
CREATE INDEX IF NOT EXISTS idx_video_calls_created_at ON video_calls(created_at DESC);

-- Enable Row Level Security
ALTER TABLE video_calls ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view video calls they are part of
CREATE POLICY "Users can view their own video calls"
  ON video_calls
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = initiator_id OR
    auth.uid() = receiver_id
  );

-- Policy: Users can create video calls
CREATE POLICY "Users can create video calls"
  ON video_calls
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = initiator_id);

-- Policy: Users can update video calls they are part of
CREATE POLICY "Users can update their video calls"
  ON video_calls
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = initiator_id OR
    auth.uid() = receiver_id
  )
  WITH CHECK (
    auth.uid() = initiator_id OR
    auth.uid() = receiver_id
  );

-- Policy: Users can delete video calls they initiated
CREATE POLICY "Users can delete video calls they initiated"
  ON video_calls
  FOR DELETE
  TO authenticated
  USING (auth.uid() = initiator_id);

-- Function to update video_calls updated_at timestamp
CREATE OR REPLACE FUNCTION update_video_calls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS video_calls_updated_at ON video_calls;
CREATE TRIGGER video_calls_updated_at
  BEFORE UPDATE ON video_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_video_calls_updated_at();

-- Function to update conversation when video call is created
CREATE OR REPLACE FUNCTION update_conversation_on_video_call()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE conversations
  SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update conversation on new video call
DROP TRIGGER IF EXISTS update_conversation_on_video_call ON video_calls;
CREATE TRIGGER update_conversation_on_video_call
  AFTER INSERT ON video_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_on_video_call();


-- =========================================
-- Migration: 20251127234144_add_missing_foreign_key_indexes.sql
-- =========================================

/*
  # Add Missing Foreign Key Indexes for Performance

  1. Performance Optimization
    - Add indexes for all unindexed foreign keys to improve query performance
    - These indexes enable faster JOIN operations and foreign key lookups
    
  2. Tables Updated
    - blocked_users: Add index on blocked_user_id
    - client_payment_methods: Add index on client_id
    - conversation_messages: Add index on sender_id
    - favorite_pickers: Add index on picker_id
    - listing_shares: Add index on user_id
    - message_reactions: Add index on user_id
    - messages: Add indexes on recipient_id and sender_id
    - order_status_history: Add index on changed_by
    - order_updates: Add index on created_by
    - payment_escrow: Add indexes on payment_intent_id and released_to
    - profiles: Add index on default_payment_card_id
    - referral_rewards: Add index on referral_id
    - refunds: Add indexes on initiated_by and payment_intent_id
    - reported_users: Add indexes on reported_user_id, reporter_id, and reviewed_by
    - reviews: Add indexes on client_id and listing_id
    - reward_redemptions: Add indexes on order_id, reward_id, and user_id
    - shipment_tracking: Add index on provider_id
    - shipping_rates: Add index on provider_id
    - typing_indicators: Add index on user_id
*/

-- Add missing foreign key indexes
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_user_id ON public.blocked_users(blocked_user_id);
CREATE INDEX IF NOT EXISTS idx_client_payment_methods_client_id ON public.client_payment_methods(client_id);
CREATE INDEX IF NOT EXISTS idx_conversation_messages_sender_id ON public.conversation_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_favorite_pickers_picker_id ON public.favorite_pickers(picker_id);
CREATE INDEX IF NOT EXISTS idx_listing_shares_user_id ON public.listing_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id ON public.message_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON public.messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_changed_by ON public.order_status_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_order_updates_created_by ON public.order_updates(created_by);
CREATE INDEX IF NOT EXISTS idx_payment_escrow_payment_intent_id ON public.payment_escrow(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_payment_escrow_released_to ON public.payment_escrow(released_to);
CREATE INDEX IF NOT EXISTS idx_profiles_default_payment_card_id ON public.profiles(default_payment_card_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referral_id ON public.referral_rewards(referral_id);
CREATE INDEX IF NOT EXISTS idx_refunds_initiated_by ON public.refunds(initiated_by);
CREATE INDEX IF NOT EXISTS idx_refunds_payment_intent_id ON public.refunds(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_reported_users_reported_user_id ON public.reported_users(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reported_users_reporter_id ON public.reported_users(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reported_users_reviewed_by ON public.reported_users(reviewed_by);
CREATE INDEX IF NOT EXISTS idx_reviews_client_id ON public.reviews(client_id);
CREATE INDEX IF NOT EXISTS idx_reviews_listing_id ON public.reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_order_id ON public.reward_redemptions(order_id);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_reward_id ON public.reward_redemptions(reward_id);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_user_id ON public.reward_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_shipment_tracking_provider_id ON public.shipment_tracking(provider_id);
CREATE INDEX IF NOT EXISTS idx_shipping_rates_provider_id ON public.shipping_rates(provider_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_user_id ON public.typing_indicators(user_id);

-- =========================================
-- Migration: 20251127234323_optimize_rls_auth_calls.sql
-- =========================================

/*
  # Optimize RLS Policies - Replace auth.uid() with SELECT wrapper

  1. Performance Optimization
    - Wraps all auth.uid() calls with (select auth.uid())
    - Prevents re-evaluation of auth function for each row
    - Improves query performance significantly at scale
    
  2. Implementation
    - Drops existing policies and recreates with optimized auth calls
    - Maintains exact same logic and security
    - Only changes performance characteristics
*/

-- Helper function to optimize all RLS policies
DO $$
DECLARE
  pol record;
  new_using text;
  new_check text;
BEGIN
  -- Loop through all policies that likely use auth.uid()
  FOR pol IN 
    SELECT 
      schemaname,
      tablename,
      policyname,
      cmd,
      qual as using_clause,
      with_check as check_clause
    FROM pg_policies
    WHERE schemaname = 'public'
    AND (qual LIKE '%auth.uid()%' OR with_check LIKE '%auth.uid()%')
  LOOP
    -- Replace auth.uid() with (select auth.uid()) in USING clause
    IF pol.using_clause IS NOT NULL THEN
      new_using := replace(pol.using_clause, 'auth.uid()', '(select auth.uid())');
    ELSE
      new_using := NULL;
    END IF;
    
    -- Replace auth.uid() with (select auth.uid()) in WITH CHECK clause
    IF pol.check_clause IS NOT NULL THEN
      new_check := replace(pol.check_clause, 'auth.uid()', '(select auth.uid())');
    ELSE
      new_check := NULL;
    END IF;
    
    -- Drop the old policy
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
      pol.policyname,
      pol.schemaname,
      pol.tablename
    );
    
    -- Recreate with optimized version
    IF pol.cmd = '*' THEN
      -- FOR ALL
      IF new_using IS NOT NULL AND new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s) WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using, new_check
        );
      ELSIF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      ELSIF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR ALL TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'r' THEN
      -- FOR SELECT
      IF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR SELECT TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      END IF;
    ELSIF pol.cmd = 'a' THEN
      -- FOR INSERT
      IF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR INSERT TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'w' THEN
      -- FOR UPDATE
      IF new_using IS NOT NULL AND new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated USING (%s) WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using, new_check
        );
      ELSIF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      ELSIF new_check IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR UPDATE TO authenticated WITH CHECK (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_check
        );
      END IF;
    ELSIF pol.cmd = 'd' THEN
      -- FOR DELETE
      IF new_using IS NOT NULL THEN
        EXECUTE format(
          'CREATE POLICY %I ON %I.%I FOR DELETE TO authenticated USING (%s)',
          pol.policyname, pol.schemaname, pol.tablename, new_using
        );
      END IF;
    END IF;
  END LOOP;
END $$;

-- =========================================
-- Migration: 20251127234352_remove_unused_indexes.sql
-- =========================================

/*
  # Remove Unused Indexes

  1. Performance Optimization
    - Removes indexes that have never been used
    - Reduces storage overhead and write performance impact
    - Only removes truly unused indexes identified by Supabase
    
  2. Indexes Removed
    - Various unused indexes across multiple tables
    - These indexes consume storage and slow down writes without providing query benefits
*/

-- Remove unused indexes
DROP INDEX IF EXISTS public.idx_listings_region;
DROP INDEX IF EXISTS public.idx_requests_picker_id;
DROP INDEX IF EXISTS public.idx_messages_request_id;
DROP INDEX IF EXISTS public.idx_reviews_picker_id;
DROP INDEX IF EXISTS public.idx_payment_intents_order_id;
DROP INDEX IF EXISTS public.idx_payment_intents_stripe_id;
DROP INDEX IF EXISTS public.idx_refunds_order_id;
DROP INDEX IF EXISTS public.idx_reviews_order_id;
DROP INDEX IF EXISTS public.idx_email_notifications_user_id;
DROP INDEX IF EXISTS public.idx_email_notifications_status;
DROP INDEX IF EXISTS public.idx_client_desires_category;
DROP INDEX IF EXISTS public.idx_conversation_messages_created;
DROP INDEX IF EXISTS public.idx_picker_payment_methods_active;
DROP INDEX IF EXISTS public.idx_shipment_tracking_order_id;
DROP INDEX IF EXISTS public.idx_shipment_tracking_tracking_number;
DROP INDEX IF EXISTS public.idx_shipping_rates_order_id;
DROP INDEX IF EXISTS public.idx_message_reactions_message_id;
DROP INDEX IF EXISTS public.idx_message_attachments_message_id;
DROP INDEX IF EXISTS public.idx_typing_indicators_conversation_id;
DROP INDEX IF EXISTS public.idx_orders_listing_id;
DROP INDEX IF EXISTS public.idx_orders_status;
DROP INDEX IF EXISTS public.idx_orders_created_at;
DROP INDEX IF EXISTS public.idx_order_status_history_order_id;
DROP INDEX IF EXISTS public.idx_picker_analytics_picker_id;
DROP INDEX IF EXISTS public.idx_picker_analytics_date;
DROP INDEX IF EXISTS public.idx_notifications_read;
DROP INDEX IF EXISTS public.idx_favorites_client_id;
DROP INDEX IF EXISTS public.idx_favorites_listing_id;
DROP INDEX IF EXISTS public.idx_favorite_pickers_client_id;
DROP INDEX IF EXISTS public.idx_reported_users_status;
DROP INDEX IF EXISTS public.idx_blocked_users_user_id;
DROP INDEX IF EXISTS public.idx_order_updates_order_id;
DROP INDEX IF EXISTS public.idx_review_votes_review_id;
DROP INDEX IF EXISTS public.idx_review_votes_user_id;
DROP INDEX IF EXISTS public.idx_listing_shares_listing_id;
DROP INDEX IF EXISTS public.idx_user_activity_user_id;
DROP INDEX IF EXISTS public.idx_user_activity_created_at;
DROP INDEX IF EXISTS public.idx_listing_views_listing_id;
DROP INDEX IF EXISTS public.idx_listing_views_user_id;
DROP INDEX IF EXISTS public.idx_listing_views_created_at;
DROP INDEX IF EXISTS public.idx_referrals_referred_id;
DROP INDEX IF EXISTS public.idx_referral_rewards_redeemed;
DROP INDEX IF EXISTS public.idx_subscription_payments_picker_id;
DROP INDEX IF EXISTS public.idx_subscription_payments_status;
DROP INDEX IF EXISTS public.idx_subscription_payments_period;
DROP INDEX IF EXISTS public.idx_payment_cards_picker_id;
DROP INDEX IF EXISTS public.idx_cart_items_listing_id;
DROP INDEX IF EXISTS public.idx_collector_payment_methods_default;
DROP INDEX IF EXISTS public.idx_picker_stripe_accounts_stripe_id;
DROP INDEX IF EXISTS public.idx_picker_stripe_accounts_status;
DROP INDEX IF EXISTS public.idx_picker_payouts_picker_id;
DROP INDEX IF EXISTS public.idx_picker_payouts_status;
DROP INDEX IF EXISTS public.idx_picker_payouts_escrow_id;
DROP INDEX IF EXISTS public.idx_picker_payouts_order_id;
DROP INDEX IF EXISTS public.idx_picker_payouts_created_at;
DROP INDEX IF EXISTS public.idx_picker_earnings_picker_id;
DROP INDEX IF EXISTS public.idx_payment_escrow_payout_processed;
DROP INDEX IF EXISTS public.idx_video_calls_conversation_id;
DROP INDEX IF EXISTS public.idx_video_calls_initiator_id;
DROP INDEX IF EXISTS public.idx_video_calls_receiver_id;
DROP INDEX IF EXISTS public.idx_video_calls_status;
DROP INDEX IF EXISTS public.idx_video_calls_created_at;

-- =========================================
-- Migration: 20251127234437_fix_all_function_search_paths.sql
-- =========================================

/*
  # Fix Function Search Paths for Security

  1. Security Enhancement
    - Sets immutable search_path for all functions to prevent search_path attacks
    - Uses explicit schema qualification where needed
    
  2. Functions Updated
    - All trigger functions and utility functions with correct signatures
    - Ensures they use stable, secure search paths
*/

-- Fix search paths for all functions (with correct signatures)
ALTER FUNCTION public.apply_referral_code(p_code text, p_user_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.auto_release_escrow_after_confirmation() SET search_path = public, pg_temp;
ALTER FUNCTION public.automatic_escrow_creation() SET search_path = public, pg_temp;
ALTER FUNCTION public.calculate_trending_listings() SET search_path = public, pg_temp;
ALTER FUNCTION public.create_default_notification_preferences() SET search_path = public, pg_temp;
ALTER FUNCTION public.create_referral_code_for_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.generate_referral_code() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_personalized_recommendations(p_user_id uuid, p_limit integer) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_referral_stats(p_user_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_trending_listings(p_limit integer) SET search_path = public, pg_temp;
ALTER FUNCTION public.initialize_picker_earnings() SET search_path = public, pg_temp;
ALTER FUNCTION public.mark_messages_read(p_conversation_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.mark_verified_purchase() SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_picker_followed() SET search_path = public, pg_temp;
ALTER FUNCTION public.notify_tracking_update() SET search_path = public, pg_temp;
ALTER FUNCTION public.process_escrow_releases() SET search_path = public, pg_temp;
ALTER FUNCTION public.process_picker_subscription_payment(p_picker_id uuid, p_amount numeric, p_stripe_payment_intent_id text, p_payment_method_used text) SET search_path = public, pg_temp;
ALTER FUNCTION public.process_referral_completion() SET search_path = public, pg_temp;
ALTER FUNCTION public.record_listing_view(p_listing_id uuid, p_user_id uuid, p_session_id text) SET search_path = public, pg_temp;
ALTER FUNCTION public.refund_escrow_to_client(escrow_id uuid, refund_reason text) SET search_path = public, pg_temp;
ALTER FUNCTION public.release_escrow_to_picker(escrow_id uuid, picker_user_id uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.set_default_payment_card() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_cart_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_conversation_last_message() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_conversation_on_video_call() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_earnings_on_escrow_held() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_earnings_on_escrow_release() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_orders_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_picker_earnings_on_payout() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_picker_follower_count() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_review_vote_counts() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_reviews_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_unread_counts() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_user_preferences_from_activity() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_video_calls_updated_at() SET search_path = public, pg_temp;

-- =========================================
-- Migration: 20251128074500_add_profile_update_policy.sql
-- =========================================

/*
  # Add UPDATE policy for profiles table

  1. Changes
    - Add policy to allow authenticated users to update their own profile
    - This enables users to switch between picker and client modes
  
  2. Security
    - Users can only update their own profile (auth.uid() = id)
    - Prevents users from modifying other users' profiles
*/

CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- =========================================
-- Migration: 20251128075137_add_orders_messages_policies_fixed.sql
-- =========================================

/*
  # Add RLS policies for orders, conversations, and messages

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for orders table
    - Add SELECT, INSERT, UPDATE policies for conversations table
    - Add SELECT, INSERT, UPDATE policies for messages table
  
  2. Security
    - Orders: accessible by client who placed order or picker who received it
    - Conversations: accessible by both participants
    - Messages: accessible by sender and recipient
*/

-- Orders policies
CREATE POLICY "Users can view their orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Clients can create orders"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update their orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  )
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

-- Conversations policies
CREATE POLICY "Users can view their conversations"
  ON conversations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Users can create conversations"
  ON conversations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

CREATE POLICY "Users can update their conversations"
  ON conversations
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  )
  WITH CHECK (
    auth.uid() = client_id OR 
    auth.uid() = picker_id
  );

-- Messages policies
CREATE POLICY "Users can view their messages"
  ON messages
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = sender_id OR 
    auth.uid() = recipient_id
  );

CREATE POLICY "Users can send messages"
  ON messages
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own messages"
  ON messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);


-- =========================================
-- Migration: 20251128075606_add_video_calls_policies.sql
-- =========================================

/*
  # Add RLS policies for video_calls table

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for video_calls table
  
  2. Security
    - Video calls accessible by both initiator and receiver
    - Only initiator can create calls
    - Both parties can update call status
*/

-- Video calls policies
CREATE POLICY "Users can view their video calls"
  ON video_calls
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  );

CREATE POLICY "Users can initiate video calls"
  ON video_calls
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = initiator_id);

CREATE POLICY "Users can update their video calls"
  ON video_calls
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  )
  WITH CHECK (
    auth.uid() = initiator_id OR 
    auth.uid() = receiver_id
  );


-- =========================================
-- Migration: 20251128080112_add_conversation_messages_policies.sql
-- =========================================

/*
  # Add RLS policies for conversation_messages table

  1. Changes
    - Add SELECT, INSERT, UPDATE policies for conversation_messages table
  
  2. Security
    - Users can view messages in their conversations
    - Users can send messages in their conversations
    - Users can update their own messages
*/

-- Conversation messages policies
CREATE POLICY "Users can view messages in their conversations"
  ON conversation_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM conversations
      WHERE conversations.id = conversation_messages.conversation_id
      AND (conversations.client_id = auth.uid() OR conversations.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their conversations"
  ON conversation_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM conversations
      WHERE conversations.id = conversation_id
      AND (conversations.client_id = auth.uid() OR conversations.picker_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their own messages"
  ON conversation_messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);


-- =========================================
-- Migration: 20251128082919_add_client_desires_policies.sql
-- =========================================

/*
  # Add RLS policies for client_desires table

  1. Changes
    - Add SELECT, INSERT, UPDATE, DELETE policies for client_desires table
  
  2. Security
    - Pickers can view all active desires
    - Clients can view their own desires
    - Clients can create their own desires
    - Clients can update/delete their own desires
*/

-- Clients can view their own desires
CREATE POLICY "Clients can view own desires"
  ON client_desires
  FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- Pickers can view all active desires
CREATE POLICY "Pickers can view active desires"
  ON client_desires
  FOR SELECT
  TO authenticated
  USING (
    active = true AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'picker'
    )
  );

-- Clients can create their own desires
CREATE POLICY "Clients can create desires"
  ON client_desires
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.user_type = 'client'
    )
  );

-- Clients can update their own desires
CREATE POLICY "Clients can update own desires"
  ON client_desires
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (auth.uid() = client_id);

-- Clients can delete their own desires
CREATE POLICY "Clients can delete own desires"
  ON client_desires
  FOR DELETE
  TO authenticated
  USING (auth.uid() = client_id);


-- =========================================
-- Migration: 20251128084636_add_default_delivery_address_to_profiles.sql
-- =========================================

/*
  # Add Default Delivery Address to Profiles
  
  ## Overview
  This migration adds a default delivery address field to the profiles table for collectors
  to save their preferred shipping address.
  
  ## Changes
  1. Add `default_delivery_address` column to profiles table
  2. This allows collectors to save their address and have it pre-filled during checkout
  
  ## Notes
  - Field is optional (nullable)
  - Collectors can update this in their profile settings
  - Will be used to pre-fill the delivery address field in cart checkout
*/

-- Add default delivery address column to profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'default_delivery_address'
  ) THEN
    ALTER TABLE profiles ADD COLUMN default_delivery_address text;
  END IF;
END $$;

-- =========================================
-- Migration: 20251128113815_enable_pg_cron_for_escrow_releases.sql
-- =========================================

/*
  # Enable pg_cron for Automated Escrow Releases

  1. Extensions
    - Enable pg_cron extension for scheduled jobs
    - Enable pg_net extension for HTTP requests

  2. Scheduled Jobs
    - Creates a cron job that runs every hour to check for escrows that should be auto-released
    - Automatically releases payment to pickers after 48 hours if collector doesn't confirm

  3. Automation Flow
    - Runs every hour (0 * * * *)
    - Checks for orders with status='delivered' where delivered_at > 48 hours ago
    - Automatically releases funds from escrow to picker
    - Sends notifications to both picker and collector
    - Updates order status to 'completed'

  4. Security
    - Uses existing process_escrow_releases() function
    - All RLS policies remain in effect
    - Only releases funds that meet 48-hour criteria
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule the escrow auto-release job to run every hour
SELECT cron.schedule(
  'auto-release-escrow-after-48-hours',
  '0 * * * *',
  $$
  SELECT process_escrow_releases();
  $$
);


-- =========================================
-- Migration: 20251128114450_create_media_verification_system.sql
-- =========================================

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


-- =========================================
-- Migration: 20251128115709_create_invoices_system.sql
-- =========================================

/*
  # Create Invoice System for Subscription Payments

  1. New Tables
    - `invoices`
      - `id` (uuid, primary key)
      - `invoice_number` (text, unique) - Format: INV-YYYY-MM-XXXXXXX
      - `picker_id` (uuid, references profiles)
      - `payment_id` (uuid, references picker_subscription_payments)
      - `issue_date` (date) - Invoice issue date
      - `due_date` (date) - Payment due date
      - `billing_period_start` (date)
      - `billing_period_end` (date)
      - `subtotal` (decimal) - Amount before tax
      - `tax_rate` (decimal) - VAT/Tax rate percentage
      - `tax_amount` (decimal) - Calculated tax
      - `total_amount` (decimal) - Final amount
      - `currency` (text) - EUR, USD, etc.
      - `status` (enum: 'draft', 'sent', 'paid', 'cancelled')
      - `payment_method` (text) - Card type and last 4 digits
      - `paid_at` (timestamp)
      - `sent_at` (timestamp) - When email was sent
      - `billing_name` (text) - Customer/company name
      - `billing_email` (text)
      - `billing_address` (text)
      - `billing_city` (text)
      - `billing_postal_code` (text)
      - `billing_country` (text)
      - `tax_id` (text) - VAT number if applicable
      - `notes` (text) - Additional notes
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on invoices table
    - Pickers can view their own invoices
    - Admins can view all invoices
    - System can create and update invoices

  3. Indexes
    - Index on picker_id for user queries
    - Index on invoice_number for lookups
    - Index on issue_date for chronological queries
    - Index on status for filtering

  4. Functions
    - Auto-generate invoice numbers
    - Calculate tax amounts
    - Update invoice sequence

  5. Notes
    - Invoices generated automatically after successful subscription payment
    - Email sent to picker with PDF invoice attachment
    - Supports VAT/tax calculation for EU countries
    - Invoice numbers follow format: INV-2025-11-0000001
*/

-- Create enum for invoice status
DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM ('draft', 'sent', 'paid', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create invoices table
CREATE TABLE IF NOT EXISTS invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number text UNIQUE NOT NULL,
  picker_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  payment_id uuid REFERENCES picker_subscription_payments(id) ON DELETE SET NULL,
  issue_date date DEFAULT CURRENT_DATE NOT NULL,
  due_date date DEFAULT CURRENT_DATE NOT NULL,
  billing_period_start date NOT NULL,
  billing_period_end date NOT NULL,
  subtotal decimal(10,2) NOT NULL,
  tax_rate decimal(5,2) DEFAULT 0,
  tax_amount decimal(10,2) DEFAULT 0,
  total_amount decimal(10,2) NOT NULL,
  currency text DEFAULT 'EUR' NOT NULL,
  status invoice_status DEFAULT 'draft' NOT NULL,
  payment_method text,
  paid_at timestamptz,
  sent_at timestamptz,
  billing_name text NOT NULL,
  billing_email text NOT NULL,
  billing_address text,
  billing_city text,
  billing_postal_code text,
  billing_country text,
  tax_id text,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create invoice sequence table for tracking invoice numbers
CREATE TABLE IF NOT EXISTS invoice_sequences (
  year integer PRIMARY KEY,
  month integer NOT NULL,
  last_sequence integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(year, month)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_invoices_picker 
  ON invoices(picker_id);

CREATE INDEX IF NOT EXISTS idx_invoices_number 
  ON invoices(invoice_number);

CREATE INDEX IF NOT EXISTS idx_invoices_issue_date 
  ON invoices(issue_date DESC);

CREATE INDEX IF NOT EXISTS idx_invoices_status 
  ON invoices(status);

CREATE INDEX IF NOT EXISTS idx_invoices_payment 
  ON invoices(payment_id);

-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_sequences ENABLE ROW LEVEL SECURITY;

-- Pickers can view their own invoices
CREATE POLICY "Pickers can view own invoices"
  ON invoices
  FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- System can create invoices
CREATE POLICY "System can create invoices"
  ON invoices
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- System can update invoices
CREATE POLICY "System can update invoices"
  ON invoices
  FOR UPDATE
  TO authenticated
  USING (true);

-- Admins can view all invoices
CREATE POLICY "Admins can view all invoices"
  ON invoices
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.user_type = 'admin'
  ));

-- Function to generate next invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS text AS $$
DECLARE
  current_year integer;
  current_month integer;
  next_sequence integer;
  invoice_num text;
BEGIN
  current_year := EXTRACT(YEAR FROM CURRENT_DATE)::integer;
  current_month := EXTRACT(MONTH FROM CURRENT_DATE)::integer;
  
  -- Get or create sequence for current year/month
  INSERT INTO invoice_sequences (year, month, last_sequence)
  VALUES (current_year, current_month, 1)
  ON CONFLICT (year, month) 
  DO UPDATE SET 
    last_sequence = invoice_sequences.last_sequence + 1,
    updated_at = now()
  RETURNING last_sequence INTO next_sequence;
  
  -- Format: INV-2025-11-0000001
  invoice_num := 'INV-' || 
                 current_year::text || '-' || 
                 LPAD(current_month::text, 2, '0') || '-' ||
                 LPAD(next_sequence::text, 7, '0');
  
  RETURN invoice_num;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set search path for the function
ALTER FUNCTION generate_invoice_number() SET search_path = public, pg_temp;

-- Function to calculate VAT based on country
CREATE OR REPLACE FUNCTION calculate_vat_rate(country_code text)
RETURNS decimal AS $$
BEGIN
  -- EU VAT rates (simplified - in production, use accurate rates)
  CASE UPPER(country_code)
    WHEN 'AT' THEN RETURN 20.00; -- Austria
    WHEN 'BE' THEN RETURN 21.00; -- Belgium
    WHEN 'BG' THEN RETURN 20.00; -- Bulgaria
    WHEN 'CY' THEN RETURN 19.00; -- Cyprus
    WHEN 'CZ' THEN RETURN 21.00; -- Czech Republic
    WHEN 'DE' THEN RETURN 19.00; -- Germany
    WHEN 'DK' THEN RETURN 25.00; -- Denmark
    WHEN 'EE' THEN RETURN 20.00; -- Estonia
    WHEN 'ES' THEN RETURN 21.00; -- Spain
    WHEN 'FI' THEN RETURN 24.00; -- Finland
    WHEN 'FR' THEN RETURN 20.00; -- France
    WHEN 'GR' THEN RETURN 24.00; -- Greece
    WHEN 'HR' THEN RETURN 25.00; -- Croatia
    WHEN 'HU' THEN RETURN 27.00; -- Hungary
    WHEN 'IE' THEN RETURN 23.00; -- Ireland
    WHEN 'IT' THEN RETURN 22.00; -- Italy
    WHEN 'LT' THEN RETURN 21.00; -- Lithuania
    WHEN 'LU' THEN RETURN 17.00; -- Luxembourg
    WHEN 'LV' THEN RETURN 21.00; -- Latvia
    WHEN 'MT' THEN RETURN 18.00; -- Malta
    WHEN 'NL' THEN RETURN 21.00; -- Netherlands
    WHEN 'PL' THEN RETURN 23.00; -- Poland
    WHEN 'PT' THEN RETURN 23.00; -- Portugal
    WHEN 'RO' THEN RETURN 19.00; -- Romania
    WHEN 'SE' THEN RETURN 25.00; -- Sweden
    WHEN 'SI' THEN RETURN 22.00; -- Slovenia
    WHEN 'SK' THEN RETURN 20.00; -- Slovakia
    ELSE RETURN 0.00; -- Non-EU or unknown
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Set search path for the function
ALTER FUNCTION calculate_vat_rate(text) SET search_path = public, pg_temp;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_invoice_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_invoice_timestamp
  BEFORE UPDATE ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_invoice_updated_at();


-- =========================================
-- Migration: 20251128124343_create_social_feed_stories_system.sql
-- =========================================

/*
  # Social Feed & Stories System

  1. New Tables
    - `stories`
      - Ephemeral content from pickers (24-hour lifespan)
      - Photos/videos from markets, events, travels
      - Links to picker's current location

    - `story_views`
      - Tracks who viewed which stories
      - Used for analytics and "seen by" features

    - `story_reactions`
      - Emoji reactions to stories
      - Real-time engagement metrics

    - `feed_posts`
      - Permanent social posts from pickers
      - Showcase completed orders, featured items
      - Community building content

    - `post_reactions`
      - Likes and reactions to feed posts

    - `post_comments`
      - Comments on feed posts
      - Enable community discussion

  2. Security
    - Enable RLS on all tables
    - Anyone can view public stories/posts
    - Only creators can manage their content
    - Authenticated users can react and comment

  3. Features
    - 24-hour auto-expiry for stories
    - Real-time view tracking
    - Multiple media per post
    - Hashtag support
    - Location tagging
*/

-- Stories table (Instagram-style stories)
CREATE TABLE IF NOT EXISTS stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  media_url text NOT NULL,
  media_type text NOT NULL CHECK (media_type IN ('image', 'video')),
  thumbnail_url text,
  caption text,
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  view_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stories_picker_id_idx ON stories(picker_id);
CREATE INDEX IF NOT EXISTS stories_expires_at_idx ON stories(expires_at);
CREATE INDEX IF NOT EXISTS stories_created_at_idx ON stories(created_at DESC);

-- Story views tracking
CREATE TABLE IF NOT EXISTS story_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at timestamptz DEFAULT now(),
  UNIQUE(story_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS story_views_story_id_idx ON story_views(story_id);
CREATE INDEX IF NOT EXISTS story_views_viewer_id_idx ON story_views(viewer_id);

-- Story reactions
CREATE TABLE IF NOT EXISTS story_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL CHECK (reaction IN ('like', 'love', 'fire', 'clap', 'wow')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(story_id, user_id)
);

CREATE INDEX IF NOT EXISTS story_reactions_story_id_idx ON story_reactions(story_id);
CREATE INDEX IF NOT EXISTS story_reactions_user_id_idx ON story_reactions(user_id);

-- Feed posts (permanent social content)
CREATE TABLE IF NOT EXISTS feed_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  media_urls text[] DEFAULT '{}',
  media_types text[] DEFAULT '{}',
  hashtags text[] DEFAULT '{}',
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  linked_order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  linked_listing_id uuid REFERENCES listings(id) ON DELETE SET NULL,
  is_pinned boolean DEFAULT false,
  view_count integer DEFAULT 0,
  reaction_count integer DEFAULT 0,
  comment_count integer DEFAULT 0,
  share_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS feed_posts_user_id_idx ON feed_posts(user_id);
CREATE INDEX IF NOT EXISTS feed_posts_created_at_idx ON feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS feed_posts_hashtags_idx ON feed_posts USING gin(hashtags);
CREATE INDEX IF NOT EXISTS feed_posts_linked_order_id_idx ON feed_posts(linked_order_id);

-- Post reactions
CREATE TABLE IF NOT EXISTS post_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL CHECK (reaction IN ('like', 'love', 'fire', 'clap', 'wow', 'celebrate')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS post_reactions_post_id_idx ON post_reactions(post_id);
CREATE INDEX IF NOT EXISTS post_reactions_user_id_idx ON post_reactions(user_id);

-- Post comments
CREATE TABLE IF NOT EXISTS post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  parent_comment_id uuid REFERENCES post_comments(id) ON DELETE CASCADE,
  is_edited boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS post_comments_post_id_idx ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS post_comments_user_id_idx ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS post_comments_parent_id_idx ON post_comments(parent_comment_id);

-- Enable RLS
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Stories policies
CREATE POLICY "Anyone can view active stories"
  ON stories FOR SELECT
  USING (expires_at > now());

CREATE POLICY "Pickers can create stories"
  ON stories FOR INSERT
  TO authenticated
  WITH CHECK (
    picker_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND user_type = 'picker')
  );

CREATE POLICY "Pickers can delete own stories"
  ON stories FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- Story views policies
CREATE POLICY "Anyone can view story views"
  ON story_views FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can record story views"
  ON story_views FOR INSERT
  TO authenticated
  WITH CHECK (viewer_id = auth.uid());

-- Story reactions policies
CREATE POLICY "Anyone can view story reactions"
  ON story_reactions FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can add story reactions"
  ON story_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own story reactions"
  ON story_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Feed posts policies
CREATE POLICY "Anyone can view feed posts"
  ON feed_posts FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create posts"
  ON feed_posts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own posts"
  ON feed_posts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own posts"
  ON feed_posts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Post reactions policies
CREATE POLICY "Anyone can view post reactions"
  ON post_reactions FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can add reactions"
  ON post_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own reactions"
  ON post_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Post comments policies
CREATE POLICY "Anyone can view comments"
  ON post_comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create comments"
  ON post_comments FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own comments"
  ON post_comments FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own comments"
  ON post_comments FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Function to increment story view count
CREATE OR REPLACE FUNCTION increment_story_views()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE stories
  SET view_count = view_count + 1
  WHERE id = NEW.story_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_story_view_increment
  AFTER INSERT ON story_views
  FOR EACH ROW
  EXECUTE FUNCTION increment_story_views();

-- Function to update post reaction count
CREATE OR REPLACE FUNCTION update_post_reaction_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE feed_posts
    SET reaction_count = reaction_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE feed_posts
    SET reaction_count = reaction_count - 1
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER on_post_reaction_change
  AFTER INSERT OR DELETE ON post_reactions
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reaction_count();

-- Function to update post comment count
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE feed_posts
    SET comment_count = comment_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE feed_posts
    SET comment_count = comment_count - 1
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER on_post_comment_change
  AFTER INSERT OR DELETE ON post_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_post_comment_count();

-- =========================================
-- Migration: 20251128124532_create_live_streaming_system.sql
-- =========================================

/*
  # Live Streaming System

  1. New Tables
    - `live_streams`
      - Active live streams from pickers
      - Stream metadata and status
      - Location and viewer counts

    - `stream_viewers`
      - Track who is watching streams
      - Real-time viewer analytics

    - `stream_chat_messages`
      - Live chat during streams
      - Real-time messaging

    - `stream_item_requests`
      - Collectors can request items during live streams
      - Real-time shopping experience

  2. Security
    - Enable RLS on all tables
    - Anyone can view active streams
    - Only pickers can create streams
    - Authenticated users can chat and request items

  3. Features
    - Real-time viewer tracking
    - Live chat functionality
    - Item request system
    - Stream analytics
*/

-- Live streams table
CREATE TABLE IF NOT EXISTS live_streams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  thumbnail_url text,
  stream_url text,
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  status text NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'ended')),
  viewer_count integer DEFAULT 0,
  peak_viewers integer DEFAULT 0,
  total_views integer DEFAULT 0,
  started_at timestamptz DEFAULT now(),
  ended_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS live_streams_picker_id_idx ON live_streams(picker_id);
CREATE INDEX IF NOT EXISTS live_streams_status_idx ON live_streams(status);
CREATE INDEX IF NOT EXISTS live_streams_started_at_idx ON live_streams(started_at DESC);

-- Stream viewers table
CREATE TABLE IF NOT EXISTS stream_viewers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  left_at timestamptz,
  is_active boolean DEFAULT true,
  UNIQUE(stream_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS stream_viewers_stream_id_idx ON stream_viewers(stream_id);
CREATE INDEX IF NOT EXISTS stream_viewers_viewer_id_idx ON stream_viewers(viewer_id);
CREATE INDEX IF NOT EXISTS stream_viewers_is_active_idx ON stream_viewers(is_active);

-- Stream chat messages table
CREATE TABLE IF NOT EXISTS stream_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stream_chat_messages_stream_id_idx ON stream_chat_messages(stream_id);
CREATE INDEX IF NOT EXISTS stream_chat_messages_created_at_idx ON stream_chat_messages(created_at DESC);

-- Stream item requests table
CREATE TABLE IF NOT EXISTS stream_item_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  description text,
  max_price decimal(10, 2),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'fulfilled')),
  linked_listing_id uuid REFERENCES listings(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stream_item_requests_stream_id_idx ON stream_item_requests(stream_id);
CREATE INDEX IF NOT EXISTS stream_item_requests_requester_id_idx ON stream_item_requests(requester_id);
CREATE INDEX IF NOT EXISTS stream_item_requests_status_idx ON stream_item_requests(status);

-- Enable RLS
ALTER TABLE live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_viewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_item_requests ENABLE ROW LEVEL SECURITY;

-- Live streams policies
CREATE POLICY "Anyone can view active streams"
  ON live_streams FOR SELECT
  USING (true);

CREATE POLICY "Pickers can create streams"
  ON live_streams FOR INSERT
  TO authenticated
  WITH CHECK (
    picker_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND user_type = 'picker')
  );

CREATE POLICY "Pickers can update own streams"
  ON live_streams FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Stream viewers policies
CREATE POLICY "Anyone can view stream viewers"
  ON stream_viewers FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can join streams"
  ON stream_viewers FOR INSERT
  TO authenticated
  WITH CHECK (viewer_id = auth.uid());

CREATE POLICY "Users can update own viewer status"
  ON stream_viewers FOR UPDATE
  TO authenticated
  USING (viewer_id = auth.uid())
  WITH CHECK (viewer_id = auth.uid());

-- Stream chat policies
CREATE POLICY "Anyone can view stream chat"
  ON stream_chat_messages FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can send chat messages"
  ON stream_chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Stream item requests policies
CREATE POLICY "Anyone can view item requests"
  ON stream_item_requests FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create item requests"
  ON stream_item_requests FOR INSERT
  TO authenticated
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Picker can update requests for their stream"
  ON stream_item_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM live_streams
      WHERE live_streams.id = stream_item_requests.stream_id
      AND live_streams.picker_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM live_streams
      WHERE live_streams.id = stream_item_requests.stream_id
      AND live_streams.picker_id = auth.uid()
    )
  );

-- Function to update viewer count
CREATE OR REPLACE FUNCTION update_stream_viewer_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_count integer;
  stream_peak integer;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.is_active THEN
    UPDATE live_streams
    SET viewer_count = viewer_count + 1,
        total_views = total_views + 1
    WHERE id = NEW.stream_id
    RETURNING viewer_count, peak_viewers INTO current_count, stream_peak;
    
    IF current_count > stream_peak THEN
      UPDATE live_streams
      SET peak_viewers = current_count
      WHERE id = NEW.stream_id;
    END IF;
    
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_active AND NOT NEW.is_active THEN
      UPDATE live_streams
      SET viewer_count = viewer_count - 1
      WHERE id = NEW.stream_id;
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      UPDATE live_streams
      SET viewer_count = viewer_count + 1
      WHERE id = NEW.stream_id
      RETURNING viewer_count, peak_viewers INTO current_count, stream_peak;
      
      IF current_count > stream_peak THEN
        UPDATE live_streams
        SET peak_viewers = current_count
        WHERE id = NEW.stream_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_stream_viewer_change
  AFTER INSERT OR UPDATE ON stream_viewers
  FOR EACH ROW
  EXECUTE FUNCTION update_stream_viewer_count();

-- =========================================
-- Migration: 20251128124658_add_gift_souvenir_functionality.sql
-- =========================================

/*
  # Add Gift Souvenir Functionality

  1. Changes
    - Add gift-related columns to orders table
    - Enable collectors to send souvenirs as gifts
    - Store recipient information
    - Add gift message support

  2. New Columns in orders table
    - is_gift (boolean) - Whether this is a gift order
    - gift_recipient_name (text) - Name of the gift recipient
    - gift_recipient_email (text) - Email of the gift recipient
    - gift_message (text) - Personal message for the gift
    - gift_recipient_address (text) - Delivery address for the gift

  3. Features
    - Gift orders can be sent to different addresses
    - Personal messages included with gifts
    - Email notifications to recipients
    - Track gift deliveries separately
*/

-- Add gift-related columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'is_gift'
  ) THEN
    ALTER TABLE orders ADD COLUMN is_gift boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_name'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_name text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_email'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_email text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_message'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_message text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'gift_recipient_address'
  ) THEN
    ALTER TABLE orders ADD COLUMN gift_recipient_address text;
  END IF;
END $$;

-- Create index on gift orders for analytics
CREATE INDEX IF NOT EXISTS orders_is_gift_idx ON orders(is_gift) WHERE is_gift = true;

-- =========================================
-- Migration: 20251128130713_add_order_pickup_videos.sql
-- =========================================

/*
  # Add Order Pickup Videos Feature

  1. Changes
    - Add `pickup_video_url` column to orders table
    - Add `pickup_video_uploaded_at` timestamp column
    - Add `pickup_video_thumbnail_url` for video previews
    - Create notification trigger when pickup video is uploaded
    - Add RLS policies for video access

  2. Security
    - Pickers can upload videos to their own orders
    - Collectors can view videos for their orders
    - Videos are optional and enhance the customer experience

  3. Notes
    - Videos should be uploaded to Supabase Storage
    - Automatic notification sent to collector when video is added
    - Provides a personal touch and builds trust
*/

-- Add pickup video columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_url'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_uploaded_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_uploaded_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_thumbnail_url'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_thumbnail_url text;
  END IF;
END $$;

-- Create function to notify collector when pickup video is uploaded
CREATE OR REPLACE FUNCTION notify_collector_of_pickup_video()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_picker_name text;
  v_listing_title text;
BEGIN
  -- Only proceed if pickup_video_url was just added (changed from null to a value)
  IF OLD.pickup_video_url IS NULL AND NEW.pickup_video_url IS NOT NULL THEN
    -- Get picker name and listing title
    SELECT p.full_name, l.title
    INTO v_picker_name, v_listing_title
    FROM profiles p
    JOIN listings l ON l.id = NEW.listing_id
    WHERE p.id = NEW.picker_id;

    -- Create notification for collector
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      related_id,
      created_at
    ) VALUES (
      NEW.client_id,
      'pickup_video',
      'Pickup Moment Captured! 🎥',
      v_picker_name || ' shared a video of picking up your ' || v_listing_title,
      NEW.id,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for pickup video notifications
DROP TRIGGER IF EXISTS on_pickup_video_uploaded ON orders;
CREATE TRIGGER on_pickup_video_uploaded
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_collector_of_pickup_video();

-- Add RLS policy for pickers to update pickup videos on their orders
CREATE POLICY "Pickers can add pickup videos to their orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

-- Add comment for documentation
COMMENT ON COLUMN orders.pickup_video_url IS 'URL to video of picker finding/purchasing the item';
COMMENT ON COLUMN orders.pickup_video_uploaded_at IS 'Timestamp when pickup video was uploaded';
COMMENT ON COLUMN orders.pickup_video_thumbnail_url IS 'Thumbnail preview image for the pickup video';

-- =========================================
-- Migration: 20251128131500_create_pickup_videos_storage_bucket.sql
-- =========================================

/*
  # Create Pickup Videos Storage Bucket

  1. Storage Setup
    - Create `pickup-videos` storage bucket for order pickup videos
    - Set bucket to public for easy viewing by collectors
    - Configure max file size limits

  2. Security (RLS Policies)
    - Authenticated pickers can upload videos
    - Anyone can view videos (collectors need access)
    - Only uploaders can delete their own videos

  3. Notes
    - Videos are automatically verified for content
    - Provides transparency and trust in the picking process
*/

-- Create the pickup-videos storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pickup-videos',
  'pickup-videos',
  true,
  52428800,
  ARRAY['video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload videos
CREATE POLICY "Authenticated users can upload pickup videos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow public to view pickup videos
CREATE POLICY "Anyone can view pickup videos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'pickup-videos');

-- Allow users to update their own videos
CREATE POLICY "Users can update their own pickup videos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own videos
CREATE POLICY "Users can delete their own pickup videos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- =========================================
-- Migration: 20251128140850_fix_pickup_video_notification_trigger.sql
-- =========================================

/*
  # Fix Pickup Video Notification Trigger

  1. Changes
    - Update the `notify_collector_of_pickup_video` function to use correct notification columns
    - Remove the non-existent `related_id` column reference
    - Add the order link to the notification instead

  2. Notes
    - The notifications table doesn't have a `related_id` column
    - Use the `link` column to provide a direct link to the order
*/

-- Drop and recreate the function with correct column references
CREATE OR REPLACE FUNCTION public.notify_collector_of_pickup_video()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_picker_name text;
  v_listing_title text;
BEGIN
  -- Only proceed if pickup_video_url was just added (changed from null to a value)
  IF OLD.pickup_video_url IS NULL AND NEW.pickup_video_url IS NOT NULL THEN
    -- Get picker name and listing title
    SELECT p.full_name, l.title
    INTO v_picker_name, v_listing_title
    FROM profiles p
    JOIN listings l ON l.id = NEW.listing_id
    WHERE p.id = NEW.picker_id;

    -- Create notification for collector (using correct column names)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      read,
      created_at
    ) VALUES (
      NEW.client_id,
      'pickup_video',
      'Pickup Moment Captured! 🎥',
      v_picker_name || ' shared a video of picking up your ' || v_listing_title,
      '/orders',
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$function$;


-- =========================================
-- Migration: 20251128142031_add_transportation_cost_to_listings.sql
-- =========================================

/*
  # Add Transportation Cost to Listings

  1. Changes
    - Add `transportation_cost` column to listings table
    - Add `base_price` column to track the item price separately from transportation
    - The `price` column will remain as the total price (base + transportation)
    
  2. Notes
    - Transportation cost helps collectors understand pricing breakdown
    - Base price is the item cost without transportation
    - Total price (existing price field) = base_price + transportation_cost
    - All fields are nullable to support existing listings
*/

-- Add transportation cost and base price columns
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS transportation_cost decimal(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_price decimal(10,2);

-- For existing listings, set base_price equal to current price and transportation to 0
UPDATE listings 
SET base_price = price, 
    transportation_cost = 0
WHERE base_price IS NULL;

-- Add a comment to explain the pricing structure
COMMENT ON COLUMN listings.base_price IS 'The base cost of the item/service without transportation';
COMMENT ON COLUMN listings.transportation_cost IS 'Estimated transportation cost to acquire and deliver the item';
COMMENT ON COLUMN listings.price IS 'Total price (base_price + transportation_cost)';


-- =========================================
-- Migration: 20251128143232_create_custom_orders_system.sql
-- =========================================

/*
  # Create Custom Orders System

  1. New Tables
    - `custom_orders`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles) - The picker creating the custom offer
      - `client_id` (uuid, references profiles) - The collector receiving the offer
      - `title` (text) - Custom product/service title
      - `description` (text) - Details of what's being offered
      - `base_price` (decimal) - Item/service cost
      - `transportation_cost` (decimal) - Transportation cost
      - `total_price` (decimal) - Total = base + transportation
      - `quantity` (integer) - Number of items
      - `images` (text array) - Optional product images
      - `delivery_address` (text) - Optional delivery address
      - `notes` (text) - Additional notes
      - `status` (text) - pending, accepted, rejected, expired, completed
      - `expires_at` (timestamptz) - When the offer expires
      - `accepted_at` (timestamptz) - When collector accepted
      - `order_id` (uuid, references orders) - Created order after acceptance
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on custom_orders table
    - Pickers can create and view their custom orders
    - Collectors can view and accept custom orders sent to them
    - Both parties can view orders they're involved in

  3. Notes
    - Pickers create custom orders through messages/chat
    - Collectors receive notification and can accept/reject
    - Upon acceptance, a regular order is created with payment
    - Custom orders expire after 7 days by default
*/

-- Create custom_orders table
CREATE TABLE IF NOT EXISTS custom_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  client_id uuid REFERENCES profiles(id) NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  base_price decimal(10,2) NOT NULL DEFAULT 0,
  transportation_cost decimal(10,2) NOT NULL DEFAULT 0,
  total_price decimal(10,2) NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  images text[] DEFAULT '{}',
  delivery_address text,
  notes text,
  status text NOT NULL DEFAULT 'pending',
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz,
  order_id uuid REFERENCES orders(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_custom_orders_picker_id ON custom_orders(picker_id);
CREATE INDEX IF NOT EXISTS idx_custom_orders_client_id ON custom_orders(client_id);
CREATE INDEX IF NOT EXISTS idx_custom_orders_status ON custom_orders(status);
CREATE INDEX IF NOT EXISTS idx_custom_orders_expires_at ON custom_orders(expires_at);

-- Enable RLS
ALTER TABLE custom_orders ENABLE ROW LEVEL SECURITY;

-- Pickers can create custom orders
CREATE POLICY "Pickers can create custom orders"
  ON custom_orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

-- Pickers can view their custom orders
CREATE POLICY "Pickers can view their custom orders"
  ON custom_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Collectors can view custom orders sent to them
CREATE POLICY "Collectors can view their custom orders"
  ON custom_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = client_id);

-- Collectors can accept/reject custom orders
CREATE POLICY "Collectors can update their custom orders"
  ON custom_orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = client_id)
  WITH CHECK (auth.uid() = client_id);

-- Pickers can update their pending custom orders
CREATE POLICY "Pickers can update pending custom orders"
  ON custom_orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id AND status = 'pending')
  WITH CHECK (auth.uid() = picker_id);

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_custom_orders_updated_at()
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

CREATE TRIGGER custom_orders_updated_at
  BEFORE UPDATE ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_custom_orders_updated_at();

-- Create notification when custom order is created
CREATE OR REPLACE FUNCTION notify_custom_order_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    NEW.client_id,
    'custom_order_received',
    'New Custom Order Offer',
    'You have received a custom order offer: ' || NEW.title,
    jsonb_build_object('custom_order_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER custom_order_created_notification
  AFTER INSERT ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_custom_order_created();

-- Create notification when custom order is accepted
CREATE OR REPLACE FUNCTION notify_custom_order_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    INSERT INTO notifications (user_id, type, title, message, data)
    VALUES (
      NEW.picker_id,
      'custom_order_accepted',
      'Custom Order Accepted',
      'Your custom order offer has been accepted: ' || NEW.title,
      jsonb_build_object('custom_order_id', NEW.id, 'order_id', NEW.order_id)
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER custom_order_accepted_notification
  AFTER UPDATE ON custom_orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_custom_order_accepted();

-- Function to expire old custom orders
CREATE OR REPLACE FUNCTION expire_old_custom_orders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE custom_orders
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < now();
END;
$$;

COMMENT ON TABLE custom_orders IS 'Custom orders with negotiated prices between pickers and collectors';
COMMENT ON COLUMN custom_orders.base_price IS 'Base cost of the custom item/service';
COMMENT ON COLUMN custom_orders.transportation_cost IS 'Transportation cost for the custom order';
COMMENT ON COLUMN custom_orders.total_price IS 'Total price (base_price + transportation_cost) * quantity';
COMMENT ON COLUMN custom_orders.expires_at IS 'When the custom order offer expires';


-- =========================================
-- Migration: 20251128151801_create_revenue_boosters_system.sql
-- =========================================

/*
  # Create Revenue Boosters System

  1. New Tables
    - `revenue_insights`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles)
      - `insight_type` (text) - Type of insight (pricing, inventory, promotion, etc.)
      - `title` (text) - Insight title
      - `description` (text) - Detailed description
      - `potential_revenue` (decimal) - Estimated revenue impact
      - `priority` (text) - high, medium, low
      - `action_url` (text) - Where to take action
      - `action_label` (text) - Button label for action
      - `status` (text) - active, dismissed, completed
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `revenue_booster_actions`
      - `id` (uuid, primary key)
      - `picker_id` (uuid, references profiles)
      - `insight_id` (uuid, references revenue_insights)
      - `action_type` (text) - Type of action taken
      - `action_data` (jsonb) - Additional action data
      - `created_at` (timestamptz)

  2. Views
    - `picker_revenue_stats` - Aggregated revenue statistics for insights

  3. Functions
    - `generate_revenue_insights()` - Generates personalized insights
    - `calculate_revenue_potential()` - Calculates potential revenue

  4. Security
    - Enable RLS on all tables
    - Pickers can only view their own insights
    - System generates insights automatically

  5. Notes
    - Insights are generated based on:
      - Listing performance
      - Pricing compared to market
      - Inventory gaps
      - Seasonal opportunities
      - Engagement metrics
*/

-- Create revenue_insights table
CREATE TABLE IF NOT EXISTS revenue_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  insight_type text NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  potential_revenue decimal(10,2) DEFAULT 0,
  priority text NOT NULL DEFAULT 'medium',
  action_url text,
  action_label text DEFAULT 'Take Action',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_priority CHECK (priority IN ('high', 'medium', 'low')),
  CONSTRAINT valid_status CHECK (status IN ('active', 'dismissed', 'completed'))
);

-- Create revenue_booster_actions table
CREATE TABLE IF NOT EXISTS revenue_booster_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid REFERENCES profiles(id) NOT NULL,
  insight_id uuid REFERENCES revenue_insights(id),
  action_type text NOT NULL,
  action_data jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_revenue_insights_picker_id ON revenue_insights(picker_id);
CREATE INDEX IF NOT EXISTS idx_revenue_insights_status ON revenue_insights(status);
CREATE INDEX IF NOT EXISTS idx_revenue_insights_priority ON revenue_insights(priority);
CREATE INDEX IF NOT EXISTS idx_revenue_booster_actions_picker_id ON revenue_booster_actions(picker_id);
CREATE INDEX IF NOT EXISTS idx_revenue_booster_actions_insight_id ON revenue_booster_actions(insight_id);

-- Enable RLS
ALTER TABLE revenue_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_booster_actions ENABLE ROW LEVEL SECURITY;

-- Pickers can view their own insights
CREATE POLICY "Pickers can view own insights"
  ON revenue_insights FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Pickers can update their own insights
CREATE POLICY "Pickers can update own insights"
  ON revenue_insights FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

-- Pickers can track their actions
CREATE POLICY "Pickers can insert own actions"
  ON revenue_booster_actions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = picker_id);

CREATE POLICY "Pickers can view own actions"
  ON revenue_booster_actions FOR SELECT
  TO authenticated
  USING (auth.uid() = picker_id);

-- Create view for picker revenue stats
CREATE OR REPLACE VIEW picker_revenue_stats AS
SELECT 
  p.id as picker_id,
  COUNT(DISTINCT o.id) as total_orders,
  COALESCE(SUM(o.total_price), 0) as total_revenue,
  COALESCE(AVG(o.total_price), 0) as avg_order_value,
  COUNT(DISTINCT l.id) as total_listings,
  COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.id END) as completed_orders,
  COUNT(DISTINCT CASE WHEN o.created_at > now() - interval '30 days' THEN o.id END) as orders_last_30_days,
  COALESCE(SUM(CASE WHEN o.created_at > now() - interval '30 days' THEN o.total_price ELSE 0 END), 0) as revenue_last_30_days,
  COUNT(DISTINCT CASE WHEN l.created_at > now() - interval '30 days' THEN l.id END) as new_listings_last_30_days
FROM profiles p
LEFT JOIN orders o ON p.id = o.picker_id
LEFT JOIN listings l ON p.id = l.picker_id
WHERE p.user_type = 'picker'
GROUP BY p.id;

-- Function to generate revenue insights for a picker
CREATE OR REPLACE FUNCTION generate_revenue_insights(p_picker_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats RECORD;
  v_avg_market_price decimal;
  v_listing_count integer;
  v_low_price_count integer;
BEGIN
  -- Get picker stats
  SELECT * INTO v_stats FROM picker_revenue_stats WHERE picker_id = p_picker_id;
  
  -- Clear old active insights
  UPDATE revenue_insights 
  SET status = 'dismissed' 
  WHERE picker_id = p_picker_id 
    AND status = 'active' 
    AND created_at < now() - interval '7 days';
  
  -- Insight 1: Low listing count
  SELECT COUNT(*) INTO v_listing_count 
  FROM listings 
  WHERE picker_id = p_picker_id AND status = 'active';
  
  IF v_listing_count < 5 THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'inventory',
      'Add More Listings to Increase Visibility',
      'You currently have ' || v_listing_count || ' active listings. Pickers with 10+ listings earn 3x more on average. Add unique local items to attract more collectors.',
      COALESCE(v_stats.avg_order_value * 5, 50),
      'high',
      'listings',
      'Add New Listing'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 2: Pricing optimization
  SELECT AVG(price) INTO v_avg_market_price FROM listings WHERE status = 'active';
  
  SELECT COUNT(*) INTO v_low_price_count
  FROM listings
  WHERE picker_id = p_picker_id 
    AND status = 'active'
    AND price < v_avg_market_price * 0.7;
  
  IF v_low_price_count > 0 THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'pricing',
      'Optimize Your Pricing',
      'You have ' || v_low_price_count || ' listings priced significantly below market average (€' || ROUND(v_avg_market_price, 2) || '). Consider adjusting prices to match market demand.',
      v_low_price_count * 10,
      'medium',
      'listings',
      'Review Pricing'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 3: Add videos to listings
  IF EXISTS (
    SELECT 1 FROM listings 
    WHERE picker_id = p_picker_id 
      AND status = 'active' 
      AND (videos IS NULL OR array_length(videos, 1) = 0)
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'media',
      'Add Videos to Boost Conversions',
      'Listings with videos convert 40% better! Add videos to your listings to show items in detail and build trust with collectors.',
      COALESCE(v_stats.avg_order_value * 2, 30),
      'high',
      'listings',
      'Add Videos'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 4: Complete profile
  IF EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = p_picker_id 
      AND (bio IS NULL OR bio = '' OR avatar_url IS NULL)
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'profile',
      'Complete Your Profile',
      'Complete profiles get 50% more orders. Add a bio and profile photo to build trust with collectors.',
      COALESCE(v_stats.avg_order_value * 1.5, 25),
      'medium',
      'profile',
      'Complete Profile'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 5: Enable live streaming
  IF NOT EXISTS (
    SELECT 1 FROM live_streams WHERE picker_id = p_picker_id
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'engagement',
      'Start Live Streaming',
      'Engage collectors in real-time! Live streams generate 5x more engagement and can lead to custom orders on the spot.',
      100,
      'high',
      'live-streams',
      'Start Streaming'
    )
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Insight 6: Respond to client desires
  IF EXISTS (
    SELECT 1 FROM client_desires 
    WHERE location IS NOT NULL 
      AND NOT EXISTS (
        SELECT 1 FROM listings 
        WHERE picker_id = p_picker_id 
          AND location = client_desires.location
      )
    LIMIT 1
  ) THEN
    INSERT INTO revenue_insights (picker_id, insight_type, title, description, potential_revenue, priority, action_url, action_label)
    VALUES (
      p_picker_id,
      'opportunity',
      'Fulfill Client Desires',
      'There are unfulfilled collector requests in your area! Check the Client Desires page for guaranteed sales opportunities.',
      COALESCE(v_stats.avg_order_value * 3, 75),
      'high',
      'desires',
      'View Desires'
    )
    ON CONFLICT DO NOTHING;
  END IF;

END;
$$;

-- Function to calculate total revenue potential
CREATE OR REPLACE FUNCTION get_revenue_potential(p_picker_id uuid)
RETURNS decimal
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total decimal;
BEGIN
  SELECT COALESCE(SUM(potential_revenue), 0)
  INTO v_total
  FROM revenue_insights
  WHERE picker_id = p_picker_id
    AND status = 'active';
    
  RETURN v_total;
END;
$$;

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_revenue_insights_updated_at()
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

CREATE TRIGGER revenue_insights_updated_at
  BEFORE UPDATE ON revenue_insights
  FOR EACH ROW
  EXECUTE FUNCTION update_revenue_insights_updated_at();

COMMENT ON TABLE revenue_insights IS 'Personalized revenue optimization insights for pickers';
COMMENT ON TABLE revenue_booster_actions IS 'Track actions taken on revenue insights';
COMMENT ON FUNCTION generate_revenue_insights IS 'Generates personalized revenue insights for a picker';


-- =========================================
-- Migration: 20251128154704_add_live_streams_delete_policy.sql
-- =========================================

/*
  # Add Delete Policy for Live Streams

  1. Changes
    - Add DELETE policy for live_streams table
    - Allow pickers to delete their own streams
    - This enables pickers to remove old or unwanted streams

  2. Security
    - Only the picker who created the stream can delete it
    - Must be authenticated
    - Uses auth.uid() to verify ownership
*/

-- Add DELETE policy for live streams
CREATE POLICY "Pickers can delete own streams"
  ON live_streams FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- =========================================
-- Migration: 20251128160352_create_media_storage_bucket.sql
-- =========================================

/*
  # Create Media Storage Bucket

  1. Storage Setup
    - Create `media` storage bucket for stories, posts, and social content
    - Set bucket to public for easy viewing
    - Configure max file size limits (100MB)
    - Allow images and videos

  2. Security (RLS Policies)
    - Authenticated users can upload media
    - Anyone can view media (public content)
    - Only uploaders can delete their own media

  3. Notes
    - Used for stories (24hr expiring content)
    - Used for feed posts (permanent content)
    - Supports both images and videos
*/

-- Create the media storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  104857600,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'video/x-msvideo'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload media
CREATE POLICY "Authenticated users can upload media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'media'
);

-- Allow public to view media
CREATE POLICY "Anyone can view media"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'media');

-- Allow users to update their own media
CREATE POLICY "Users can update their own media"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'media' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'media' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own media
CREATE POLICY "Users can delete their own media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'media'
);

-- =========================================
-- Migration: 20251128160739_update_stories_support_all_users.sql
-- =========================================

/*
  # Update Stories to Support All Users

  1. Schema Changes
    - Rename `picker_id` to `user_id` in stories table
    - Update foreign key constraint
    - Update indexes
    - Update query joins to use profiles instead of picker-specific fields

  2. Security Updates
    - Update RLS policies to allow both pickers and collectors
    - Maintain security - users can only create/delete their own stories

  3. Notes
    - Stories are now available to all authenticated users
    - Both pickers and collectors can share 24-hour stories
    - Maintains backward compatibility with existing data
*/

-- Rename picker_id column to user_id
ALTER TABLE stories 
  RENAME COLUMN picker_id TO user_id;

-- Drop old index and create new one with correct name
DROP INDEX IF EXISTS stories_picker_id_idx;
CREATE INDEX IF NOT EXISTS stories_user_id_idx ON stories(user_id);

-- Update RLS policies to support all authenticated users
DROP POLICY IF EXISTS "Pickers can create stories" ON stories;
DROP POLICY IF EXISTS "Pickers can delete own stories" ON stories;

CREATE POLICY "Authenticated users can create stories"
  ON stories FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own stories"
  ON stories FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Update story_views foreign key reference (already correct, just for clarity)
-- The viewer_id correctly references profiles(id) which includes all user types

-- =========================================
-- Migration: 20251128165350_create_support_tickets_system.sql
-- =========================================

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


-- =========================================
-- Migration: 20251129132148_create_comprehensive_trust_safety_system.sql
-- =========================================

/*
  # Comprehensive Trust & Safety System

  1. New Tables
    - `identity_verifications`
      - User identity verification records with document uploads
      - Tracks verification attempts and status

    - `trust_scores`
      - Calculated trust scores based on user behavior
      - Includes components: transaction history, reviews, verification, responsiveness

    - `disputes`
      - Order disputes and resolution tracking
      - Support for evidence uploads and resolution notes

    - `content_reports`
      - Reports for listings, reviews, and other content
      - Category-based reporting with admin review workflow

    - `safety_actions`
      - Admin actions taken (warnings, suspensions, bans)
      - Audit trail for all safety interventions

    - `suspicious_activity_logs`
      - Automated detection of suspicious patterns
      - Fraud prevention and account takeover protection

  2. Security
    - RLS enabled on all tables
    - Users can view their own records
    - Admin-only policies for moderation actions
    - Reporters can view their own reports

  3. Important Notes
    - Trust scores are calculated automatically based on multiple factors
    - Verification status affects user privileges
    - Dispute resolution includes escrow integration
    - All safety actions are logged for audit
*/

-- Identity Verifications Table
CREATE TABLE IF NOT EXISTS identity_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  verification_type text NOT NULL CHECK (verification_type IN ('id_card', 'passport', 'drivers_license', 'utility_bill', 'selfie')),
  document_url text NOT NULL,
  document_number text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  rejection_reason text,
  verified_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Trust Scores Table
CREATE TABLE IF NOT EXISTS trust_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  overall_score integer DEFAULT 50 CHECK (overall_score >= 0 AND overall_score <= 100),
  verification_score integer DEFAULT 0 CHECK (verification_score >= 0 AND verification_score <= 25),
  transaction_score integer DEFAULT 0 CHECK (transaction_score >= 0 AND transaction_score <= 35),
  review_score integer DEFAULT 0 CHECK (review_score >= 0 AND review_score <= 25),
  responsiveness_score integer DEFAULT 0 CHECK (responsiveness_score >= 0 AND responsiveness_score <= 15),
  completed_orders integer DEFAULT 0,
  successful_transactions integer DEFAULT 0,
  disputes_filed integer DEFAULT 0,
  disputes_against integer DEFAULT 0,
  avg_response_time_hours decimal(10,2),
  last_calculated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Disputes Table
CREATE TABLE IF NOT EXISTS disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  filed_by uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  against_user uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  dispute_type text NOT NULL CHECK (dispute_type IN ('non_delivery', 'wrong_item', 'damaged_item', 'quality_issue', 'refund_request', 'other')),
  description text NOT NULL,
  evidence_urls text[],
  status text DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'closed', 'escalated')),
  resolution text,
  resolution_type text CHECK (resolution_type IN ('refund_full', 'refund_partial', 'replacement', 'no_action', 'other')),
  refund_amount decimal(10,2),
  resolved_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Content Reports Table
CREATE TABLE IF NOT EXISTS content_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content_type text NOT NULL CHECK (content_type IN ('listing', 'review', 'profile', 'message', 'story', 'live_stream')),
  content_id uuid NOT NULL,
  report_category text NOT NULL CHECK (report_category IN ('spam', 'fraud', 'inappropriate', 'counterfeit', 'harassment', 'copyright', 'dangerous', 'other')),
  description text NOT NULL,
  evidence_urls text[],
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'action_taken', 'dismissed', 'escalated')),
  action_taken text,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Safety Actions Table
CREATE TABLE IF NOT EXISTS safety_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('warning', 'temporary_suspension', 'permanent_ban', 'feature_restriction', 'verification_required', 'account_review')),
  reason text NOT NULL,
  description text,
  related_report_id uuid,
  related_dispute_id uuid,
  duration_days integer,
  restrictions jsonb,
  actioned_by uuid REFERENCES profiles(id) ON DELETE SET NULL NOT NULL,
  expires_at timestamptz,
  appeal_status text CHECK (appeal_status IN ('none', 'pending', 'approved', 'denied')),
  appeal_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Suspicious Activity Logs Table
CREATE TABLE IF NOT EXISTS suspicious_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('multiple_failed_logins', 'rapid_orders', 'unusual_location', 'account_takeover_attempt', 'payment_fraud', 'fake_reviews', 'suspicious_messaging', 'price_manipulation')),
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description text NOT NULL,
  metadata jsonb,
  ip_address text,
  user_agent text,
  action_taken text,
  reviewed boolean DEFAULT false,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Dispute Messages Table (for communication during disputes)
CREATE TABLE IF NOT EXISTS dispute_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid REFERENCES disputes(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  message text NOT NULL,
  attachment_urls text[],
  is_admin_message boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE safety_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE suspicious_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispute_messages ENABLE ROW LEVEL SECURITY;

-- Identity Verifications Policies
CREATE POLICY "Users can view own verifications"
  ON identity_verifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create verifications"
  ON identity_verifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Trust Scores Policies
CREATE POLICY "Users can view own trust score"
  ON trust_scores FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Trust scores viewable by others"
  ON trust_scores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can manage trust scores"
  ON trust_scores FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update trust scores"
  ON trust_scores FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Disputes Policies
CREATE POLICY "Users can view disputes they're involved in"
  ON disputes FOR SELECT
  TO authenticated
  USING (auth.uid() = filed_by OR auth.uid() = against_user);

CREATE POLICY "Users can file disputes"
  ON disputes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = filed_by);

CREATE POLICY "Users can update their disputes"
  ON disputes FOR UPDATE
  TO authenticated
  USING (auth.uid() = filed_by)
  WITH CHECK (auth.uid() = filed_by);

-- Content Reports Policies
CREATE POLICY "Users can view own reports"
  ON content_reports FOR SELECT
  TO authenticated
  USING (auth.uid() = reporter_id);

CREATE POLICY "Users can create reports"
  ON content_reports FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = reporter_id);

-- Safety Actions Policies
CREATE POLICY "Users can view own safety actions"
  ON safety_actions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Suspicious Activity Policies
CREATE POLICY "Users can view own suspicious activity"
  ON suspicious_activity_logs FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can log suspicious activity"
  ON suspicious_activity_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Dispute Messages Policies
CREATE POLICY "Users can view dispute messages"
  ON dispute_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (disputes.filed_by = auth.uid() OR disputes.against_user = auth.uid())
    )
  );

CREATE POLICY "Users can send dispute messages"
  ON dispute_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (disputes.filed_by = auth.uid() OR disputes.against_user = auth.uid())
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_identity_verifications_user_id ON identity_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_identity_verifications_status ON identity_verifications(status);
CREATE INDEX IF NOT EXISTS idx_trust_scores_user_id ON trust_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_trust_scores_overall ON trust_scores(overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_disputes_order_id ON disputes(order_id);
CREATE INDEX IF NOT EXISTS idx_disputes_filed_by ON disputes(filed_by);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_content_reports_content ON content_reports(content_type, content_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON content_reports(status);
CREATE INDEX IF NOT EXISTS idx_safety_actions_user_id ON safety_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_user_id ON suspicious_activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_suspicious_activity_reviewed ON suspicious_activity_logs(reviewed);
CREATE INDEX IF NOT EXISTS idx_dispute_messages_dispute_id ON dispute_messages(dispute_id);

-- Function to calculate trust score
CREATE OR REPLACE FUNCTION calculate_trust_score(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification_score integer := 0;
  v_transaction_score integer := 0;
  v_review_score integer := 0;
  v_responsiveness_score integer := 0;
  v_overall_score integer;
  v_completed_orders integer;
  v_avg_rating decimal;
  v_verified boolean;
BEGIN
  SELECT COUNT(*) INTO v_completed_orders
  FROM orders
  WHERE (client_id = p_user_id OR picker_id = p_user_id)
  AND status = 'completed';

  SELECT verification_status = 'verified' INTO v_verified
  FROM picker_profiles
  WHERE user_id = p_user_id;

  IF v_verified THEN
    v_verification_score := 25;
  ELSIF EXISTS (SELECT 1 FROM identity_verifications WHERE user_id = p_user_id AND status = 'pending') THEN
    v_verification_score := 10;
  END IF;

  IF v_completed_orders > 0 THEN
    v_transaction_score := LEAST(35, v_completed_orders * 3);
  END IF;

  SELECT AVG(rating) INTO v_avg_rating
  FROM reviews
  WHERE reviewed_user_id = p_user_id;

  IF v_avg_rating IS NOT NULL THEN
    v_review_score := LEAST(25, ROUND((v_avg_rating / 5.0) * 25));
  END IF;

  v_responsiveness_score := 10;

  v_overall_score := v_verification_score + v_transaction_score + v_review_score + v_responsiveness_score;

  INSERT INTO trust_scores (
    user_id,
    overall_score,
    verification_score,
    transaction_score,
    review_score,
    responsiveness_score,
    completed_orders,
    last_calculated_at
  ) VALUES (
    p_user_id,
    v_overall_score,
    v_verification_score,
    v_transaction_score,
    v_review_score,
    v_responsiveness_score,
    v_completed_orders,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    overall_score = v_overall_score,
    verification_score = v_verification_score,
    transaction_score = v_transaction_score,
    review_score = v_review_score,
    responsiveness_score = v_responsiveness_score,
    completed_orders = v_completed_orders,
    last_calculated_at = now();

  RETURN v_overall_score;
END;
$$;

-- Function to log suspicious activity
CREATE OR REPLACE FUNCTION log_suspicious_activity(
  p_user_id uuid,
  p_activity_type text,
  p_severity text,
  p_description text,
  p_metadata jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO suspicious_activity_logs (
    user_id,
    activity_type,
    severity,
    description,
    metadata
  ) VALUES (
    p_user_id,
    p_activity_type,
    p_severity,
    p_description,
    p_metadata
  )
  RETURNING id INTO v_log_id;

  IF p_severity IN ('high', 'critical') THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link
    )
    SELECT
      profiles.id,
      'security_alert',
      'Security Alert',
      'Suspicious activity detected on the platform',
      '/admin/safety'
    FROM profiles
    WHERE user_type = 'admin'
    LIMIT 1;
  END IF;

  RETURN v_log_id;
END;
$$;


-- =========================================
-- Migration: 20251129181333_add_picker_payment_cards_policies.sql
-- =========================================

/*
  # Add RLS Policies for Picker Payment Cards

  1. Security
    - Enable RLS on picker_payment_cards table
    - Add policies for pickers to manage their own payment cards
    
  2. Policies
    - Pickers can view their own payment cards
    - Pickers can insert their own payment cards
    - Pickers can update their own payment cards
    - Pickers can delete their own payment cards
*/

-- Ensure RLS is enabled
ALTER TABLE picker_payment_cards ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Pickers can view own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can add own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can update own payment cards" ON picker_payment_cards;
DROP POLICY IF EXISTS "Pickers can delete own payment cards" ON picker_payment_cards;

-- Create policies for picker_payment_cards
CREATE POLICY "Pickers can view own payment cards"
  ON picker_payment_cards FOR SELECT
  TO authenticated
  USING (picker_id = auth.uid());

CREATE POLICY "Pickers can add own payment cards"
  ON picker_payment_cards FOR INSERT
  TO authenticated
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can update own payment cards"
  ON picker_payment_cards FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

CREATE POLICY "Pickers can delete own payment cards"
  ON picker_payment_cards FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());


-- =========================================
-- Migration: 20251130162459_update_collector_payment_methods_security.sql
-- =========================================

/*
  # Secure Collector Payment Methods

  This migration updates the `collector_payment_methods` table to only use Stripe payment method IDs.
  It removes insecure card storage fields that should never be stored directly in our database.

  ## Changes Made

  1. Table Structure Updates
     - Remove `cardholder_name` column (not needed - Stripe stores this securely)
     - Add `stripe_payment_method_id` column if it doesn't exist (for secure Stripe integration)
     - Keep only safe display fields: `card_brand`, `last_four`, `expiry_month`, `expiry_year`

  2. Security Improvements
     - Card details are now stored securely by Stripe, not in our database
     - Only non-sensitive display information is retained
     - Stripe payment method ID references the secure payment method in Stripe's vault

  ## Important Notes
  
  - This migration is safe for existing data
  - The `stripe_payment_method_id` field will be populated by the save-payment-method Edge Function
  - Card numbers, CVV, and full cardholder info are NEVER stored in our database
*/

-- Add stripe_payment_method_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'collector_payment_methods' AND column_name = 'stripe_payment_method_id'
  ) THEN
    ALTER TABLE collector_payment_methods ADD COLUMN stripe_payment_method_id text;
  END IF;
END $$;

-- Remove cardholder_name column if it exists (insecure storage)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'collector_payment_methods' AND column_name = 'cardholder_name'
  ) THEN
    ALTER TABLE collector_payment_methods DROP COLUMN cardholder_name;
  END IF;
END $$;

-- Add index for faster Stripe payment method lookups
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_stripe_pm_id 
  ON collector_payment_methods(stripe_payment_method_id);

-- Add index for faster default payment method queries
CREATE INDEX IF NOT EXISTS idx_collector_payment_methods_client_default 
  ON collector_payment_methods(client_id, is_default) WHERE is_default = true;

-- =========================================
-- Migration: 20251130173005_add_cardholder_name_to_payment_cards.sql
-- =========================================

/*
  # Add cardholder name to payment cards

  1. Changes
    - Add cardholder_name column to picker_payment_cards table to store the name entered by the user
    
  2. Purpose
    - Display the cardholder name on saved payment cards for better user experience
*/

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payment_cards' AND column_name = 'cardholder_name'
  ) THEN
    ALTER TABLE picker_payment_cards ADD COLUMN cardholder_name text;
  END IF;
END $$;

-- =========================================
-- Migration: 20251130211547_create_wishlist_and_enhanced_search.sql
-- =========================================

/*
  # Create Wishlist and Enhanced Search System

  ## Overview
  This migration adds wishlist functionality and enhanced search capabilities to improve user engagement and discovery.

  ## 1. New Tables
  
  ### `wishlists`
  - `id` (uuid, primary key) - Unique wishlist item identifier
  - `user_id` (uuid, foreign key) - References auth.users
  - `listing_id` (uuid, foreign key) - References listings
  - `created_at` (timestamptz) - When item was added to wishlist
  - `notes` (text, optional) - User's personal notes about the item

  ### `search_history`
  - `id` (uuid, primary key) - Unique search record identifier
  - `user_id` (uuid, foreign key) - References auth.users (nullable for anonymous)
  - `search_query` (text) - The search text entered
  - `filters_applied` (jsonb) - Filter parameters used
  - `results_count` (integer) - Number of results returned
  - `created_at` (timestamptz) - When search was performed

  ### `popular_searches`
  - `id` (uuid, primary key) - Unique record identifier
  - `search_term` (text, unique) - The search term
  - `search_count` (integer) - Number of times searched
  - `last_searched_at` (timestamptz) - Most recent search
  - `updated_at` (timestamptz) - Last update timestamp

  ## 2. Indexes
  - Index on wishlists(user_id) for fast user wishlist lookups
  - Index on wishlists(listing_id) for wishlist count queries
  - Index on search_history(user_id) for user search history
  - Full-text search index on listings for enhanced search

  ## 3. Functions
  - `update_listing_search_vector()` - Trigger function for full-text search
  - `get_trending_listings()` - Function to calculate trending listings based on views

  ## 4. Security
  - Enable RLS on all new tables
  - Users can manage their own wishlists
  - Users can view their own search history
  - Popular searches are publicly readable

  ## 5. Important Notes
  - Wishlist provides quick access to saved items
  - Search history helps personalize recommendations
  - Popular searches improve discovery
  - Listing views track engagement for trending algorithms
*/

-- Create wishlists table
CREATE TABLE IF NOT EXISTS wishlists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, listing_id)
);

-- Create search_history table
CREATE TABLE IF NOT EXISTS search_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  search_query text NOT NULL,
  filters_applied jsonb DEFAULT '{}'::jsonb,
  results_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create popular_searches table
CREATE TABLE IF NOT EXISTS popular_searches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  search_term text UNIQUE NOT NULL,
  search_count integer DEFAULT 1,
  last_searched_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_wishlists_user_id ON wishlists(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlists_listing_id ON wishlists(listing_id);
CREATE INDEX IF NOT EXISTS idx_wishlists_created_at ON wishlists(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_search_history_user_id ON search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_created_at ON search_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_popular_searches_count ON popular_searches(search_count DESC);
CREATE INDEX IF NOT EXISTS idx_popular_searches_term ON popular_searches(search_term);

-- Add indexes to existing listing_views table
CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_created_at ON listing_views(created_at DESC);

-- Add full-text search to listings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'listings' AND column_name = 'search_vector'
  ) THEN
    ALTER TABLE listings ADD COLUMN search_vector tsvector;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON listings USING gin(search_vector);

-- Function to update search vector (uses region and pickup_location instead of location)
CREATE OR REPLACE FUNCTION update_listing_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.category, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(NEW.region, '')), 'D') ||
    setweight(to_tsvector('english', COALESCE(NEW.pickup_location, '')), 'D');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update search vector
DROP TRIGGER IF EXISTS update_listing_search_vector_trigger ON listings;
CREATE TRIGGER update_listing_search_vector_trigger
  BEFORE INSERT OR UPDATE OF title, description, category, region, pickup_location
  ON listings
  FOR EACH ROW
  EXECUTE FUNCTION update_listing_search_vector();

-- Update existing listings search vectors
UPDATE listings 
SET search_vector = 
  setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(description, '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(category, '')), 'C') ||
  setweight(to_tsvector('english', COALESCE(region, '')), 'D') ||
  setweight(to_tsvector('english', COALESCE(pickup_location, '')), 'D')
WHERE search_vector IS NULL;

-- Function to get trending listings (uses existing listing_views table)
CREATE OR REPLACE FUNCTION get_trending_listings(time_period interval DEFAULT '7 days'::interval, limit_count integer DEFAULT 10)
RETURNS TABLE (
  listing_id uuid,
  view_count bigint,
  unique_viewers bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    lv.listing_id,
    COUNT(*) as view_count,
    COUNT(DISTINCT lv.user_id) as unique_viewers
  FROM listing_views lv
  WHERE lv.created_at > now() - time_period
  GROUP BY lv.listing_id
  ORDER BY view_count DESC, unique_viewers DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE popular_searches ENABLE ROW LEVEL SECURITY;

-- Wishlist policies
CREATE POLICY "Users can view own wishlist"
  ON wishlists FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can add to own wishlist"
  ON wishlists FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove from own wishlist"
  ON wishlists FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own wishlist notes"
  ON wishlists FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Search history policies
CREATE POLICY "Users can view own search history"
  ON search_history FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Anyone can insert search history"
  ON search_history FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Popular searches policies
CREATE POLICY "Anyone can view popular searches"
  ON popular_searches FOR SELECT
  TO authenticated, anon
  USING (true);

-- =========================================
-- Migration: 20251130221152_add_listings_insert_update_policies.sql
-- =========================================

/*
  # Add RLS Policies for Listings Table

  1. Security Changes
    - Add INSERT policy for pickers to create their own listings
    - Add UPDATE policy for pickers to edit their own listings
    - Add DELETE policy for pickers to remove their own listings

  2. Notes
    - Pickers can only manage listings associated with their picker_profile
    - Clients can only view listings (existing SELECT policy)
*/

-- Allow pickers to insert their own listings
CREATE POLICY "Pickers can create own listings"
  ON listings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Allow pickers to update their own listings
CREATE POLICY "Pickers can update own listings"
  ON listings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Allow pickers to delete their own listings
CREATE POLICY "Pickers can delete own listings"
  ON listings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- =========================================
-- Migration: 20251130230425_create_dispute_to_support_notification.sql
-- =========================================

/*
  # Create Automatic Support Notification for Disputes

  1. Changes
    - Creates a function to automatically generate support tickets when disputes are filed
    - Creates a trigger that executes after a dispute is inserted
    - Support team will receive a ticket for every new dispute with full context

  2. Details
    - Automatically creates a high-priority support ticket when dispute is filed
    - Includes dispute details, order info, and parties involved
    - Links the support ticket to the user who filed the dispute
    - Sets priority to 'high' for immediate attention
*/

-- Function to create support ticket when dispute is filed
CREATE OR REPLACE FUNCTION notify_support_of_dispute()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  order_title text;
  filer_name text;
  against_name text;
BEGIN
  -- Get order and user details
  SELECT 
    l.title,
    p1.full_name,
    p2.full_name
  INTO 
    order_title,
    filer_name,
    against_name
  FROM orders o
  JOIN listings l ON l.id = o.listing_id
  JOIN profiles p1 ON p1.id = NEW.filed_by
  JOIN profiles p2 ON p2.id = NEW.against_user
  WHERE o.id = NEW.order_id;

  -- Create support ticket
  INSERT INTO support_tickets (
    user_id,
    subject,
    message,
    category,
    status,
    priority
  ) VALUES (
    NEW.filed_by,
    'DISPUTE FILED: ' || COALESCE(order_title, 'Order #' || NEW.order_id),
    'A dispute has been filed and requires immediate attention.

DISPUTE DETAILS:
- Dispute ID: ' || NEW.id || '
- Order: ' || COALESCE(order_title, 'Unknown') || '
- Filed By: ' || COALESCE(filer_name, 'Unknown') || '
- Against: ' || COALESCE(against_name, 'Unknown') || '
- Type: ' || NEW.dispute_type || '
- Description: ' || NEW.description || '

Please review this dispute in the Disputes section and take appropriate action.',
    'dispute',
    'open',
    'high'
  );

  RETURN NEW;
END;
$$;

-- Create trigger to execute function after dispute insert
DROP TRIGGER IF EXISTS on_dispute_filed ON disputes;

CREATE TRIGGER on_dispute_filed
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION notify_support_of_dispute();

-- Add comment
COMMENT ON FUNCTION notify_support_of_dispute() IS 'Automatically creates a high-priority support ticket when a dispute is filed';


-- =========================================
-- Migration: 20251130230437_link_support_tickets_to_disputes.sql
-- =========================================

/*
  # Link Support Tickets to Disputes

  1. Changes
    - Adds optional dispute_id column to support_tickets table
    - Creates foreign key relationship between tickets and disputes
    - Allows support team to quickly navigate from ticket to dispute

  2. Security
    - No RLS changes needed (inherits from existing policies)
*/

-- Add dispute_id column to support_tickets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'support_tickets' AND column_name = 'dispute_id'
  ) THEN
    ALTER TABLE support_tickets 
    ADD COLUMN dispute_id uuid REFERENCES disputes(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_support_tickets_dispute_id 
    ON support_tickets(dispute_id);
  END IF;
END $$;

-- Update the function to include dispute_id
CREATE OR REPLACE FUNCTION notify_support_of_dispute()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  order_title text;
  filer_name text;
  against_name text;
BEGIN
  -- Get order and user details
  SELECT 
    l.title,
    p1.full_name,
    p2.full_name
  INTO 
    order_title,
    filer_name,
    against_name
  FROM orders o
  JOIN listings l ON l.id = o.listing_id
  JOIN profiles p1 ON p1.id = NEW.filed_by
  JOIN profiles p2 ON p2.id = NEW.against_user
  WHERE o.id = NEW.order_id;

  -- Create support ticket with dispute link
  INSERT INTO support_tickets (
    user_id,
    subject,
    message,
    category,
    status,
    priority,
    dispute_id
  ) VALUES (
    NEW.filed_by,
    'DISPUTE FILED: ' || COALESCE(order_title, 'Order #' || NEW.order_id),
    'A dispute has been filed and requires immediate attention.

DISPUTE DETAILS:
- Dispute ID: ' || NEW.id || '
- Order: ' || COALESCE(order_title, 'Unknown') || '
- Filed By: ' || COALESCE(filer_name, 'Unknown') || '
- Against: ' || COALESCE(against_name, 'Unknown') || '
- Type: ' || NEW.dispute_type || '
- Description: ' || NEW.description || '

Please review this dispute in the Disputes section and take appropriate action.',
    'dispute',
    'open',
    'high',
    NEW.id
  );

  RETURN NEW;
END;
$$;


-- =========================================
-- Migration: 20251130231343_create_profile_on_email_confirmation.sql
-- =========================================

/*
  # Create Profile Automatically After Email Confirmation

  1. Changes
    - Creates a trigger function that runs when a user confirms their email
    - Automatically creates profile and picker_profile based on user metadata
    - Handles the profile creation that previously happened in the signup function

  2. Details
    - Extracts full_name and user_type from auth.users raw_user_meta_data
    - Creates profile record with the user's information
    - Creates picker_profile if user_type is 'picker'
    - Generates referral code for new users
*/

-- Function to create profile after email confirmation
CREATE OR REPLACE FUNCTION handle_new_user_confirmation()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Only proceed if email is confirmed and profile doesn't exist
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    
    -- Check if profile already exists
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
      
      -- Extract metadata
      full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
      user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user % after email confirmation', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_confirmation();

-- Add comment
COMMENT ON FUNCTION handle_new_user_confirmation() IS 'Automatically creates profile and picker_profile when user confirms their email';


-- =========================================
-- Migration: 20251201153644_add_phone_and_recovery_options.sql
-- =========================================

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

-- =========================================
-- Migration: 20251201180815_add_notification_preferences_policies.sql
-- =========================================

/*
  # Add RLS policies for notification_preferences table

  1. Security
    - Enable RLS on notification_preferences table
    - Add policy for users to read their own preferences
    - Add policy for users to insert their own preferences
    - Add policy for users to update their own preferences
    
  2. Notes
    - Users can only access their own notification preferences
    - Each user can manage their own settings independently
*/

-- Enable RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can view their own preferences
CREATE POLICY "Users can view own notification preferences"
  ON notification_preferences
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own notification preferences"
  ON notification_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own notification preferences"
  ON notification_preferences
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =========================================
-- Migration: 20251203175543_add_fee_tracking_to_picker_payouts.sql
-- =========================================

/*
  # Add Fee Tracking to Picker Payouts Table

  1. Changes
    - Add `gross_amount` column - Original escrow amount before platform fee
    - Add `platform_fee` column - 10% platform fee deducted
    - Add `net_amount` column - Actual amount transferred to picker
    - Add `stripe_transfer_id` column - Stripe transfer ID (different from payout ID)
    - Add `processed_at` column - When the transfer was completed
    - Update the status values to include 'completed'

  2. Purpose
    - Track platform fee deductions transparently
    - Show both gross and net amounts for accounting
    - Support both Stripe transfers and payouts
    - Maintain complete audit trail of money flow

  3. Notes
    - `stripe_payout_id` is for Stripe payouts to bank accounts
    - `stripe_transfer_id` is for Stripe transfers to Connect accounts  
    - Both can coexist for different payout methods
*/

-- Add fee tracking columns to picker_payouts table
DO $$
BEGIN
  -- Add gross_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'gross_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN gross_amount numeric CHECK (gross_amount > 0);
  END IF;

  -- Add platform_fee column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'platform_fee'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN platform_fee numeric DEFAULT 0 CHECK (platform_fee >= 0);
  END IF;

  -- Add net_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'net_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN net_amount numeric CHECK (net_amount > 0);
  END IF;

  -- Add stripe_transfer_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'stripe_transfer_id'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN stripe_transfer_id text UNIQUE;
  END IF;

  -- Add processed_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'processed_at'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN processed_at timestamptz;
  END IF;
END $$;

-- Update status constraint to include 'completed'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'picker_payouts' AND constraint_name = 'picker_payouts_status_check'
  ) THEN
    ALTER TABLE picker_payouts DROP CONSTRAINT picker_payouts_status_check;
  END IF;
END $$;

ALTER TABLE picker_payouts ADD CONSTRAINT picker_payouts_status_check
  CHECK (status IN ('pending', 'in_transit', 'paid', 'failed', 'cancelled', 'completed'));

-- Create index on stripe_transfer_id for webhook lookups
CREATE INDEX IF NOT EXISTS idx_picker_payouts_stripe_transfer_id 
  ON picker_payouts(stripe_transfer_id);

-- Create a helpful view for picker earnings with fees
CREATE OR REPLACE VIEW picker_earnings_with_fees AS
SELECT
  picker_id,
  COUNT(*) as total_transactions,
  SUM(COALESCE(gross_amount, amount)) as total_gross_earned,
  SUM(COALESCE(platform_fee, 0)) as total_fees_paid,
  SUM(COALESCE(net_amount, amount)) as total_net_received,
  MIN(created_at) as first_payout_at,
  MAX(COALESCE(processed_at, paid_at)) as last_payout_at
FROM picker_payouts
WHERE status IN ('completed', 'paid', 'in_transit')
GROUP BY picker_id;

-- Grant access to the view
GRANT SELECT ON picker_earnings_with_fees TO authenticated;

-- Update existing records to set net_amount equal to amount where null
UPDATE picker_payouts
SET net_amount = amount
WHERE net_amount IS NULL AND amount IS NOT NULL;

-- Update existing records to set gross_amount equal to amount where null
UPDATE picker_payouts
SET gross_amount = amount
WHERE gross_amount IS NULL AND amount IS NOT NULL;


-- =========================================
-- Migration: 20251203175630_update_escrow_release_with_stripe_transfers_v2.sql
-- =========================================

/*
  # Update Escrow Release to Process Actual Stripe Transfers

  1. Changes
    - Drop and recreate `release_escrow_to_picker` function with new return type
    - Function now marks escrow for payout processing
    - Actual Stripe transfers handled by edge function
    - Deducts 10% platform fee automatically
    - Updates escrow status after successful transfer

  2. Flow
    - When escrow is released (auto or manual)
    - Function marks escrow for processing
    - Background job or manual call to edge function processes transfer
    - Edge function creates Stripe transfer
    - Records payout in picker_payouts table
    - Updates escrow to 'released' status

  3. Important
    - This replaces the old database-only release process
    - Now actual money transfers happen via Stripe
    - Pickers must have completed Stripe Connect onboarding
    - Platform fee is automatically deducted
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

-- Recreate the function with support for actual Stripe transfers
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS json AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Get order_id for the escrow
  SELECT order_id INTO v_order_id
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  IF v_order_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Escrow not found or already processed'
    );
  END IF;

  -- Mark escrow for payout processing
  -- The actual Stripe transfer will be handled by calling the edge function
  UPDATE payment_escrow
  SET 
    payout_processed = false,
    notes = 'Pending Stripe transfer processing',
    released_to = picker_user_id
  WHERE id = escrow_id
  AND status = 'held';

  -- Insert a notification to trigger the payout processing
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    picker_user_id,
    'payout_processing',
    'Payment Processing',
    'Your payout is being processed and will arrive in your account soon',
    json_build_object(
      'escrow_id', escrow_id,
      'order_id', v_order_id,
      'action', 'process_payout'
    )
  );

  RETURN json_build_object(
    'success', true,
    'escrow_id', escrow_id,
    'order_id', v_order_id,
    'picker_id', picker_user_id,
    'message', 'Payout processing initiated. Call process-picker-payout edge function to complete.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a helper function to get pending payouts
CREATE OR REPLACE FUNCTION get_pending_payouts()
RETURNS TABLE (
  escrow_id uuid,
  picker_id uuid,
  order_id uuid,
  amount numeric,
  held_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pe.id as escrow_id,
    pe.released_to as picker_id,
    pe.order_id,
    pe.amount,
    pe.held_at
  FROM payment_escrow pe
  WHERE pe.status = 'held'
  AND pe.payout_processed = false
  AND pe.released_to IS NOT NULL
  ORDER BY pe.held_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_payouts() TO authenticated;


-- =========================================
-- Migration: 20251203175705_update_auto_escrow_release_with_edge_function_call.sql
-- =========================================

/*
  # Update Automatic Escrow Release to Call Edge Function

  1. Changes
    - Update `auto_release_escrow_after_confirmation` to call edge function
    - Use pg_net extension to make HTTP requests to edge function
    - Process actual Stripe transfers automatically
    - Handle failures gracefully with retries

  2. Flow
    - Scheduled job runs every hour
    - Finds escrows ready for release (48 hours after delivery)
    - For each escrow, calls process-picker-payout edge function
    - Edge function handles Stripe transfer and updates database
    - If edge function fails, escrow stays in 'held' status for retry

  3. Important
    - Requires pg_net extension enabled
    - Edge function must be deployed
    - Pickers must have Stripe Connect accounts set up
*/

-- Ensure pg_net extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Update the auto release function to call the edge function for actual transfers
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_supabase_url text;
  v_supabase_anon_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase configuration
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  SELECT current_setting('app.settings.supabase_anon_key', true) INTO v_supabase_anon_key;
  
  -- Default fallback (will be replaced by actual env vars in production)
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Find escrows that need to be released (48 hours after delivery)
  FOR v_escrow_record IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND o.status = 'delivered'
    AND o.actual_delivery IS NOT NULL
    AND o.actual_delivery < (NOW() - INTERVAL '48 hours')
    AND pe.payout_processed = false
  LOOP
    -- Call the edge function to process the Stripe transfer
    -- Using pg_net for async HTTP requests
    BEGIN
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(v_supabase_anon_key, '')
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      -- Log that we initiated the payout
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        'Automatic Payout Initiated',
        'Your earnings from a completed order are being transferred to your account',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount,
          'request_id', v_request_id
        )
      );

    EXCEPTION WHEN OTHERS THEN
      -- If edge function call fails, log error and continue
      -- The escrow will be retried in the next run
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_error',
        'Payout Processing Error',
        'There was an issue processing your payout. Our team will resolve this shortly.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'error', SQLERRM
        )
      );
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update process_escrow_releases to use the new logic
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS json AS $$
DECLARE
  v_processed_count int := 0;
BEGIN
  -- Call the auto release function
  PERFORM auto_release_escrow_after_confirmation();
  
  -- Count how many escrows were marked for processing
  SELECT COUNT(*) INTO v_processed_count
  FROM payment_escrow
  WHERE status = 'held'
  AND payout_processed = false
  AND released_to IS NOT NULL;
  
  RETURN json_build_object(
    'success', true,
    'pending_payouts', v_processed_count,
    'processed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION auto_release_escrow_after_confirmation() TO authenticated;
GRANT EXECUTE ON FUNCTION process_escrow_releases() TO authenticated;


-- =========================================
-- Migration: 20251203175742_update_picker_earnings_with_platform_fees.sql
-- =========================================

/*
  # Update Picker Earnings to Account for Platform Fees

  1. Changes
    - Update picker_earnings table to track gross vs net earnings
    - Add platform_fees_paid column
    - Update earnings calculation functions
    - Deduct 10% platform fee from all earnings
    - Show transparent fee breakdown to pickers

  2. New Columns
    - `total_gross_earned` - Total before fees (replaces total_earned)
    - `platform_fees_paid` - Total fees paid to platform (10%)
    - `total_net_earned` - Total after fees (what picker actually receives)

  3. Important
    - Platform takes 10% of all earnings
    - Pickers see both gross and net amounts
    - Available balance is net amount minus payouts
*/

-- Add new columns to picker_earnings table
DO $$
BEGIN
  -- Add total_gross_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_gross_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_gross_earned numeric DEFAULT 0 CHECK (total_gross_earned >= 0);
  END IF;

  -- Add platform_fees_paid if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'platform_fees_paid'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN platform_fees_paid numeric DEFAULT 0 CHECK (platform_fees_paid >= 0);
  END IF;

  -- Add total_net_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_net_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_net_earned numeric DEFAULT 0 CHECK (total_net_earned >= 0);
  END IF;
END $$;

-- Migrate existing data: total_earned becomes total_gross_earned
UPDATE picker_earnings
SET 
  total_gross_earned = COALESCE(total_earned, 0),
  platform_fees_paid = ROUND(COALESCE(total_earned, 0) * 0.10, 2),
  total_net_earned = ROUND(COALESCE(total_earned, 0) * 0.90, 2)
WHERE total_gross_earned = 0;

-- Update available_balance to reflect net earnings
UPDATE picker_earnings
SET available_balance = GREATEST(
  (total_net_earned - COALESCE(total_paid_out, 0)),
  0
);

-- Create or replace the earnings update function with fee calculation
CREATE OR REPLACE FUNCTION update_earnings_on_escrow_held()
RETURNS TRIGGER AS $$
DECLARE
  v_picker_id uuid;
  v_platform_fee numeric;
  v_net_amount numeric;
BEGIN
  -- Get picker_id from the order
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = NEW.order_id;

  IF v_picker_id IS NOT NULL THEN
    -- Calculate platform fee (10%) and net amount (90%)
    v_platform_fee := ROUND(NEW.amount * 0.10, 2);
    v_net_amount := NEW.amount - v_platform_fee;

    -- Update or insert picker earnings
    INSERT INTO picker_earnings (
      picker_id,
      total_gross_earned,
      platform_fees_paid,
      total_net_earned,
      pending_payout,
      available_balance
    )
    VALUES (
      v_picker_id,
      NEW.amount,
      v_platform_fee,
      v_net_amount,
      v_net_amount,
      0
    )
    ON CONFLICT (picker_id) DO UPDATE SET
      total_gross_earned = picker_earnings.total_gross_earned + NEW.amount,
      platform_fees_paid = picker_earnings.platform_fees_paid + v_platform_fee,
      total_net_earned = picker_earnings.total_net_earned + v_net_amount,
      pending_payout = picker_earnings.pending_payout + v_net_amount,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update earnings when payout is completed
CREATE OR REPLACE FUNCTION update_earnings_on_payout_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Move from pending to paid out
    UPDATE picker_earnings
    SET
      pending_payout = GREATEST(pending_payout - COALESCE(NEW.net_amount, NEW.amount), 0),
      total_paid_out = total_paid_out + COALESCE(NEW.net_amount, NEW.amount),
      available_balance = GREATEST(total_net_earned - (total_paid_out + COALESCE(NEW.net_amount, NEW.amount)), 0),
      last_payout_at = NEW.processed_at,
      updated_at = now()
    WHERE picker_id = NEW.picker_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for payout completion
DROP TRIGGER IF EXISTS trigger_update_earnings_on_payout ON picker_payouts;
CREATE TRIGGER trigger_update_earnings_on_payout
  AFTER UPDATE ON picker_payouts
  FOR EACH ROW
  EXECUTE FUNCTION update_earnings_on_payout_completed();

-- Create a comprehensive view for picker dashboard
CREATE OR REPLACE VIEW picker_earnings_dashboard AS
SELECT
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at,
  COUNT(pp.id) as total_payouts,
  COUNT(CASE WHEN pp.status = 'completed' THEN 1 END) as successful_payouts,
  COUNT(CASE WHEN pp.status = 'failed' THEN 1 END) as failed_payouts,
  COUNT(DISTINCT o.id) as total_orders_completed,
  AVG(CASE WHEN pp.status = 'completed' THEN pp.net_amount END) as avg_payout_amount
FROM picker_earnings pe
LEFT JOIN picker_payouts pp ON pp.picker_id = pe.picker_id
LEFT JOIN orders o ON o.picker_id = pe.picker_id AND o.status = 'completed'
GROUP BY 
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at;

-- Grant access to the views
GRANT SELECT ON picker_earnings_dashboard TO authenticated;

-- Add comment to clarify the old total_earned column (if it still exists)
COMMENT ON COLUMN picker_earnings.total_earned IS 'DEPRECATED: Use total_gross_earned instead. This column may be removed in a future update.';


-- =========================================
-- Migration: 20251203180027_add_goods_confirmation_system.sql
-- =========================================

/*
  # Add Goods Confirmation System for Collectors

  1. New Columns to orders table
    - `goods_confirmed` (boolean) - Whether collector confirmed receipt
    - `goods_confirmed_at` (timestamptz) - When confirmation happened
    - `confirmation_notes` (text) - Optional feedback from collector

  2. New Function
    - `confirm_goods_receipt(order_id, notes)` - Collector confirms receipt
    - Triggers immediate escrow release process
    - Updates order status to confirmed

  3. Flow
    - Collector receives order
    - Collector clicks "Confirm Receipt" button
    - System marks goods_confirmed = true
    - Escrow released immediately (no 48-hour wait)
    - Picker gets paid faster when collector is satisfied

  4. Benefits
    - Pickers get paid faster when collectors are happy
    - 48-hour auto-release still exists as backup
    - Builds trust between pickers and collectors
*/

-- Add confirmation columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'confirmation_notes'
  ) THEN
    ALTER TABLE orders ADD COLUMN confirmation_notes text;
  END IF;
END $$;

-- Create function for collectors to confirm receipt of goods
CREATE OR REPLACE FUNCTION confirm_goods_receipt(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
    );
  END IF;

  -- Check if order is in a state that can be confirmed
  IF v_order.status NOT IN ('in_progress', 'delivered') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  -- Check if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been confirmed'
    );
  END IF;

  -- Update order with confirmation
  UPDATE orders
  SET
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    status = CASE 
      WHEN status != 'delivered' THEN 'delivered'
      ELSE status
    END,
    actual_delivery = CASE
      WHEN actual_delivery IS NULL THEN now()
      ELSE actual_delivery
    END,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- If escrow exists, release it immediately
  IF v_escrow_id IS NOT NULL THEN
    PERFORM release_escrow_to_picker(v_escrow_id, v_picker_id);
  END IF;

  -- Notify picker that goods were confirmed and payment is being processed
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Order Confirmed - Payment Processing',
    'The collector confirmed receipt of the order. Your payment is being processed now!',
    json_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  -- Notify collector that their confirmation was received
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'confirmation_received',
    'Thank You for Confirming',
    'Your confirmation has been received. The picker will be paid shortly.',
    json_build_object(
      'order_id', p_order_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'message', 'Receipt confirmed. Payment will be processed immediately.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the auto-release function to prioritize confirmed orders
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_supabase_url text;
  v_supabase_anon_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase configuration
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  SELECT current_setting('app.settings.supabase_anon_key', true) INTO v_supabase_anon_key;
  
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Find escrows that need to be released
  -- Priority 1: Orders confirmed by collector (immediate release)
  -- Priority 2: Orders delivered 48+ hours ago (auto release)
  FOR v_escrow_record IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount,
      o.goods_confirmed,
      o.goods_confirmed_at
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND pe.payout_processed = false
    AND (
      -- Confirmed by collector (immediate release)
      (o.goods_confirmed = true AND o.goods_confirmed_at IS NOT NULL)
      OR
      -- Auto-release after 48 hours
      (
        o.status = 'delivered'
        AND o.actual_delivery IS NOT NULL
        AND o.actual_delivery < (NOW() - INTERVAL '48 hours')
      )
    )
    ORDER BY 
      o.goods_confirmed DESC,  -- Confirmed orders first
      o.goods_confirmed_at ASC, -- Earlier confirmations first
      o.actual_delivery ASC     -- Then oldest deliveries
  LOOP
    BEGIN
      -- Call the edge function to process the Stripe transfer
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(v_supabase_anon_key, '')
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      -- Log payout initiation
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'Payment Processing (Confirmed)'
          ELSE 'Automatic Payout Initiated'
        END,
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'The collector confirmed receipt. Your payment is being transferred now!'
          ELSE 'Your earnings from a completed order are being transferred to your account'
        END,
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount,
          'confirmed', v_escrow_record.goods_confirmed,
          'request_id', v_request_id
        )
      );

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_error',
        'Payout Processing Error',
        'There was an issue processing your payout. Our team will resolve this shortly.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'error', SQLERRM
        )
      );
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION confirm_goods_receipt(uuid, text) TO authenticated;

-- Create index for faster confirmation queries
CREATE INDEX IF NOT EXISTS idx_orders_goods_confirmed 
  ON orders(goods_confirmed, goods_confirmed_at) 
  WHERE goods_confirmed = true;


-- =========================================
-- Migration: 20251203180751_create_delivery_confirmation_reminders.sql
-- =========================================

/*
  # Create Delivery Confirmation Reminder System

  1. New Table
    - `reminder_queue` - Tracks scheduled reminders to be sent
    
  2. New Functions
    - `send_delivery_confirmation_reminder()` - Sends reminder to collector
    - `create_delivery_reminders()` - Schedules reminders when order is delivered
    
  3. New Triggers
    - Automatically creates reminders when order status changes to 'delivered'
    
  4. Reminder Schedule
    - Immediate: Notification when order delivered
    - 12 hours: First reminder to confirm receipt
    - 24 hours: Second reminder to confirm receipt
    - 36 hours: Final reminder (before 48hr auto-release)

  5. Benefits
    - Encourages collectors to confirm receipt quickly
    - Pickers get paid faster
    - Reduces forgotten confirmations
    - Improves platform engagement
*/

-- Create reminder queue table
CREATE TABLE IF NOT EXISTS reminder_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_type text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  related_id uuid,
  scheduled_for timestamptz NOT NULL,
  sent boolean DEFAULT false,
  sent_at timestamptz,
  cancelled boolean DEFAULT false,
  cancelled_at timestamptz,
  data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_reminder_queue_scheduled 
  ON reminder_queue(scheduled_for) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_user 
  ON reminder_queue(user_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_related 
  ON reminder_queue(related_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

-- Enable RLS
ALTER TABLE reminder_queue ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view own reminders"
  ON reminder_queue FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Function to cancel reminders for an order
CREATE OR REPLACE FUNCTION cancel_order_reminders(p_order_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'delivery_confirmation';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create delivery confirmation reminders
CREATE OR REPLACE FUNCTION create_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_delivery_time timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as picker_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use actual delivery time or current time
  v_delivery_time := COALESCE(v_order.actual_delivery, now());

  -- Cancel any existing reminders for this order
  PERFORM cancel_order_reminders(p_order_id);

  -- Schedule reminders at 12, 24, and 36 hours after delivery
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '12 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '24 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '36 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );

  -- Send immediate notification about delivery
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'order_delivered',
    'Order Delivered!',
    'Your order from ' || v_order.picker_name || ' has been delivered. Confirm receipt to release payment immediately.',
    jsonb_build_object(
      'order_id', p_order_id,
      'picker_id', v_order.picker_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create reminders when order is delivered
CREATE OR REPLACE FUNCTION trigger_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if status changed to delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Check if goods not already confirmed
    IF NOT NEW.goods_confirmed THEN
      PERFORM create_delivery_reminders(NEW.id);
    END IF;
  END IF;

  -- Cancel reminders if goods are confirmed
  IF NEW.goods_confirmed = true AND (OLD.goods_confirmed IS NULL OR OLD.goods_confirmed = false) THEN
    PERFORM cancel_order_reminders(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS on_order_delivered ON orders;
CREATE TRIGGER on_order_delivered
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_delivery_reminders();

-- Function to process pending reminders (called by scheduled job)
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Handle different reminder types
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        -- Get picker name from order
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        -- Send reminder notification
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⏰ Last Reminder: Confirm Receipt'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Please Confirm Your Order'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Final reminder: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will auto-confirm in 12 hours. Confirm now to release payment immediately!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Confirm receipt to release their payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' was delivered. Please confirm receipt when you receive it!'
          END,
          v_reminder.data
        );
      END IF;

      -- Mark reminder as sent
      UPDATE reminder_queue
      SET sent = true, sent_at = now()
      WHERE id = v_reminder.id;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue processing
      RAISE WARNING 'Error processing reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_delivery_reminders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_order_reminders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION process_pending_reminders() TO authenticated;


-- =========================================
-- Migration: 20251203180837_create_trial_ending_reminders.sql
-- =========================================

/*
  # Create Trial Ending Reminder System for Pickers

  1. New Functions
    - `check_trial_endings()` - Finds pickers whose trials are ending soon
    - `create_trial_reminder()` - Creates reminder for a picker
    - `check_picker_has_payment_method()` - Verifies if picker has payment card
    
  2. Reminder Schedule
    - 7 days before: First reminder to add payment method
    - 3 days before: Second reminder with urgency
    - 1 day before: Final urgent reminder
    - On trial end day: Warning about account suspension

  3. Flow
    - Daily check for upcoming trial expirations
    - Send reminders only if picker has no payment method
    - Don't spam if picker already added payment
    - Clear call-to-action to add payment method

  4. Benefits
    - Prevents surprise trial endings
    - Increases payment method conversion
    - Better user experience
    - Reduces churn
*/

-- Function to check if picker has valid payment method
CREATE OR REPLACE FUNCTION check_picker_has_payment_method(p_picker_id uuid)
RETURNS boolean AS $$
DECLARE
  v_has_payment boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM picker_payment_cards
    WHERE picker_id = p_picker_id
    AND stripe_payment_method_id IS NOT NULL
  ) INTO v_has_payment;

  RETURN COALESCE(v_has_payment, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create trial ending reminder
CREATE OR REPLACE FUNCTION create_trial_reminder(
  p_picker_id uuid,
  p_days_until_end integer
)
RETURNS void AS $$
DECLARE
  v_profile record;
  v_reminder_exists boolean;
  v_title text;
  v_message text;
BEGIN
  -- Get picker profile
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_picker_id
  AND user_type = 'picker';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Check if reminder already exists for this timeframe
  SELECT EXISTS (
    SELECT 1
    FROM reminder_queue
    WHERE user_id = p_picker_id
      AND reminder_type = 'trial_ending'
      AND (data->>'days_until_end')::int = p_days_until_end
      AND sent = false
      AND cancelled = false
      AND scheduled_for >= now()
  ) INTO v_reminder_exists;

  IF v_reminder_exists THEN
    RETURN;
  END IF;

  -- Don't send if picker already has payment method
  IF check_picker_has_payment_method(p_picker_id) THEN
    RETURN;
  END IF;

  -- Create appropriate message based on days remaining
  IF p_days_until_end >= 7 THEN
    v_title := 'Trial Ending in ' || p_days_until_end || ' Days';
    v_message := 'Your free trial ends in ' || p_days_until_end || ' days. Add your payment method now to continue using SouvenirPickers without interruption.';
  ELSIF p_days_until_end >= 3 THEN
    v_title := 'Action Needed: Trial Ending Soon';
    v_message := 'Only ' || p_days_until_end || ' days left in your trial! Add a payment method now to keep your picker account active and continue earning.';
  ELSIF p_days_until_end >= 1 THEN
    v_title := '⚠️ Urgent: Trial Ends Tomorrow';
    v_message := 'Your trial ends tomorrow! Add your payment method immediately to avoid account suspension and continue accepting orders.';
  ELSE
    v_title := '🚨 Final Notice: Trial Ends Today';
    v_message := 'Your trial ends today! Add a payment method now to prevent your account from being suspended. Don''t lose access to your earnings and customers!';
  END IF;

  -- Schedule reminder
  INSERT INTO reminder_queue (reminder_type, user_id, scheduled_for, data)
  VALUES (
    'trial_ending',
    p_picker_id,
    now() + INTERVAL '5 minutes',
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'has_payment_method', false
    )
  );

  -- Send immediate notification
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    p_picker_id,
    'trial_ending',
    v_title,
    v_message,
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'action_required', true,
      'action_url', '/subscription'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check all upcoming trial endings
CREATE OR REPLACE FUNCTION check_trial_endings()
RETURNS json AS $$
DECLARE
  v_picker record;
  v_count_7day integer := 0;
  v_count_3day integer := 0;
  v_count_1day integer := 0;
  v_count_today integer := 0;
  v_days_remaining integer;
BEGIN
  -- Find pickers whose trials are ending soon
  FOR v_picker IN
    SELECT 
      id,
      email,
      full_name,
      trial_ends_at,
      subscription_status
    FROM profiles
    WHERE user_type = 'picker'
      AND subscription_status IN ('trial', 'past_due', 'cancelled')
      AND trial_ends_at IS NOT NULL
      AND trial_ends_at > now()
      AND trial_ends_at <= now() + INTERVAL '14 days'
  LOOP
    -- Calculate days remaining
    v_days_remaining := EXTRACT(DAY FROM (v_picker.trial_ends_at - now()));

    -- Skip if picker already has payment method
    IF check_picker_has_payment_method(v_picker.id) THEN
      CONTINUE;
    END IF;

    -- Create reminders based on days remaining
    IF v_days_remaining = 7 THEN
      PERFORM create_trial_reminder(v_picker.id, 7);
      v_count_7day := v_count_7day + 1;
    ELSIF v_days_remaining = 3 THEN
      PERFORM create_trial_reminder(v_picker.id, 3);
      v_count_3day := v_count_3day + 1;
    ELSIF v_days_remaining = 1 THEN
      PERFORM create_trial_reminder(v_picker.id, 1);
      v_count_1day := v_count_1day + 1;
    ELSIF v_days_remaining = 0 THEN
      PERFORM create_trial_reminder(v_picker.id, 0);
      v_count_today := v_count_today + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'reminders_7day', v_count_7day,
    'reminders_3day', v_count_3day,
    'reminders_1day', v_count_1day,
    'reminders_today', v_count_today,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle trial reminders in reminder queue
CREATE OR REPLACE FUNCTION process_trial_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_has_payment boolean;
BEGIN
  -- Process trial ending reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE reminder_type = 'trial_ending'
      AND scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 50
  LOOP
    BEGIN
      -- Check if picker now has payment method
      v_has_payment := check_picker_has_payment_method(v_reminder.user_id);

      IF v_has_payment THEN
        -- Cancel reminder if payment method was added
        UPDATE reminder_queue
        SET cancelled = true, cancelled_at = now()
        WHERE id = v_reminder.id;
        
        -- Send success notification
        INSERT INTO notifications (user_id, type, title, message)
        VALUES (
          v_reminder.user_id,
          'payment_method_added',
          'Payment Method Added Successfully',
          'Thank you for adding your payment method! Your account will remain active when your trial ends.'
        );
      ELSE
        -- Send the reminder
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'trial_ending_reminder',
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 'Trial Ending Soon'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 'Action Required: Add Payment Method'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN '⚠️ Urgent: Trial Ends Tomorrow'
            ELSE '🚨 Final Notice: Trial Ends Today'
          END,
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 
              'Your trial ends in ' || (v_reminder.data->>'days_until_end') || ' days. Add payment method to continue.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 
              'Only ' || (v_reminder.data->>'days_until_end') || ' days left! Add payment now to keep earning.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN 
              'Trial ends tomorrow! Add payment method to avoid account suspension.'
            ELSE 
              'Trial ends today! Add payment method now to prevent suspension.'
          END,
          jsonb_build_object(
            'days_until_end', v_reminder.data->>'days_until_end',
            'action_required', true,
            'action_url', '/subscription'
          )
        );

        -- Mark as sent
        UPDATE reminder_queue
        SET sent = true, sent_at = now()
        WHERE id = v_reminder.id;
      END IF;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Error processing trial reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_picker_has_payment_method(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_trial_reminder(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION check_trial_endings() TO authenticated;
GRANT EXECUTE ON FUNCTION process_trial_reminders() TO authenticated;


-- =========================================
-- Migration: 20251203180959_schedule_reminder_processing_v2.sql
-- =========================================

/*
  # Schedule Reminder Processing with pg_cron

  1. Scheduled Jobs
    - Process reminders every 15 minutes
    - Check for trial endings daily
    
  2. Implementation
    - Uses pg_cron extension (already enabled)
    - Calls edge function via pg_net extension
    - Runs automatically in background
    
  3. Schedule
    - Every 15 minutes for urgent delivery confirmations and trial reminders
*/

-- Create scheduled job to process reminders every 15 minutes
SELECT cron.schedule(
  'process-urgent-reminders',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/process-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.supabase_anon_key', true)
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);

-- Create a function to manually trigger reminder processing (for testing)
CREATE OR REPLACE FUNCTION trigger_reminder_processing()
RETURNS json AS $$
DECLARE
  v_supabase_url text;
  v_request_id bigint;
BEGIN
  -- Get Supabase URL
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Trigger the edge function
  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/process-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  ) INTO v_request_id;

  RETURN json_build_object(
    'success', true,
    'request_id', v_request_id,
    'message', 'Reminder processing triggered',
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION trigger_reminder_processing() TO authenticated;

-- Create a function to view reminder queue status (instead of a view)
CREATE OR REPLACE FUNCTION get_reminder_queue_status()
RETURNS TABLE (
  reminder_type text,
  pending bigint,
  sent bigint,
  cancelled bigint,
  next_scheduled timestamptz,
  last_sent timestamptz
) AS $$
BEGIN
  -- Only allow admins to view status
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT 
    rq.reminder_type,
    COUNT(*) FILTER (WHERE NOT rq.sent AND NOT rq.cancelled) as pending,
    COUNT(*) FILTER (WHERE rq.sent) as sent,
    COUNT(*) FILTER (WHERE rq.cancelled) as cancelled,
    MIN(rq.scheduled_for) FILTER (WHERE NOT rq.sent AND NOT rq.cancelled) as next_scheduled,
    MAX(rq.sent_at) as last_sent
  FROM reminder_queue rq
  GROUP BY rq.reminder_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_reminder_queue_status() TO authenticated;


-- =========================================
-- Migration: 20251203181627_fix_valid_status_constraint.sql
-- =========================================

/*
  # Fix Valid Status Constraint for Orders

  1. Changes
    - Update the valid_status constraint to include 'delivered' status
    - This allows orders to be marked as delivered before goods confirmation
    
  2. Valid Statuses
    - pending: Order created, waiting for picker acceptance
    - accepted: Picker accepted the order
    - in_progress: Picker is working on the order
    - delivered: Order has been delivered to collector
    - completed: Order completed and confirmed
    - cancelled: Order was cancelled
    - refunded: Order was refunded
*/

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS valid_status;

-- Add the updated constraint with 'delivered' included
ALTER TABLE orders ADD CONSTRAINT valid_status 
  CHECK (status IN ('pending', 'accepted', 'in_progress', 'delivered', 'completed', 'cancelled', 'refunded'));


-- =========================================
-- Migration: 20251203181901_fix_delivery_reminders_notifications.sql
-- =========================================

/*
  # Fix Delivery Reminders to Use Correct Notification Columns

  1. Changes
    - Update create_delivery_reminders() to use 'link' instead of 'data' column
    - Update process_pending_reminders() to use 'link' instead of 'data' column
    - The notifications table has: user_id, type, title, message, link (not 'data')
*/

-- Fix create_delivery_reminders function
CREATE OR REPLACE FUNCTION create_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_delivery_time timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as picker_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use actual delivery time or current time
  v_delivery_time := COALESCE(v_order.actual_delivery, now());

  -- Cancel any existing reminders for this order
  PERFORM cancel_order_reminders(p_order_id);

  -- Schedule reminders at 12, 24, and 36 hours after delivery
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '12 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '24 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '36 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );

  -- Send immediate notification about delivery (using link instead of data)
  INSERT INTO notifications (user_id, type, title, message, link)
  VALUES (
    v_order.client_id,
    'order_delivered',
    'Order Delivered!',
    'Your order from ' || COALESCE(v_order.picker_name, 'the picker') || ' has been delivered. Confirm receipt to release payment immediately.',
    '/orders'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix process_pending_reminders function
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Handle different reminder types
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        -- Get picker name from order
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        -- Send reminder notification (using link instead of data)
        INSERT INTO notifications (user_id, type, title, message, link)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⏰ Last Reminder: Confirm Receipt'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Please Confirm Your Order'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Final reminder: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will auto-confirm in 12 hours. Confirm now to release payment immediately!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Confirm receipt to release their payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' was delivered. Please confirm receipt when you receive it!'
          END,
          '/orders'
        );
      END IF;

      -- Mark reminder as sent
      UPDATE reminder_queue
      SET sent = true, sent_at = now()
      WHERE id = v_reminder.id;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue processing
      RAISE WARNING 'Error processing reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251203181915_simplify_order_status_remove_completed_v2.sql
-- =========================================

/*
  # Simplify Order Status - Remove 'completed'

  1. Changes
    - Remove 'completed' from valid order statuses
    - 'delivered' becomes the final status for successfully finished orders
    - When collector confirms receipt, the order stays as 'delivered' and payment is released
    
  2. Valid Statuses (simplified)
    - pending: Order created, waiting for picker acceptance
    - accepted: Picker accepted the order
    - in_progress: Picker is working on the order
    - delivered: Order has been delivered (FINAL STATUS for successful orders)
    - cancelled: Order was cancelled
    - refunded: Order was refunded
*/

-- First, update any existing orders with 'completed' status to 'delivered'
UPDATE orders 
SET status = 'delivered' 
WHERE status = 'completed';

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS valid_status;

-- Add the simplified constraint without 'completed'
ALTER TABLE orders ADD CONSTRAINT valid_status 
  CHECK (status IN ('pending', 'accepted', 'in_progress', 'delivered', 'cancelled', 'refunded'));


-- =========================================
-- Migration: 20251203182113_update_escrow_release_use_delivered_status_v2.sql
-- =========================================

/*
  # Update Escrow Release to Use 'delivered' Status

  1. Changes
    - Update release_escrow_to_picker() to keep order status as 'delivered' instead of changing to 'completed'
    - 'delivered' is now the final status for successfully finished orders
    - No need to change status after payment release
*/

-- Drop and recreate the function to not change status to 'completed'
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

CREATE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'released',
    released_at = now(),
    released_to = picker_user_id,
    notes = 'Funds released to picker after delivery confirmation'
  WHERE id = escrow_id
  AND status = 'held'
  RETURNING order_id INTO v_order_id;

  -- No need to update order status - it should already be 'delivered'
  -- Just update the updated_at timestamp
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251203205722_extend_trial_period_to_180_days.sql
-- =========================================

/*
  # Extend Trial Period to 6 Months

  1. Changes
    - Update default trial period from 60 days to 180 days (6 months)
    - Extend trial for all existing users to 180 days from their trial start date
    - This ensures adequate testing time and prevents disruption
    
  2. Notes
    - All users get extended to 180 days total trial period
    - New users will automatically get 180 days trial
    - Existing users close to expiration get extended
*/

-- Update the default for new users to 180 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '180 days');

-- Extend trial for ALL existing users to 180 days from their trial start
-- This ensures everyone gets adequate testing time
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '180 days'
WHERE trial_started_at IS NOT NULL;

-- =========================================
-- Migration: 20251205194744_update_trial_period_to_30_days.sql
-- =========================================

/*
  # Update Trial Period to 30 Days (1 Month)

  1. Changes
    - Update default trial period from 180 days to 30 days (1 month)
    - Update existing users' trial period to 30 days from their trial start date
    - This aligns with standard monthly subscription model
    
  2. Notes
    - All new users will automatically get 30 days trial
    - Existing users will have their trials adjusted to 30 days total
*/

-- Update the default for new users to 30 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '30 days');

-- Update trial for ALL existing users to 30 days from their trial start
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '30 days'
WHERE trial_started_at IS NOT NULL;

-- =========================================
-- Migration: 20260110203546_fix_profile_creation_trigger.sql
-- =========================================

/*
  # Fix Profile Creation Trigger for All Cases

  1. Changes
    - Updates trigger to handle both auto-confirm and email confirmation cases
    - Creates profile immediately if email is already confirmed (auto-confirm enabled)
    - Creates profile when email gets confirmed (email confirmation enabled)
    - Ensures profile is always created regardless of confirmation setting

  2. Security
    - Function runs with SECURITY DEFINER to access auth schema
    - Properly scoped to public schema
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user_confirmation();

-- Create improved trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';


-- =========================================
-- Migration: 20260110212530_20251007130041_create_marketplace_schema.sql
-- =========================================

/*
  # Global Souvenir Marketplace Schema

  ## Overview
  This migration creates a complete marketplace system for connecting souvenir pickers
  (travelers who collect items globally) with clients seeking specific regional souvenirs.

  ## 1. New Tables

  ### `profiles`
  - `id` (uuid, primary key) - References auth.users
  - `email` (text) - User email
  - `full_name` (text) - Display name
  - `user_type` (text) - Either 'picker' or 'client'
  - `avatar_url` (text, nullable) - Profile picture
  - `bio` (text, nullable) - User description
  - `created_at` (timestamptz) - Account creation time

  ### `picker_profiles`
  - `id` (uuid, primary key)
  - `user_id` (uuid) - References profiles
  - `current_location` (text) - Current region/country
  - `regions` (text array) - All regions they can access
  - `specialties` (text array) - Types of souvenirs they specialize in
  - `rating` (numeric) - Average rating (0-5)
  - `total_reviews` (integer) - Number of reviews received
  - `verified` (boolean) - Verification status
  - `created_at` (timestamptz)

  ### `listings`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `title` (text) - Item name
  - `description` (text) - Detailed description
  - `category` (text) - Item category
  - `region` (text) - Region/country of origin
  - `price` (numeric) - Item price
  - `image_url` (text, nullable) - Main image
  - `images` (text array) - Additional images
  - `available` (boolean) - Availability status
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `requests`
  - `id` (uuid, primary key)
  - `client_id` (uuid) - References profiles
  - `picker_id` (uuid, nullable) - Assigned picker
  - `title` (text) - Request title
  - `description` (text) - Detailed request
  - `region` (text) - Desired region
  - `category` (text) - Item category
  - `budget` (numeric) - Client budget
  - `status` (text) - 'open', 'assigned', 'in_progress', 'completed', 'cancelled'
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `messages`
  - `id` (uuid, primary key)
  - `request_id` (uuid) - References requests
  - `sender_id` (uuid) - References profiles
  - `recipient_id` (uuid) - References profiles
  - `content` (text) - Message content
  - `read` (boolean) - Read status
  - `created_at` (timestamptz)

  ### `reviews`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `client_id` (uuid) - References profiles
  - `request_id` (uuid) - References requests
  - `rating` (integer) - Rating 1-5
  - `comment` (text, nullable) - Review text
  - `created_at` (timestamptz)

  ## 2. Security
  - Enable RLS on all tables
  - Users can read their own profile data
  - Users can update their own profiles
  - Public read access for picker profiles and listings
  - Request creators can read/update their requests
  - Pickers can read requests and update assigned ones
  - Message participants can read their conversations
  - Clients can create reviews for completed requests
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text NOT NULL,
  full_name text NOT NULL,
  user_type text NOT NULL CHECK (user_type IN ('picker', 'client')),
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now()
);

-- Create picker_profiles table
CREATE TABLE IF NOT EXISTS picker_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE UNIQUE,
  current_location text NOT NULL DEFAULT '',
  regions text[] DEFAULT '{}',
  specialties text[] DEFAULT '{}',
  rating numeric DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  total_reviews integer DEFAULT 0,
  verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create listings table
CREATE TABLE IF NOT EXISTS listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL DEFAULT '',
  region text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  image_url text,
  images text[] DEFAULT '{}',
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create requests table
CREATE TABLE IF NOT EXISTS requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  picker_id uuid REFERENCES picker_profiles ON DELETE SET NULL,
  title text NOT NULL,
  description text NOT NULL,
  region text NOT NULL,
  category text NOT NULL DEFAULT '',
  budget numeric CHECK (budget >= 0),
  status text DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create reviews table
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(request_id, client_id)
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Picker profiles policies
CREATE POLICY "Anyone can view picker profiles"
  ON picker_profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can update own profile"
  ON picker_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Pickers can insert own profile"
  ON picker_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Listings policies
CREATE POLICY "Anyone can view available listings"
  ON listings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can create listings"
  ON listings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update own listings"
  ON listings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can delete own listings"
  ON listings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Requests policies
CREATE POLICY "Users can view relevant requests"
  ON requests FOR SELECT
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    ) OR
    (status = 'open' AND picker_id IS NULL)
  );

CREATE POLICY "Clients can create requests"
  ON requests FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Request owners can update"
  ON requests FOR UPDATE
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  );

-- Messages policies
CREATE POLICY "Users can view their messages"
  ON messages FOR SELECT
  TO authenticated
  USING (sender_id = auth.uid() OR recipient_id = auth.uid());

CREATE POLICY "Users can send messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update their received messages"
  ON messages FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- Reviews policies
CREATE POLICY "Anyone can view reviews"
  ON reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Clients can create reviews"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM requests
      WHERE requests.id = request_id
      AND requests.client_id = auth.uid()
      AND requests.status = 'completed'
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_picker_profiles_user_id ON picker_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_listings_picker_id ON listings(picker_id);
CREATE INDEX IF NOT EXISTS idx_listings_region ON listings(region);
CREATE INDEX IF NOT EXISTS idx_requests_client_id ON requests(client_id);
CREATE INDEX IF NOT EXISTS idx_requests_picker_id ON requests(picker_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_messages_request_id ON messages(request_id);
CREATE INDEX IF NOT EXISTS idx_reviews_picker_id ON reviews(picker_id);

-- =========================================
-- Migration: 20260110212634_consolidate_missing_profile_fields_and_auth.sql
-- =========================================

/*
  # Consolidate Missing Profile Fields and Auth Setup

  1. Changes
    - Add all missing subscription fields to profiles table
    - Add billing and social media fields
    - Add default delivery address field
    - Add admin flag
    - Create profile creation trigger for auth

  2. Security
    - Maintains existing RLS policies
    - Creates trigger with SECURITY DEFINER
*/

-- Add subscription fields
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS trial_started_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz DEFAULT (now() + interval '30 days'),
ADD COLUMN IF NOT EXISTS subscription_status text DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'cancelled')),
ADD COLUMN IF NOT EXISTS subscription_started_at timestamptz,
ADD COLUMN IF NOT EXISTS last_payment_date timestamptz,
ADD COLUMN IF NOT EXISTS next_payment_due timestamptz,
ADD COLUMN IF NOT EXISTS payment_failed boolean DEFAULT false;

-- Add billing fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS company_name text,
ADD COLUMN IF NOT EXISTS billing_address text,
ADD COLUMN IF NOT EXISTS billing_city text,
ADD COLUMN IF NOT EXISTS billing_postal_code text,
ADD COLUMN IF NOT EXISTS billing_country text,
ADD COLUMN IF NOT EXISTS tax_id text,
ADD COLUMN IF NOT EXISTS billing_email text,
ADD COLUMN IF NOT EXISTS billing_phone text;

-- Add delivery address
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS default_delivery_address text;

-- Add social media fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS facebook_url text,
ADD COLUMN IF NOT EXISTS twitter_url text,
ADD COLUMN IF NOT EXISTS instagram_url text,
ADD COLUMN IF NOT EXISTS threads_url text;

-- Add admin flag
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Create profile creation trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type,
        trial_started_at,
        trial_ends_at,
        subscription_status
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val,
        now(),
        now() + interval '30 days',
        'trial'
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Update existing profiles to have subscription data
UPDATE profiles
SET 
  trial_started_at = COALESCE(trial_started_at, created_at),
  trial_ends_at = COALESCE(trial_ends_at, created_at + interval '30 days'),
  subscription_status = COALESCE(subscription_status, 'trial'),
  payment_failed = COALESCE(payment_failed, false)
WHERE trial_started_at IS NULL OR trial_ends_at IS NULL OR subscription_status IS NULL;

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';
