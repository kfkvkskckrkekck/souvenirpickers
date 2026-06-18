-- ================================================
-- PAYOUT SYSTEM VERIFICATION SCRIPT
-- ================================================
-- Run these queries in Supabase SQL Editor to verify
-- the payout system is correctly configured
-- ================================================

-- 1. CHECK PICKER PAYOUT INFORMATION
-- Shows all pickers with saved payout info
SELECT
  p.id,
  p.full_name,
  p.email,
  p.user_type,
  p.stripe_account_id,
  ppi.bank_name,
  ppi.bank_account_name,
  ppi.bank_account_last4,
  ppi.country,
  ppi.currency,
  ppi.created_at as payout_info_created,
  ppi.updated_at as payout_info_updated
FROM profiles p
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
WHERE p.user_type = 'picker'
ORDER BY ppi.created_at DESC;

-- 2. CHECK STRIPE VALIDATION STATUS
-- Shows which accounts have been validated (have last4)
SELECT
  p.full_name,
  p.email,
  ppi.bank_name,
  ppi.bank_account_last4,
  CASE
    WHEN ppi.bank_account_last4 IS NOT NULL THEN 'Validated by Stripe'
    WHEN ppi.bank_account_number IS NOT NULL THEN 'Not validated (old entry)'
    ELSE 'No bank account'
  END as validation_status,
  ppi.created_at
FROM profiles p
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
WHERE p.user_type = 'picker'
ORDER BY ppi.created_at DESC;

-- 3. CHECK STRIPE CONNECT STATUS
-- Shows which pickers have completed Stripe Connect
SELECT
  p.full_name,
  p.email,
  p.stripe_account_id,
  ppi.bank_account_last4,
  CASE
    WHEN p.stripe_account_id IS NOT NULL AND ppi.bank_account_last4 IS NOT NULL THEN 'Fully Setup'
    WHEN p.stripe_account_id IS NOT NULL THEN 'Stripe Connected (no bank validated)'
    WHEN ppi.bank_account_last4 IS NOT NULL THEN 'Bank Validated (no Stripe Connect)'
    ELSE 'Not Setup'
  END as setup_status
FROM profiles p
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
WHERE p.user_type = 'picker'
ORDER BY p.created_at DESC;

-- 4. CHECK PENDING ORDERS READY FOR PAYOUT
-- Orders that are delivered and waiting for escrow release
SELECT
  o.id,
  o.order_number,
  o.status,
  o.total_amount,
  o.goods_confirmed_at,
  o.goods_confirmed_by_collector,
  p.full_name as picker_name,
  p.email as picker_email,
  ppi.bank_account_last4,
  prof_collector.full_name as collector_name,
  CASE
    WHEN o.goods_confirmed_at IS NULL THEN 'Waiting for delivery confirmation'
    WHEN o.goods_confirmed_at + interval '48 hours' > NOW() THEN 'In 48-hour hold period'
    ELSE 'Ready for payout'
  END as payout_status,
  CASE
    WHEN o.goods_confirmed_at IS NOT NULL THEN
      EXTRACT(EPOCH FROM (o.goods_confirmed_at + interval '48 hours' - NOW())) / 3600
    ELSE NULL
  END as hours_until_payout
FROM orders o
JOIN profiles p ON o.picker_id = p.id
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
LEFT JOIN profiles prof_collector ON o.collector_id = prof_collector.id
WHERE o.status = 'delivered'
  AND o.goods_confirmed_by_collector = true
ORDER BY o.goods_confirmed_at DESC;

-- 5. CHECK PICKER EARNINGS RECORDS
-- All payouts that have been processed or are pending
SELECT
  pe.id,
  p.full_name,
  p.email,
  pe.amount,
  pe.platform_fee,
  pe.stripe_transfer_id,
  pe.status,
  pe.payout_date,
  pe.created_at,
  o.order_number
FROM picker_earnings pe
JOIN profiles p ON pe.picker_id = p.id
LEFT JOIN orders o ON pe.order_id = o.id
ORDER BY pe.created_at DESC
LIMIT 50;

-- 6. CHECK FAILED PAYOUTS
-- Any payouts that failed to process
SELECT
  pe.id,
  p.full_name,
  p.email,
  pe.amount,
  pe.status,
  pe.error_message,
  pe.created_at,
  ppi.bank_account_last4,
  prof.stripe_account_id
FROM picker_earnings pe
JOIN profiles p ON pe.picker_id = p.id
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
LEFT JOIN profiles prof ON prof.id = p.id
WHERE pe.status = 'failed'
ORDER BY pe.created_at DESC;

