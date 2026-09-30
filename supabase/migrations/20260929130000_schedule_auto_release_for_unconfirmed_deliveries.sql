SELECT cron.schedule(
  'auto-release-unconfirmed-deliveries',
  '0 20 * * *',
  'SELECT process_auto_release_orders();'
);