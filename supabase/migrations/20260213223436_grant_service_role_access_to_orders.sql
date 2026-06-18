/*
  # Grant Service Role Access to Orders Table

  ## Changes
  - Grant full access to service_role on orders table
  - This is required for edge functions to work properly
  
  ## Security
  - Service role is used by edge functions which implement their own authorization
  - Edge functions already verify user ownership before accessing orders
*/

-- Grant all permissions to service_role on orders table
GRANT ALL ON orders TO service_role;

-- Also grant access to related tables that edge functions need
GRANT ALL ON payment_intents TO service_role;
GRANT ALL ON payment_escrow TO service_role;
GRANT ALL ON picker_payout_info TO service_role;