-- 7. PAYOUT STATISTICS BY PICKER
-- Summary of earnings per picker
SELECT
  p.full_name,
  p.email,
  COUNT(pe.id) as total_payouts,
  SUM(pe.amount) as total_earned,
  SUM(pe.platform_fee) as total_fees,
  SUM(pe.amount) - SUM(pe.platform_fee) as net_earnings,
  MIN(pe.created_at) as first_payout,
  MAX(pe.created_at) as last_payout,
  COUNT(CASE WHEN pe.status = 'paid' THEN 1 END) as successful_payouts,
  COUNT(CASE WHEN pe.status = 'pending' THEN 1 END) as pending_payouts,
  COUNT(CASE WHEN pe.status = 'failed' THEN 1 END) as failed_payouts
FROM profiles p
LEFT JOIN picker_earnings pe ON pe.picker_id = p.id
WHERE p.user_type = 'picker'
GROUP BY p.id, p.full_name, p.email
HAVING COUNT(pe.id) > 0
ORDER BY total_earned DESC;

-- 8. PLATFORM REVENUE SUMMARY
-- Total platform fees collected
SELECT
  COUNT(DISTINCT picker_id) as total_pickers_paid,
  COUNT(*) as total_payouts,
  SUM(amount) as total_paid_out,
  SUM(platform_fee) as total_platform_fees,
  ROUND(AVG(platform_fee)::numeric, 2) as avg_platform_fee,
  MIN(created_at) as first_payout_date,
  MAX(created_at) as last_payout_date
FROM picker_earnings
WHERE status = 'paid';

-- 9. RECENT VALIDATION ACTIVITY
-- Recent bank account validations
SELECT
  p.full_name,
  p.email,
  ppi.bank_name,
  ppi.bank_account_last4,
  ppi.country,
  ppi.currency,
  ppi.created_at as validated_at,
  EXTRACT(EPOCH FROM (NOW() - ppi.created_at)) / 3600 as hours_ago
FROM picker_payout_info ppi
JOIN profiles p ON ppi.picker_id = p.id
WHERE ppi.bank_account_last4 IS NOT NULL
ORDER BY ppi.created_at DESC
LIMIT 20;

-- 10. INCOMPLETE SETUPS
-- Pickers who started but didn't finish setup
SELECT
  p.full_name,
  p.email,
  CASE
    WHEN ppi.picker_id IS NULL THEN 'No bank account added'
    WHEN ppi.bank_account_last4 IS NULL THEN 'Bank not validated'
    WHEN p.stripe_account_id IS NULL THEN 'Stripe Connect not completed'
    ELSE 'Setup complete'
  END as missing_step,
  p.created_at as picker_joined,
  ppi.created_at as bank_added
FROM profiles p
LEFT JOIN picker_payout_info ppi ON ppi.picker_id = p.id
WHERE p.user_type = 'picker'
  AND (
    ppi.picker_id IS NULL
    OR ppi.bank_account_last4 IS NULL
    OR p.stripe_account_id IS NULL
  )
ORDER BY p.created_at DESC;

-- 11. TEST MANUAL ESCROW RELEASE
-- Use this to manually trigger escrow release (careful in production!)
-- Uncomment to run:
-- SELECT process_escrow_releases();

-- 12. CHECK EDGE FUNCTION LOGS
-- This query won't work in SQL editor, but here's what to check in Supabase Dashboard:
-- 1. Go to Functions > validate-bank-account
-- 2. Click on "Logs" tab
-- 3. Look for recent invocations and any errors

-- ================================================
-- HELPFUL COMMANDS FOR TESTING
-- ================================================

-- Update order to "delivered" status for testing:
-- UPDATE orders
-- SET status = 'delivered',
--     goods_confirmed_by_collector = true,
--     goods_confirmed_at = NOW() - interval '49 hours'
-- WHERE order_number = 'YOUR_ORDER_NUMBER';

-- Manually create a test earning record:
-- INSERT INTO picker_earnings (
--   picker_id,
--   order_id,
--   amount,
--   platform_fee,
--   status
-- ) VALUES (
--   'picker_user_id',
--   'order_id',
--   100.00,
--   10.00,
--   'pending'
-- );

-- ================================================
-- NOTES
-- ================================================
--
-- VALIDATION STATUS:
-- - bank_account_last4 IS NOT NULL means validated by Stripe
-- - bank_account_last4 IS NULL means old entry (not validated)
--
-- PAYOUT FLOW:
-- 1. Order placed (status: pending)
-- 2. Picker fulfills (status: shipped)
-- 3. Collector confirms delivery (status: delivered, goods_confirmed_at set)
-- 4. 48 hour hold period
-- 5. Escrow release triggered by cron job
-- 6. Transfer created to picker's Stripe account
-- 7. Stripe transfers to bank (2-5 business days)
--
-- TROUBLESHOOTING:
-- - If no last4: Bank account needs validation
-- - If no stripe_account_id: Picker needs Stripe Connect
-- - If earnings are "pending": Check Stripe Dashboard for transfer status
-- - If earnings are "failed": Check error_message column
