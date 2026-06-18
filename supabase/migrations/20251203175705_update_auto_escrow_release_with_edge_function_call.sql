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
