/*
  # Fix Picker Earnings and Payouts Permissions
  
  1. Changes
    - Grant SELECT access to authenticated users on picker_earnings
    - Grant SELECT access to authenticated users on picker_payouts
    - Grant INSERT/UPDATE access for system operations
  
  2. Security
    - RLS policies already in place to restrict data to owners
*/

-- Grant access to picker_earnings
GRANT SELECT ON picker_earnings TO authenticated;
GRANT INSERT ON picker_earnings TO authenticated;
GRANT UPDATE ON picker_earnings TO authenticated;
GRANT DELETE ON picker_earnings TO authenticated;

-- Grant access to picker_payouts
GRANT SELECT ON picker_payouts TO authenticated;
GRANT INSERT ON picker_payouts TO authenticated;
GRANT UPDATE ON picker_payouts TO authenticated;
GRANT DELETE ON picker_payouts TO authenticated;

-- Grant service role full access for automated processes
GRANT ALL ON picker_earnings TO service_role;
GRANT ALL ON picker_payouts TO service_role;
