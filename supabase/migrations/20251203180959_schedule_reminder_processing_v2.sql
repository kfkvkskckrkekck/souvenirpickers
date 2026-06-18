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
