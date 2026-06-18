/*
  # Create helper function to seed service role key into vault
  
  This function is called once by the seed-payout-vault-secret edge function
  to store the service role key in vault.secrets so DB payout trigger functions
  can authenticate when calling the process-picker-payout edge function via pg_net.
*/

CREATE OR REPLACE FUNCTION seed_service_role_key_in_vault(p_key text)
RETURNS void AS $$
BEGIN
  -- Upsert the secret into vault
  IF EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'supabase_service_role_key') THEN
    UPDATE vault.secrets
    SET secret = p_key, updated_at = now()
    WHERE name = 'supabase_service_role_key';
  ELSE
    INSERT INTO vault.secrets (name, secret)
    VALUES ('supabase_service_role_key', p_key);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION seed_service_role_key_in_vault(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seed_service_role_key_in_vault(text) TO service_role;
