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
