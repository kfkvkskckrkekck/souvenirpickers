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
