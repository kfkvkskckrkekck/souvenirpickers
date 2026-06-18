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