/*
  # Create app_secrets table for storing service role key

  ## Purpose
  vault.secrets requires pgsodium owner privileges not available to postgres/service_role.
  This table provides a simple locked-down alternative to store the service role key
  so DB functions can authenticate pg_net calls to edge functions.

  ## Security
  - RLS enabled and locked down to service_role only (no authenticated user access)
  - Only service_role can read/write
  - No public access whatsoever
*/

CREATE TABLE IF NOT EXISTS app_secrets (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE app_secrets ENABLE ROW LEVEL SECURITY;

-- Only service_role can select (no authenticated user policies)
CREATE POLICY "service_role_select_app_secrets"
  ON app_secrets FOR SELECT
  TO service_role
  USING (true);

CREATE POLICY "service_role_insert_app_secrets"
  ON app_secrets FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "service_role_update_app_secrets"
  ON app_secrets FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Revoke from authenticated and anon
REVOKE ALL ON TABLE app_secrets FROM authenticated;
REVOKE ALL ON TABLE app_secrets FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE app_secrets TO service_role;

-- Update get_service_role_key to read from app_secrets table
CREATE OR REPLACE FUNCTION get_service_role_key()
RETURNS text AS $$
DECLARE
  v_key text;
BEGIN
  SELECT value INTO v_key
  FROM app_secrets
  WHERE key = 'supabase_service_role_key'
  LIMIT 1;
  RETURN v_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

REVOKE ALL ON FUNCTION get_service_role_key() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_service_role_key() TO service_role;

-- Update seed function to use app_secrets instead of vault
CREATE OR REPLACE FUNCTION seed_service_role_key_in_vault(p_key text)
RETURNS void AS $$
BEGIN
  INSERT INTO app_secrets (key, value, updated_at)
  VALUES ('supabase_service_role_key', p_key, now())
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION seed_service_role_key_in_vault(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seed_service_role_key_in_vault(text) TO service_role;
