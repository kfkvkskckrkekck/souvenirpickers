/*
  # Automatic Payout Cron Job (Backup System)
  
  1. Purpose
    - Process any escrows that are marked for payout but haven't been processed
    - Acts as backup if the webhook/edge function call fails
    - Ensures pickers always get paid
    
  2. Schedule
    - Runs every 5 minutes
    - Processes all escrows in 'processing' status
    
  3. Safety
    - Only processes escrows older than 2 minutes (avoids race conditions)
    - Idempotent - won't double-process
    - Logs all actions for monitoring
*/

-- Create a function to process pending payouts
CREATE OR REPLACE FUNCTION process_pending_payouts()
RETURNS void AS $$
DECLARE
  v_escrow record;
  v_request_id bigint;
  v_processed_count integer := 0;
BEGIN
  -- Find all escrows that need processing
  -- Only process if they've been in 'processing' state for at least 2 minutes
  FOR v_escrow IN
    SELECT 
      pe.id as escrow_id,
      pe.picker_id,
      pe.amount,
      pe.currency,
      o.id as order_id
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'processing'
    AND pe.released_at IS NOT NULL
    AND pe.released_at < NOW() - INTERVAL '2 minutes'
    AND pe.payout_id IS NULL
    ORDER BY pe.released_at ASC
    LIMIT 50
  LOOP
    BEGIN
      -- Call edge function to process the payout
      SELECT net.http_post(
        url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key', true)
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow.escrow_id,
          'pickerId', v_escrow.picker_id
        ),
        timeout_milliseconds := 10000
      ) INTO v_request_id;

      v_processed_count := v_processed_count + 1;
      
      RAISE NOTICE 'Processed payout for escrow % (request ID: %)', v_escrow.escrow_id, v_request_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to process payout for escrow %: %', v_escrow.escrow_id, SQLERRM;
    END;
  END LOOP;

  IF v_processed_count > 0 THEN
    RAISE NOTICE 'Processed % pending payouts', v_processed_count;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule the cron job to run every 5 minutes
SELECT cron.schedule(
  'process-pending-payouts',
  '*/5 * * * *',
  'SELECT process_pending_payouts();'
);

COMMENT ON FUNCTION process_pending_payouts() IS
  'Background job to process pending Stripe payouts - runs every 5 minutes as backup';
