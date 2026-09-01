-- Grant service role access to tables needed by get-shipping-rates edge function
GRANT SELECT ON listings TO service_role;
GRANT SELECT ON picker_profiles TO service_role;
GRANT SELECT ON seller_addresses TO service_role;
