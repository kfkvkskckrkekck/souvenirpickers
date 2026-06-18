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
