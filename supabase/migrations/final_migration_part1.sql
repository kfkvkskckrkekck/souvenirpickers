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
