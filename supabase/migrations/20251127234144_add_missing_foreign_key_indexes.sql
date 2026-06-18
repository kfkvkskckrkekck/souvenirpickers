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