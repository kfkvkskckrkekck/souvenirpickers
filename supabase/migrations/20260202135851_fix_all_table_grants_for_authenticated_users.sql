/*
  # Fix Table Grants for Authenticated Users

  1. Problem
    - Most tables have RLS policies but no grants for authenticated users
    - This causes "permission denied" errors throughout the app
    - The issue occurred after database schema updates
    
  2. Solution
    - Grant SELECT, INSERT, UPDATE, DELETE to authenticated users on all user-facing tables
    - RLS policies will still control actual access
    
  3. Security
    - Grants are safe because RLS policies control the actual data access
    - Without grants, users can't access tables even with proper RLS policies
*/

-- Grant permissions to authenticated users for all user-facing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON listings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON reviews TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON favorites TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON client_desires TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON cart_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON wishlist_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON client_payment_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON collector_payment_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_payment_cards TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_payment_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_payout_info TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_escrow TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_intents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON stripe_subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_subscription_payments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON referral_codes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON referral_rewards TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON followers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON social_posts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON stories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON likes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON comments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON live_streams TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON custom_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON invoices TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_tracking TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_status_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON refunds TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON disputes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON dispute_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON support_tickets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON support_ticket_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON reported_content TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON blocked_users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON identity_verifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON trust_scores TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON media_verifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON video_calls TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON analytics_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON page_views TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON picker_analytics TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON search_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON recommendations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON recommendation_interactions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON delivery_confirmation_reminders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON trial_ending_reminders TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON password_reset_requests TO authenticated;

-- Also grant usage on sequences so users can insert records
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
