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