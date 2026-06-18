DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'support_tickets' AND column_name = 'dispute_id'
  ) THEN
    ALTER TABLE support_tickets 
    ADD COLUMN dispute_id uuid REFERENCES disputes(id) ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_support_tickets_dispute_id 
    ON support_tickets(dispute_id);
  END IF;
END $$;

-- Update the function to include dispute_id
CREATE OR REPLACE FUNCTION notify_support_of_dispute()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  order_title text;
  filer_name text;
  against_name text;
BEGIN
  -- Get order and user details
  SELECT 
    l.title,
    p1.full_name,
    p2.full_name
  INTO 
    order_title,
    filer_name,
    against_name
  FROM orders o
  JOIN listings l ON l.id = o.listing_id
  JOIN profiles p1 ON p1.id = NEW.filed_by
  JOIN profiles p2 ON p2.id = NEW.against_user
  WHERE o.id = NEW.order_id;

  -- Create support ticket with dispute link
  INSERT INTO support_tickets (
    user_id,
    subject,
    message,
    category,
    status,
    priority,
    dispute_id
  ) VALUES (
    NEW.filed_by,
    'DISPUTE FILED: ' || COALESCE(order_title, 'Order #' || NEW.order_id),
    'A dispute has been filed and requires immediate attention.

DISPUTE DETAILS:
- Dispute ID: ' || NEW.id || '
- Order: ' || COALESCE(order_title, 'Unknown') || '
- Filed By: ' || COALESCE(filer_name, 'Unknown') || '
- Against: ' || COALESCE(against_name, 'Unknown') || '
- Type: ' || NEW.dispute_type || '
- Description: ' || NEW.description || '

Please review this dispute in the Disputes section and take appropriate action.',
    'dispute',
    'open',
    'high',
    NEW.id
  );

  RETURN NEW;
END;
$$;


-- =========================================
-- Migration: 20251130231343_create_profile_on_email_confirmation.sql
-- =========================================

/*
  # Create Profile Automatically After Email Confirmation

  1. Changes
    - Creates a trigger function that runs when a user confirms their email
    - Automatically creates profile and picker_profile based on user metadata
    - Handles the profile creation that previously happened in the signup function

  2. Details
    - Extracts full_name and user_type from auth.users raw_user_meta_data
    - Creates profile record with the user's information
    - Creates picker_profile if user_type is 'picker'
    - Generates referral code for new users
*/

-- Function to create profile after email confirmation
CREATE OR REPLACE FUNCTION handle_new_user_confirmation()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Only proceed if email is confirmed and profile doesn't exist
  IF NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL THEN
    
    -- Check if profile already exists
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
      
      -- Extract metadata
      full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
      user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user % after email confirmation', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user_confirmation();

-- Add comment
COMMENT ON FUNCTION handle_new_user_confirmation() IS 'Automatically creates profile and picker_profile when user confirms their email';


-- =========================================
-- Migration: 20251201153644_add_phone_and_recovery_options.sql
-- =========================================

/*
  # Add Phone and Account Recovery Options

  1. Changes to profiles table
    - Add `phone_number` column for SMS-based authentication
    - Add `phone_verified` boolean flag
    - Add `phone_verified_at` timestamp
    - Add `backup_email` for alternative recovery email
    - Add `backup_email_verified` boolean flag
    - Add `preferred_recovery_method` enum
    - Add `last_recovery_attempt` timestamp for rate limiting

  2. Security
    - Existing RLS policies remain in place
    - Users can only modify their own recovery options
    - Phone numbers are stored with country code format

  3. Notes
    - Phone numbers should be in E.164 format (+1234567890)
    - SMS functionality requires external service integration
    - Backup email must be different from primary email
*/

-- Add new columns to profiles table
DO $$
BEGIN
  -- Add phone number support
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'phone_number'
  ) THEN
    ALTER TABLE profiles ADD COLUMN phone_number text;
    ALTER TABLE profiles ADD COLUMN phone_verified boolean DEFAULT false;
    ALTER TABLE profiles ADD COLUMN phone_verified_at timestamptz;
  END IF;

  -- Add backup email support
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'backup_email'
  ) THEN
    ALTER TABLE profiles ADD COLUMN backup_email text;
    ALTER TABLE profiles ADD COLUMN backup_email_verified boolean DEFAULT false;
  END IF;

  -- Add recovery preferences
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'preferred_recovery_method'
  ) THEN
    ALTER TABLE profiles ADD COLUMN preferred_recovery_method text DEFAULT 'email' CHECK (preferred_recovery_method IN ('email', 'phone', 'magic_link'));
    ALTER TABLE profiles ADD COLUMN last_recovery_attempt timestamptz;
  END IF;

  -- Add auth method tracking
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'linked_auth_providers'
  ) THEN
    ALTER TABLE profiles ADD COLUMN linked_auth_providers text[] DEFAULT ARRAY[]::text[];
    ALTER TABLE profiles ADD COLUMN last_login_method text;
    ALTER TABLE profiles ADD COLUMN last_login_at timestamptz;
  END IF;
END $$;

-- Create index on phone numbers for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_phone_number ON profiles(phone_number) WHERE phone_number IS NOT NULL;

-- Create index on backup emails
CREATE INDEX IF NOT EXISTS idx_profiles_backup_email ON profiles(backup_email) WHERE backup_email IS NOT NULL;

-- Add constraint to ensure backup email is different from primary email
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'backup_email_different_from_primary'
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT backup_email_different_from_primary
    CHECK (backup_email IS NULL OR backup_email != email);
  END IF;
END $$;

-- Create a function to update last login tracking
CREATE OR REPLACE FUNCTION update_last_login()
RETURNS TRIGGER AS $$
BEGIN
  -- This would be called from application code when user logs in
  -- Just creating the structure here
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create recovery attempts table for rate limiting
CREATE TABLE IF NOT EXISTS recovery_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  email text NOT NULL,
  phone_number text,
  recovery_method text NOT NULL CHECK (recovery_method IN ('email', 'phone', 'magic_link')),
  attempted_at timestamptz DEFAULT now(),
  success boolean DEFAULT false,
  ip_address text,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on recovery_attempts
ALTER TABLE recovery_attempts ENABLE ROW LEVEL SECURITY;

-- Users can view their own recovery attempts
CREATE POLICY "Users can view own recovery attempts"
  ON recovery_attempts
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Only authenticated users can insert recovery attempts
CREATE POLICY "Users can log own recovery attempts"
  ON recovery_attempts
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create index on recovery attempts for rate limiting queries
CREATE INDEX IF NOT EXISTS idx_recovery_attempts_user_time
  ON recovery_attempts(user_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_recovery_attempts_email_time
  ON recovery_attempts(email, attempted_at DESC);

-- Function to check rate limiting for recovery attempts
CREATE OR REPLACE FUNCTION check_recovery_rate_limit(
  p_identifier text,
  p_method text,
  p_time_window interval DEFAULT '1 hour'::interval,
  p_max_attempts integer DEFAULT 5
)
RETURNS boolean AS $$
DECLARE
  attempt_count integer;
BEGIN
  SELECT COUNT(*)
  INTO attempt_count
  FROM recovery_attempts
  WHERE (email = p_identifier OR phone_number = p_identifier)
    AND recovery_method = p_method
    AND attempted_at > (now() - p_time_window);

  RETURN attempt_count < p_max_attempts;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =========================================
-- Migration: 20251201180815_add_notification_preferences_policies.sql
-- =========================================

/*
  # Add RLS policies for notification_preferences table

  1. Security
    - Enable RLS on notification_preferences table
    - Add policy for users to read their own preferences
    - Add policy for users to insert their own preferences
    - Add policy for users to update their own preferences
    
  2. Notes
    - Users can only access their own notification preferences
    - Each user can manage their own settings independently
*/

-- Enable RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can view their own preferences
CREATE POLICY "Users can view own notification preferences"
  ON notification_preferences
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own notification preferences"
  ON notification_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own notification preferences"
  ON notification_preferences
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =========================================
-- Migration: 20251203175543_add_fee_tracking_to_picker_payouts.sql
-- =========================================

/*
  # Add Fee Tracking to Picker Payouts Table

  1. Changes
    - Add `gross_amount` column - Original escrow amount before platform fee
    - Add `platform_fee` column - 10% platform fee deducted
    - Add `net_amount` column - Actual amount transferred to picker
    - Add `stripe_transfer_id` column - Stripe transfer ID (different from payout ID)
    - Add `processed_at` column - When the transfer was completed
    - Update the status values to include 'completed'

  2. Purpose
    - Track platform fee deductions transparently
    - Show both gross and net amounts for accounting
    - Support both Stripe transfers and payouts
    - Maintain complete audit trail of money flow

  3. Notes
    - `stripe_payout_id` is for Stripe payouts to bank accounts
    - `stripe_transfer_id` is for Stripe transfers to Connect accounts  
    - Both can coexist for different payout methods
*/

-- Add fee tracking columns to picker_payouts table
DO $$
BEGIN
  -- Add gross_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'gross_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN gross_amount numeric CHECK (gross_amount > 0);
  END IF;

  -- Add platform_fee column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'platform_fee'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN platform_fee numeric DEFAULT 0 CHECK (platform_fee >= 0);
  END IF;

  -- Add net_amount column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'net_amount'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN net_amount numeric CHECK (net_amount > 0);
  END IF;

  -- Add stripe_transfer_id column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'stripe_transfer_id'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN stripe_transfer_id text UNIQUE;
  END IF;

  -- Add processed_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_payouts' AND column_name = 'processed_at'
  ) THEN
    ALTER TABLE picker_payouts ADD COLUMN processed_at timestamptz;
  END IF;
END $$;

-- Update status constraint to include 'completed'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'picker_payouts' AND constraint_name = 'picker_payouts_status_check'
  ) THEN
    ALTER TABLE picker_payouts DROP CONSTRAINT picker_payouts_status_check;
  END IF;
END $$;

ALTER TABLE picker_payouts ADD CONSTRAINT picker_payouts_status_check
  CHECK (status IN ('pending', 'in_transit', 'paid', 'failed', 'cancelled', 'completed'));

-- Create index on stripe_transfer_id for webhook lookups
CREATE INDEX IF NOT EXISTS idx_picker_payouts_stripe_transfer_id 
  ON picker_payouts(stripe_transfer_id);

-- Create a helpful view for picker earnings with fees
CREATE OR REPLACE VIEW picker_earnings_with_fees AS
SELECT
  picker_id,
  COUNT(*) as total_transactions,
  SUM(COALESCE(gross_amount, amount)) as total_gross_earned,
  SUM(COALESCE(platform_fee, 0)) as total_fees_paid,
  SUM(COALESCE(net_amount, amount)) as total_net_received,
  MIN(created_at) as first_payout_at,
  MAX(COALESCE(processed_at, paid_at)) as last_payout_at
FROM picker_payouts
WHERE status IN ('completed', 'paid', 'in_transit')
GROUP BY picker_id;

-- Grant access to the view
GRANT SELECT ON picker_earnings_with_fees TO authenticated;

-- Update existing records to set net_amount equal to amount where null
UPDATE picker_payouts
SET net_amount = amount
WHERE net_amount IS NULL AND amount IS NOT NULL;

-- Update existing records to set gross_amount equal to amount where null
UPDATE picker_payouts
SET gross_amount = amount
WHERE gross_amount IS NULL AND amount IS NOT NULL;


-- =========================================
-- Migration: 20251203175630_update_escrow_release_with_stripe_transfers_v2.sql
-- =========================================

/*
  # Update Escrow Release to Process Actual Stripe Transfers

  1. Changes
    - Drop and recreate `release_escrow_to_picker` function with new return type
    - Function now marks escrow for payout processing
    - Actual Stripe transfers handled by edge function
    - Deducts 10% platform fee automatically
    - Updates escrow status after successful transfer

  2. Flow
    - When escrow is released (auto or manual)
    - Function marks escrow for processing
    - Background job or manual call to edge function processes transfer
    - Edge function creates Stripe transfer
    - Records payout in picker_payouts table
    - Updates escrow to 'released' status

  3. Important
    - This replaces the old database-only release process
    - Now actual money transfers happen via Stripe
    - Pickers must have completed Stripe Connect onboarding
    - Platform fee is automatically deducted
*/

-- Drop the existing function
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

-- Recreate the function with support for actual Stripe transfers
CREATE OR REPLACE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS json AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Get order_id for the escrow
  SELECT order_id INTO v_order_id
  FROM payment_escrow
  WHERE id = escrow_id
  AND status = 'held';

  IF v_order_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Escrow not found or already processed'
    );
  END IF;

  -- Mark escrow for payout processing
  -- The actual Stripe transfer will be handled by calling the edge function
  UPDATE payment_escrow
  SET 
    payout_processed = false,
    notes = 'Pending Stripe transfer processing',
    released_to = picker_user_id
  WHERE id = escrow_id
  AND status = 'held';

  -- Insert a notification to trigger the payout processing
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    picker_user_id,
    'payout_processing',
    'Payment Processing',
    'Your payout is being processed and will arrive in your account soon',
    json_build_object(
      'escrow_id', escrow_id,
      'order_id', v_order_id,
      'action', 'process_payout'
    )
  );

  RETURN json_build_object(
    'success', true,
    'escrow_id', escrow_id,
    'order_id', v_order_id,
    'picker_id', picker_user_id,
    'message', 'Payout processing initiated. Call process-picker-payout edge function to complete.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a helper function to get pending payouts
CREATE OR REPLACE FUNCTION get_pending_payouts()
RETURNS TABLE (
  escrow_id uuid,
  picker_id uuid,
  order_id uuid,
  amount numeric,
  held_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pe.id as escrow_id,
    pe.released_to as picker_id,
    pe.order_id,
    pe.amount,
    pe.held_at
  FROM payment_escrow pe
  WHERE pe.status = 'held'
  AND pe.payout_processed = false
  AND pe.released_to IS NOT NULL
  ORDER BY pe.held_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION release_escrow_to_picker(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_payouts() TO authenticated;


-- =========================================
-- Migration: 20251203175705_update_auto_escrow_release_with_edge_function_call.sql
-- =========================================

/*
  # Update Automatic Escrow Release to Call Edge Function

  1. Changes
    - Update `auto_release_escrow_after_confirmation` to call edge function
    - Use pg_net extension to make HTTP requests to edge function
    - Process actual Stripe transfers automatically
    - Handle failures gracefully with retries

  2. Flow
    - Scheduled job runs every hour
    - Finds escrows ready for release (48 hours after delivery)
    - For each escrow, calls process-picker-payout edge function
    - Edge function handles Stripe transfer and updates database
    - If edge function fails, escrow stays in 'held' status for retry

  3. Important
    - Requires pg_net extension enabled
    - Edge function must be deployed
    - Pickers must have Stripe Connect accounts set up
*/

-- Ensure pg_net extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Update the auto release function to call the edge function for actual transfers
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_supabase_url text;
  v_supabase_anon_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase configuration
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  SELECT current_setting('app.settings.supabase_anon_key', true) INTO v_supabase_anon_key;
  
  -- Default fallback (will be replaced by actual env vars in production)
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Find escrows that need to be released (48 hours after delivery)
  FOR v_escrow_record IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND o.status = 'delivered'
    AND o.actual_delivery IS NOT NULL
    AND o.actual_delivery < (NOW() - INTERVAL '48 hours')
    AND pe.payout_processed = false
  LOOP
    -- Call the edge function to process the Stripe transfer
    -- Using pg_net for async HTTP requests
    BEGIN
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(v_supabase_anon_key, '')
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      -- Log that we initiated the payout
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        'Automatic Payout Initiated',
        'Your earnings from a completed order are being transferred to your account',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount,
          'request_id', v_request_id
        )
      );

    EXCEPTION WHEN OTHERS THEN
      -- If edge function call fails, log error and continue
      -- The escrow will be retried in the next run
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_error',
        'Payout Processing Error',
        'There was an issue processing your payout. Our team will resolve this shortly.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'error', SQLERRM
        )
      );
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update process_escrow_releases to use the new logic
CREATE OR REPLACE FUNCTION process_escrow_releases()
RETURNS json AS $$
DECLARE
  v_processed_count int := 0;
BEGIN
  -- Call the auto release function
  PERFORM auto_release_escrow_after_confirmation();
  
  -- Count how many escrows were marked for processing
  SELECT COUNT(*) INTO v_processed_count
  FROM payment_escrow
  WHERE status = 'held'
  AND payout_processed = false
  AND released_to IS NOT NULL;
  
  RETURN json_build_object(
    'success', true,
    'pending_payouts', v_processed_count,
    'processed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION auto_release_escrow_after_confirmation() TO authenticated;
GRANT EXECUTE ON FUNCTION process_escrow_releases() TO authenticated;


-- =========================================
-- Migration: 20251203175742_update_picker_earnings_with_platform_fees.sql
-- =========================================

/*
  # Update Picker Earnings to Account for Platform Fees

  1. Changes
    - Update picker_earnings table to track gross vs net earnings
    - Add platform_fees_paid column
    - Update earnings calculation functions
    - Deduct 10% platform fee from all earnings
    - Show transparent fee breakdown to pickers

  2. New Columns
    - `total_gross_earned` - Total before fees (replaces total_earned)
    - `platform_fees_paid` - Total fees paid to platform (10%)
    - `total_net_earned` - Total after fees (what picker actually receives)

  3. Important
    - Platform takes 10% of all earnings
    - Pickers see both gross and net amounts
    - Available balance is net amount minus payouts
*/

-- Add new columns to picker_earnings table
DO $$
BEGIN
  -- Add total_gross_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_gross_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_gross_earned numeric DEFAULT 0 CHECK (total_gross_earned >= 0);
  END IF;

  -- Add platform_fees_paid if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'platform_fees_paid'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN platform_fees_paid numeric DEFAULT 0 CHECK (platform_fees_paid >= 0);
  END IF;

  -- Add total_net_earned if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'picker_earnings' AND column_name = 'total_net_earned'
  ) THEN
    ALTER TABLE picker_earnings ADD COLUMN total_net_earned numeric DEFAULT 0 CHECK (total_net_earned >= 0);
  END IF;
END $$;

-- Migrate existing data: total_earned becomes total_gross_earned
UPDATE picker_earnings
SET 
  total_gross_earned = COALESCE(total_earned, 0),
  platform_fees_paid = ROUND(COALESCE(total_earned, 0) * 0.10, 2),
  total_net_earned = ROUND(COALESCE(total_earned, 0) * 0.90, 2)
WHERE total_gross_earned = 0;

-- Update available_balance to reflect net earnings
UPDATE picker_earnings
SET available_balance = GREATEST(
  (total_net_earned - COALESCE(total_paid_out, 0)),
  0
);

-- Create or replace the earnings update function with fee calculation
CREATE OR REPLACE FUNCTION update_earnings_on_escrow_held()
RETURNS TRIGGER AS $$
DECLARE
  v_picker_id uuid;
  v_platform_fee numeric;
  v_net_amount numeric;
BEGIN
  -- Get picker_id from the order
  SELECT picker_id INTO v_picker_id
  FROM orders
  WHERE id = NEW.order_id;

  IF v_picker_id IS NOT NULL THEN
    -- Calculate platform fee (10%) and net amount (90%)
    v_platform_fee := ROUND(NEW.amount * 0.10, 2);
    v_net_amount := NEW.amount - v_platform_fee;

    -- Update or insert picker earnings
    INSERT INTO picker_earnings (
      picker_id,
      total_gross_earned,
      platform_fees_paid,
      total_net_earned,
      pending_payout,
      available_balance
    )
    VALUES (
      v_picker_id,
      NEW.amount,
      v_platform_fee,
      v_net_amount,
      v_net_amount,
      0
    )
    ON CONFLICT (picker_id) DO UPDATE SET
      total_gross_earned = picker_earnings.total_gross_earned + NEW.amount,
      platform_fees_paid = picker_earnings.platform_fees_paid + v_platform_fee,
      total_net_earned = picker_earnings.total_net_earned + v_net_amount,
      pending_payout = picker_earnings.pending_payout + v_net_amount,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update earnings when payout is completed
CREATE OR REPLACE FUNCTION update_earnings_on_payout_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Move from pending to paid out
    UPDATE picker_earnings
    SET
      pending_payout = GREATEST(pending_payout - COALESCE(NEW.net_amount, NEW.amount), 0),
      total_paid_out = total_paid_out + COALESCE(NEW.net_amount, NEW.amount),
      available_balance = GREATEST(total_net_earned - (total_paid_out + COALESCE(NEW.net_amount, NEW.amount)), 0),
      last_payout_at = NEW.processed_at,
      updated_at = now()
    WHERE picker_id = NEW.picker_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for payout completion
DROP TRIGGER IF EXISTS trigger_update_earnings_on_payout ON picker_payouts;
CREATE TRIGGER trigger_update_earnings_on_payout
  AFTER UPDATE ON picker_payouts
  FOR EACH ROW
  EXECUTE FUNCTION update_earnings_on_payout_completed();

-- Create a comprehensive view for picker dashboard
CREATE OR REPLACE VIEW picker_earnings_dashboard AS
SELECT
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at,
  COUNT(pp.id) as total_payouts,
  COUNT(CASE WHEN pp.status = 'completed' THEN 1 END) as successful_payouts,
  COUNT(CASE WHEN pp.status = 'failed' THEN 1 END) as failed_payouts,
  COUNT(DISTINCT o.id) as total_orders_completed,
  AVG(CASE WHEN pp.status = 'completed' THEN pp.net_amount END) as avg_payout_amount
FROM picker_earnings pe
LEFT JOIN picker_payouts pp ON pp.picker_id = pe.picker_id
LEFT JOIN orders o ON o.picker_id = pe.picker_id AND o.status = 'completed'
GROUP BY 
  pe.picker_id,
  pe.total_gross_earned,
  pe.platform_fees_paid,
  pe.total_net_earned,
  pe.total_paid_out,
  pe.pending_payout,
  pe.available_balance,
  pe.last_payout_at;

-- Grant access to the views
GRANT SELECT ON picker_earnings_dashboard TO authenticated;

-- Add comment to clarify the old total_earned column (if it still exists)
COMMENT ON COLUMN picker_earnings.total_earned IS 'DEPRECATED: Use total_gross_earned instead. This column may be removed in a future update.';


-- =========================================
-- Migration: 20251203180027_add_goods_confirmation_system.sql
-- =========================================

/*
  # Add Goods Confirmation System for Collectors

  1. New Columns to orders table
    - `goods_confirmed` (boolean) - Whether collector confirmed receipt
    - `goods_confirmed_at` (timestamptz) - When confirmation happened
    - `confirmation_notes` (text) - Optional feedback from collector

  2. New Function
    - `confirm_goods_receipt(order_id, notes)` - Collector confirms receipt
    - Triggers immediate escrow release process
    - Updates order status to confirmed

  3. Flow
    - Collector receives order
    - Collector clicks "Confirm Receipt" button
    - System marks goods_confirmed = true
    - Escrow released immediately (no 48-hour wait)
    - Picker gets paid faster when collector is satisfied

  4. Benefits
    - Pickers get paid faster when collectors are happy
    - 48-hour auto-release still exists as backup
    - Builds trust between pickers and collectors
*/

-- Add confirmation columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'goods_confirmed_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN goods_confirmed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'confirmation_notes'
  ) THEN
    ALTER TABLE orders ADD COLUMN confirmation_notes text;
  END IF;
END $$;

-- Create function for collectors to confirm receipt of goods
CREATE OR REPLACE FUNCTION confirm_goods_receipt(
  p_order_id uuid,
  p_notes text DEFAULT NULL
)
RETURNS json AS $$
DECLARE
  v_order record;
  v_escrow_id uuid;
  v_picker_id uuid;
BEGIN
  -- Get order details
  SELECT * INTO v_order
  FROM orders
  WHERE id = p_order_id
  AND auth.uid() = client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order not found or you do not have permission'
    );
  END IF;

  -- Check if order is in a state that can be confirmed
  IF v_order.status NOT IN ('in_progress', 'delivered') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order cannot be confirmed in current status: ' || v_order.status
    );
  END IF;

  -- Check if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Order has already been confirmed'
    );
  END IF;

  -- Update order with confirmation
  UPDATE orders
  SET
    goods_confirmed = true,
    goods_confirmed_at = now(),
    confirmation_notes = p_notes,
    status = CASE 
      WHEN status != 'delivered' THEN 'delivered'
      ELSE status
    END,
    actual_delivery = CASE
      WHEN actual_delivery IS NULL THEN now()
      ELSE actual_delivery
    END,
    updated_at = now()
  WHERE id = p_order_id
  RETURNING picker_id INTO v_picker_id;

  -- Get the escrow for this order
  SELECT id INTO v_escrow_id
  FROM payment_escrow
  WHERE order_id = p_order_id
  AND status = 'held';

  -- If escrow exists, release it immediately
  IF v_escrow_id IS NOT NULL THEN
    PERFORM release_escrow_to_picker(v_escrow_id, v_picker_id);
  END IF;

  -- Notify picker that goods were confirmed and payment is being processed
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_picker_id,
    'goods_confirmed',
    'Order Confirmed - Payment Processing',
    'The collector confirmed receipt of the order. Your payment is being processed now!',
    json_build_object(
      'order_id', p_order_id,
      'escrow_id', v_escrow_id,
      'confirmed_at', now()
    )
  );

  -- Notify collector that their confirmation was received
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'confirmation_received',
    'Thank You for Confirming',
    'Your confirmation has been received. The picker will be paid shortly.',
    json_build_object(
      'order_id', p_order_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'escrow_id', v_escrow_id,
    'message', 'Receipt confirmed. Payment will be processed immediately.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the auto-release function to prioritize confirmed orders
CREATE OR REPLACE FUNCTION auto_release_escrow_after_confirmation()
RETURNS void AS $$
DECLARE
  v_escrow_record record;
  v_supabase_url text;
  v_supabase_anon_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase configuration
  SELECT current_setting('app.settings.supabase_url', true) INTO v_supabase_url;
  SELECT current_setting('app.settings.supabase_anon_key', true) INTO v_supabase_anon_key;
  
  IF v_supabase_url IS NULL THEN
    SELECT COALESCE(
      current_setting('request.headers', true)::json->>'x-forwarded-host',
      'localhost:54321'
    ) INTO v_supabase_url;
    v_supabase_url := 'https://' || v_supabase_url;
  END IF;

  -- Find escrows that need to be released
  -- Priority 1: Orders confirmed by collector (immediate release)
  -- Priority 2: Orders delivered 48+ hours ago (auto release)
  FOR v_escrow_record IN
    SELECT 
      pe.id as escrow_id,
      o.picker_id,
      o.id as order_id,
      pe.amount,
      o.goods_confirmed,
      o.goods_confirmed_at
    FROM payment_escrow pe
    JOIN orders o ON o.id = pe.order_id
    WHERE pe.status = 'held'
    AND pe.payout_processed = false
    AND (
      -- Confirmed by collector (immediate release)
      (o.goods_confirmed = true AND o.goods_confirmed_at IS NOT NULL)
      OR
      -- Auto-release after 48 hours
      (
        o.status = 'delivered'
        AND o.actual_delivery IS NOT NULL
        AND o.actual_delivery < (NOW() - INTERVAL '48 hours')
      )
    )
    ORDER BY 
      o.goods_confirmed DESC,  -- Confirmed orders first
      o.goods_confirmed_at ASC, -- Earlier confirmations first
      o.actual_delivery ASC     -- Then oldest deliveries
  LOOP
    BEGIN
      -- Call the edge function to process the Stripe transfer
      SELECT net.http_post(
        url := v_supabase_url || '/functions/v1/process-picker-payout',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || COALESCE(v_supabase_anon_key, '')
        ),
        body := jsonb_build_object(
          'escrowId', v_escrow_record.escrow_id,
          'pickerId', v_escrow_record.picker_id
        ),
        timeout_milliseconds := 30000
      ) INTO v_request_id;

      -- Log payout initiation
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_initiated',
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'Payment Processing (Confirmed)'
          ELSE 'Automatic Payout Initiated'
        END,
        CASE 
          WHEN v_escrow_record.goods_confirmed THEN 'The collector confirmed receipt. Your payment is being transferred now!'
          ELSE 'Your earnings from a completed order are being transferred to your account'
        END,
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'amount', v_escrow_record.amount,
          'confirmed', v_escrow_record.goods_confirmed,
          'request_id', v_request_id
        )
      );

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO notifications (user_id, type, title, message, data)
      VALUES (
        v_escrow_record.picker_id,
        'payout_error',
        'Payout Processing Error',
        'There was an issue processing your payout. Our team will resolve this shortly.',
        jsonb_build_object(
          'escrow_id', v_escrow_record.escrow_id,
          'order_id', v_escrow_record.order_id,
          'error', SQLERRM
        )
      );
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION confirm_goods_receipt(uuid, text) TO authenticated;

-- Create index for faster confirmation queries
CREATE INDEX IF NOT EXISTS idx_orders_goods_confirmed 
  ON orders(goods_confirmed, goods_confirmed_at) 
  WHERE goods_confirmed = true;


-- =========================================
-- Migration: 20251203180751_create_delivery_confirmation_reminders.sql
-- =========================================

/*
  # Create Delivery Confirmation Reminder System

  1. New Table
    - `reminder_queue` - Tracks scheduled reminders to be sent
    
  2. New Functions
    - `send_delivery_confirmation_reminder()` - Sends reminder to collector
    - `create_delivery_reminders()` - Schedules reminders when order is delivered
    
  3. New Triggers
    - Automatically creates reminders when order status changes to 'delivered'
    
  4. Reminder Schedule
    - Immediate: Notification when order delivered
    - 12 hours: First reminder to confirm receipt
    - 24 hours: Second reminder to confirm receipt
    - 36 hours: Final reminder (before 48hr auto-release)

  5. Benefits
    - Encourages collectors to confirm receipt quickly
    - Pickers get paid faster
    - Reduces forgotten confirmations
    - Improves platform engagement
*/

-- Create reminder queue table
CREATE TABLE IF NOT EXISTS reminder_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_type text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  related_id uuid,
  scheduled_for timestamptz NOT NULL,
  sent boolean DEFAULT false,
  sent_at timestamptz,
  cancelled boolean DEFAULT false,
  cancelled_at timestamptz,
  data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_reminder_queue_scheduled 
  ON reminder_queue(scheduled_for) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_user 
  ON reminder_queue(user_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

CREATE INDEX IF NOT EXISTS idx_reminder_queue_related 
  ON reminder_queue(related_id, reminder_type) 
  WHERE sent = false AND cancelled = false;

-- Enable RLS
ALTER TABLE reminder_queue ENABLE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY "Users can view own reminders"
  ON reminder_queue FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Function to cancel reminders for an order
CREATE OR REPLACE FUNCTION cancel_order_reminders(p_order_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE reminder_queue
  SET cancelled = true, cancelled_at = now()
  WHERE related_id = p_order_id
    AND sent = false
    AND cancelled = false
    AND reminder_type = 'delivery_confirmation';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create delivery confirmation reminders
CREATE OR REPLACE FUNCTION create_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_delivery_time timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as picker_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use actual delivery time or current time
  v_delivery_time := COALESCE(v_order.actual_delivery, now());

  -- Cancel any existing reminders for this order
  PERFORM cancel_order_reminders(p_order_id);

  -- Schedule reminders at 12, 24, and 36 hours after delivery
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '12 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '24 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '36 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );

  -- Send immediate notification about delivery
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    v_order.client_id,
    'order_delivered',
    'Order Delivered!',
    'Your order from ' || v_order.picker_name || ' has been delivered. Confirm receipt to release payment immediately.',
    jsonb_build_object(
      'order_id', p_order_id,
      'picker_id', v_order.picker_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create reminders when order is delivered
CREATE OR REPLACE FUNCTION trigger_delivery_reminders()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if status changed to delivered
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Check if goods not already confirmed
    IF NOT NEW.goods_confirmed THEN
      PERFORM create_delivery_reminders(NEW.id);
    END IF;
  END IF;

  -- Cancel reminders if goods are confirmed
  IF NEW.goods_confirmed = true AND (OLD.goods_confirmed IS NULL OR OLD.goods_confirmed = false) THEN
    PERFORM cancel_order_reminders(NEW.id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on orders table
DROP TRIGGER IF EXISTS on_order_delivered ON orders;
CREATE TRIGGER on_order_delivered
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trigger_delivery_reminders();

-- Function to process pending reminders (called by scheduled job)
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Handle different reminder types
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        -- Get picker name from order
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        -- Send reminder notification
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⏰ Last Reminder: Confirm Receipt'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Please Confirm Your Order'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Final reminder: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will auto-confirm in 12 hours. Confirm now to release payment immediately!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Confirm receipt to release their payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' was delivered. Please confirm receipt when you receive it!'
          END,
          v_reminder.data
        );
      END IF;

      -- Mark reminder as sent
      UPDATE reminder_queue
      SET sent = true, sent_at = now()
      WHERE id = v_reminder.id;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue processing
      RAISE WARNING 'Error processing reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_delivery_reminders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_order_reminders(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION process_pending_reminders() TO authenticated;


-- =========================================
-- Migration: 20251203180837_create_trial_ending_reminders.sql
-- =========================================

/*
  # Create Trial Ending Reminder System for Pickers

  1. New Functions
    - `check_trial_endings()` - Finds pickers whose trials are ending soon
    - `create_trial_reminder()` - Creates reminder for a picker
    - `check_picker_has_payment_method()` - Verifies if picker has payment card
    
  2. Reminder Schedule
    - 7 days before: First reminder to add payment method
    - 3 days before: Second reminder with urgency
    - 1 day before: Final urgent reminder
    - On trial end day: Warning about account suspension

  3. Flow
    - Daily check for upcoming trial expirations
    - Send reminders only if picker has no payment method
    - Don't spam if picker already added payment
    - Clear call-to-action to add payment method

  4. Benefits
    - Prevents surprise trial endings
    - Increases payment method conversion
    - Better user experience
    - Reduces churn
*/

-- Function to check if picker has valid payment method
CREATE OR REPLACE FUNCTION check_picker_has_payment_method(p_picker_id uuid)
RETURNS boolean AS $$
DECLARE
  v_has_payment boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM picker_payment_cards
    WHERE picker_id = p_picker_id
    AND stripe_payment_method_id IS NOT NULL
  ) INTO v_has_payment;

  RETURN COALESCE(v_has_payment, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create trial ending reminder
CREATE OR REPLACE FUNCTION create_trial_reminder(
  p_picker_id uuid,
  p_days_until_end integer
)
RETURNS void AS $$
DECLARE
  v_profile record;
  v_reminder_exists boolean;
  v_title text;
  v_message text;
BEGIN
  -- Get picker profile
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = p_picker_id
  AND user_type = 'picker';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Check if reminder already exists for this timeframe
  SELECT EXISTS (
    SELECT 1
    FROM reminder_queue
    WHERE user_id = p_picker_id
      AND reminder_type = 'trial_ending'
      AND (data->>'days_until_end')::int = p_days_until_end
      AND sent = false
      AND cancelled = false
      AND scheduled_for >= now()
  ) INTO v_reminder_exists;

  IF v_reminder_exists THEN
    RETURN;
  END IF;

  -- Don't send if picker already has payment method
  IF check_picker_has_payment_method(p_picker_id) THEN
    RETURN;
  END IF;

  -- Create appropriate message based on days remaining
  IF p_days_until_end >= 7 THEN
    v_title := 'Trial Ending in ' || p_days_until_end || ' Days';
    v_message := 'Your free trial ends in ' || p_days_until_end || ' days. Add your payment method now to continue using SouvenirPickers without interruption.';
  ELSIF p_days_until_end >= 3 THEN
    v_title := 'Action Needed: Trial Ending Soon';
    v_message := 'Only ' || p_days_until_end || ' days left in your trial! Add a payment method now to keep your picker account active and continue earning.';
  ELSIF p_days_until_end >= 1 THEN
    v_title := '⚠️ Urgent: Trial Ends Tomorrow';
    v_message := 'Your trial ends tomorrow! Add your payment method immediately to avoid account suspension and continue accepting orders.';
  ELSE
    v_title := '🚨 Final Notice: Trial Ends Today';
    v_message := 'Your trial ends today! Add a payment method now to prevent your account from being suspended. Don''t lose access to your earnings and customers!';
  END IF;

  -- Schedule reminder
  INSERT INTO reminder_queue (reminder_type, user_id, scheduled_for, data)
  VALUES (
    'trial_ending',
    p_picker_id,
    now() + INTERVAL '5 minutes',
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'has_payment_method', false
    )
  );

  -- Send immediate notification
  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    p_picker_id,
    'trial_ending',
    v_title,
    v_message,
    jsonb_build_object(
      'days_until_end', p_days_until_end,
      'trial_ends_at', v_profile.trial_ends_at,
      'action_required', true,
      'action_url', '/subscription'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check all upcoming trial endings
CREATE OR REPLACE FUNCTION check_trial_endings()
RETURNS json AS $$
DECLARE
  v_picker record;
  v_count_7day integer := 0;
  v_count_3day integer := 0;
  v_count_1day integer := 0;
  v_count_today integer := 0;
  v_days_remaining integer;
BEGIN
  -- Find pickers whose trials are ending soon
  FOR v_picker IN
    SELECT 
      id,
      email,
      full_name,
      trial_ends_at,
      subscription_status
    FROM profiles
    WHERE user_type = 'picker'
      AND subscription_status IN ('trial', 'past_due', 'cancelled')
      AND trial_ends_at IS NOT NULL
      AND trial_ends_at > now()
      AND trial_ends_at <= now() + INTERVAL '14 days'
  LOOP
    -- Calculate days remaining
    v_days_remaining := EXTRACT(DAY FROM (v_picker.trial_ends_at - now()));

    -- Skip if picker already has payment method
    IF check_picker_has_payment_method(v_picker.id) THEN
      CONTINUE;
    END IF;

    -- Create reminders based on days remaining
    IF v_days_remaining = 7 THEN
      PERFORM create_trial_reminder(v_picker.id, 7);
      v_count_7day := v_count_7day + 1;
    ELSIF v_days_remaining = 3 THEN
      PERFORM create_trial_reminder(v_picker.id, 3);
      v_count_3day := v_count_3day + 1;
    ELSIF v_days_remaining = 1 THEN
      PERFORM create_trial_reminder(v_picker.id, 1);
      v_count_1day := v_count_1day + 1;
    ELSIF v_days_remaining = 0 THEN
      PERFORM create_trial_reminder(v_picker.id, 0);
      v_count_today := v_count_today + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'reminders_7day', v_count_7day,
    'reminders_3day', v_count_3day,
    'reminders_1day', v_count_1day,
    'reminders_today', v_count_today,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle trial reminders in reminder queue
CREATE OR REPLACE FUNCTION process_trial_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_has_payment boolean;
BEGIN
  -- Process trial ending reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE reminder_type = 'trial_ending'
      AND scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 50
  LOOP
    BEGIN
      -- Check if picker now has payment method
      v_has_payment := check_picker_has_payment_method(v_reminder.user_id);

      IF v_has_payment THEN
        -- Cancel reminder if payment method was added
        UPDATE reminder_queue
        SET cancelled = true, cancelled_at = now()
        WHERE id = v_reminder.id;
        
        -- Send success notification
        INSERT INTO notifications (user_id, type, title, message)
        VALUES (
          v_reminder.user_id,
          'payment_method_added',
          'Payment Method Added Successfully',
          'Thank you for adding your payment method! Your account will remain active when your trial ends.'
        );
      ELSE
        -- Send the reminder
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
          v_reminder.user_id,
          'trial_ending_reminder',
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 'Trial Ending Soon'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 'Action Required: Add Payment Method'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN '⚠️ Urgent: Trial Ends Tomorrow'
            ELSE '🚨 Final Notice: Trial Ends Today'
          END,
          CASE 
            WHEN (v_reminder.data->>'days_until_end')::int >= 7 THEN 
              'Your trial ends in ' || (v_reminder.data->>'days_until_end') || ' days. Add payment method to continue.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 3 THEN 
              'Only ' || (v_reminder.data->>'days_until_end') || ' days left! Add payment now to keep earning.'
            WHEN (v_reminder.data->>'days_until_end')::int >= 1 THEN 
              'Trial ends tomorrow! Add payment method to avoid account suspension.'
            ELSE 
              'Trial ends today! Add payment method now to prevent suspension.'
          END,
          jsonb_build_object(
            'days_until_end', v_reminder.data->>'days_until_end',
            'action_required', true,
            'action_url', '/subscription'
          )
        );

        -- Mark as sent
        UPDATE reminder_queue
        SET sent = true, sent_at = now()
        WHERE id = v_reminder.id;
      END IF;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Error processing trial reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_picker_has_payment_method(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION create_trial_reminder(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION check_trial_endings() TO authenticated;
GRANT EXECUTE ON FUNCTION process_trial_reminders() TO authenticated;


-- =========================================
-- Migration: 20251203180959_schedule_reminder_processing_v2.sql
-- =========================================

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


-- =========================================
-- Migration: 20251203181627_fix_valid_status_constraint.sql
-- =========================================

/*
  # Fix Valid Status Constraint for Orders

  1. Changes
    - Update the valid_status constraint to include 'delivered' status
    - This allows orders to be marked as delivered before goods confirmation
    
  2. Valid Statuses
    - pending: Order created, waiting for picker acceptance
    - accepted: Picker accepted the order
    - in_progress: Picker is working on the order
    - delivered: Order has been delivered to collector
    - completed: Order completed and confirmed
    - cancelled: Order was cancelled
    - refunded: Order was refunded
*/

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS valid_status;

-- Add the updated constraint with 'delivered' included
ALTER TABLE orders ADD CONSTRAINT valid_status 
  CHECK (status IN ('pending', 'accepted', 'in_progress', 'delivered', 'completed', 'cancelled', 'refunded'));


-- =========================================
-- Migration: 20251203181901_fix_delivery_reminders_notifications.sql
-- =========================================

/*
  # Fix Delivery Reminders to Use Correct Notification Columns

  1. Changes
    - Update create_delivery_reminders() to use 'link' instead of 'data' column
    - Update process_pending_reminders() to use 'link' instead of 'data' column
    - The notifications table has: user_id, type, title, message, link (not 'data')
*/

-- Fix create_delivery_reminders function
CREATE OR REPLACE FUNCTION create_delivery_reminders(p_order_id uuid)
RETURNS void AS $$
DECLARE
  v_order record;
  v_delivery_time timestamptz;
BEGIN
  -- Get order details
  SELECT o.*, p.full_name as picker_name
  INTO v_order
  FROM orders o
  LEFT JOIN profiles p ON p.id = o.picker_id
  WHERE o.id = p_order_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Don't create reminders if already confirmed
  IF v_order.goods_confirmed THEN
    RETURN;
  END IF;

  -- Use actual delivery time or current time
  v_delivery_time := COALESCE(v_order.actual_delivery, now());

  -- Cancel any existing reminders for this order
  PERFORM cancel_order_reminders(p_order_id);

  -- Schedule reminders at 12, 24, and 36 hours after delivery
  INSERT INTO reminder_queue (reminder_type, user_id, related_id, scheduled_for, data)
  VALUES
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '12 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 1
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '24 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 2
      )
    ),
    (
      'delivery_confirmation',
      v_order.client_id,
      p_order_id,
      v_delivery_time + INTERVAL '36 hours',
      jsonb_build_object(
        'order_id', p_order_id,
        'picker_name', v_order.picker_name,
        'reminder_number', 3
      )
    );

  -- Send immediate notification about delivery (using link instead of data)
  INSERT INTO notifications (user_id, type, title, message, link)
  VALUES (
    v_order.client_id,
    'order_delivered',
    'Order Delivered!',
    'Your order from ' || COALESCE(v_order.picker_name, 'the picker') || ' has been delivered. Confirm receipt to release payment immediately.',
    '/orders'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix process_pending_reminders function
CREATE OR REPLACE FUNCTION process_pending_reminders()
RETURNS json AS $$
DECLARE
  v_reminder record;
  v_count integer := 0;
  v_picker_name text;
BEGIN
  -- Process all due reminders
  FOR v_reminder IN
    SELECT *
    FROM reminder_queue
    WHERE scheduled_for <= now()
      AND sent = false
      AND cancelled = false
    ORDER BY scheduled_for ASC
    LIMIT 100
  LOOP
    BEGIN
      -- Handle different reminder types
      IF v_reminder.reminder_type = 'delivery_confirmation' THEN
        -- Get picker name from order
        SELECT p.full_name INTO v_picker_name
        FROM orders o
        LEFT JOIN profiles p ON p.id = o.picker_id
        WHERE o.id = v_reminder.related_id;

        -- Send reminder notification (using link instead of data)
        INSERT INTO notifications (user_id, type, title, message, link)
        VALUES (
          v_reminder.user_id,
          'delivery_confirmation_reminder',
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN '⏰ Last Reminder: Confirm Receipt'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 'Reminder: Confirm Order Receipt'
            ELSE 'Please Confirm Your Order'
          END,
          CASE 
            WHEN (v_reminder.data->>'reminder_number')::int = 3 THEN 
              'Final reminder: Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' will auto-confirm in 12 hours. Confirm now to release payment immediately!'
            WHEN (v_reminder.data->>'reminder_number')::int = 2 THEN 
              'Have you received your order from ' || COALESCE(v_picker_name, 'the picker') || 
              '? Confirm receipt to release their payment.'
            ELSE 
              'Your order from ' || COALESCE(v_picker_name, 'the picker') || 
              ' was delivered. Please confirm receipt when you receive it!'
          END,
          '/orders'
        );
      END IF;

      -- Mark reminder as sent
      UPDATE reminder_queue
      SET sent = true, sent_at = now()
      WHERE id = v_reminder.id;

      v_count := v_count + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue processing
      RAISE WARNING 'Error processing reminder %: %', v_reminder.id, SQLERRM;
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'processed', v_count,
    'timestamp', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251203181915_simplify_order_status_remove_completed_v2.sql
-- =========================================

/*
  # Simplify Order Status - Remove 'completed'

  1. Changes
    - Remove 'completed' from valid order statuses
    - 'delivered' becomes the final status for successfully finished orders
    - When collector confirms receipt, the order stays as 'delivered' and payment is released
    
  2. Valid Statuses (simplified)
    - pending: Order created, waiting for picker acceptance
    - accepted: Picker accepted the order
    - in_progress: Picker is working on the order
    - delivered: Order has been delivered (FINAL STATUS for successful orders)
    - cancelled: Order was cancelled
    - refunded: Order was refunded
*/

-- First, update any existing orders with 'completed' status to 'delivered'
UPDATE orders 
SET status = 'delivered' 
WHERE status = 'completed';

-- Drop the old constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS valid_status;

-- Add the simplified constraint without 'completed'
ALTER TABLE orders ADD CONSTRAINT valid_status 
  CHECK (status IN ('pending', 'accepted', 'in_progress', 'delivered', 'cancelled', 'refunded'));


-- =========================================
-- Migration: 20251203182113_update_escrow_release_use_delivered_status_v2.sql
-- =========================================

/*
  # Update Escrow Release to Use 'delivered' Status

  1. Changes
    - Update release_escrow_to_picker() to keep order status as 'delivered' instead of changing to 'completed'
    - 'delivered' is now the final status for successfully finished orders
    - No need to change status after payment release
*/

-- Drop and recreate the function to not change status to 'completed'
DROP FUNCTION IF EXISTS release_escrow_to_picker(uuid, uuid);

CREATE FUNCTION release_escrow_to_picker(escrow_id uuid, picker_user_id uuid)
RETURNS void AS $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Update escrow status
  UPDATE payment_escrow
  SET 
    status = 'released',
    released_at = now(),
    released_to = picker_user_id,
    notes = 'Funds released to picker after delivery confirmation'
  WHERE id = escrow_id
  AND status = 'held'
  RETURNING order_id INTO v_order_id;

  -- No need to update order status - it should already be 'delivered'
  -- Just update the updated_at timestamp
  IF v_order_id IS NOT NULL THEN
    UPDATE orders
    SET updated_at = now()
    WHERE id = v_order_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =========================================
-- Migration: 20251203205722_extend_trial_period_to_180_days.sql
-- =========================================

/*
  # Extend Trial Period to 6 Months

  1. Changes
    - Update default trial period from 60 days to 180 days (6 months)
    - Extend trial for all existing users to 180 days from their trial start date
    - This ensures adequate testing time and prevents disruption
    
  2. Notes
    - All users get extended to 180 days total trial period
    - New users will automatically get 180 days trial
    - Existing users close to expiration get extended
*/

-- Update the default for new users to 180 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '180 days');

-- Extend trial for ALL existing users to 180 days from their trial start
-- This ensures everyone gets adequate testing time
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '180 days'
WHERE trial_started_at IS NOT NULL;

-- =========================================
-- Migration: 20251205194744_update_trial_period_to_30_days.sql
-- =========================================

/*
  # Update Trial Period to 30 Days (1 Month)

  1. Changes
    - Update default trial period from 180 days to 30 days (1 month)
    - Update existing users' trial period to 30 days from their trial start date
    - This aligns with standard monthly subscription model
    
  2. Notes
    - All new users will automatically get 30 days trial
    - Existing users will have their trials adjusted to 30 days total
*/

-- Update the default for new users to 30 days
ALTER TABLE profiles 
  ALTER COLUMN trial_ends_at 
  SET DEFAULT (now() + interval '30 days');

-- Update trial for ALL existing users to 30 days from their trial start
UPDATE profiles 
SET trial_ends_at = trial_started_at + interval '30 days'
WHERE trial_started_at IS NOT NULL;

-- =========================================
-- Migration: 20260110203546_fix_profile_creation_trigger.sql
-- =========================================

/*
  # Fix Profile Creation Trigger for All Cases

  1. Changes
    - Updates trigger to handle both auto-confirm and email confirmation cases
    - Creates profile immediately if email is already confirmed (auto-confirm enabled)
    - Creates profile when email gets confirmed (email confirmation enabled)
    - Ensures profile is always created regardless of confirmation setting

  2. Security
    - Function runs with SECURITY DEFINER to access auth schema
    - Properly scoped to public schema
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user_confirmation();

-- Create improved trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';


-- =========================================
-- Migration: 20260110212530_20251007130041_create_marketplace_schema.sql
-- =========================================

/*
  # Global Souvenir Marketplace Schema

  ## Overview
  This migration creates a complete marketplace system for connecting souvenir pickers
  (travelers who collect items globally) with clients seeking specific regional souvenirs.

  ## 1. New Tables

  ### `profiles`
  - `id` (uuid, primary key) - References auth.users
  - `email` (text) - User email
  - `full_name` (text) - Display name
  - `user_type` (text) - Either 'picker' or 'client'
  - `avatar_url` (text, nullable) - Profile picture
  - `bio` (text, nullable) - User description
  - `created_at` (timestamptz) - Account creation time

  ### `picker_profiles`
  - `id` (uuid, primary key)
  - `user_id` (uuid) - References profiles
  - `current_location` (text) - Current region/country
  - `regions` (text array) - All regions they can access
  - `specialties` (text array) - Types of souvenirs they specialize in
  - `rating` (numeric) - Average rating (0-5)
  - `total_reviews` (integer) - Number of reviews received
  - `verified` (boolean) - Verification status
  - `created_at` (timestamptz)

  ### `listings`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `title` (text) - Item name
  - `description` (text) - Detailed description
  - `category` (text) - Item category
  - `region` (text) - Region/country of origin
  - `price` (numeric) - Item price
  - `image_url` (text, nullable) - Main image
  - `images` (text array) - Additional images
  - `available` (boolean) - Availability status
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `requests`
  - `id` (uuid, primary key)
  - `client_id` (uuid) - References profiles
  - `picker_id` (uuid, nullable) - Assigned picker
  - `title` (text) - Request title
  - `description` (text) - Detailed request
  - `region` (text) - Desired region
  - `category` (text) - Item category
  - `budget` (numeric) - Client budget
  - `status` (text) - 'open', 'assigned', 'in_progress', 'completed', 'cancelled'
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `messages`
  - `id` (uuid, primary key)
  - `request_id` (uuid) - References requests
  - `sender_id` (uuid) - References profiles
  - `recipient_id` (uuid) - References profiles
  - `content` (text) - Message content
  - `read` (boolean) - Read status
  - `created_at` (timestamptz)

  ### `reviews`
  - `id` (uuid, primary key)
  - `picker_id` (uuid) - References picker_profiles
  - `client_id` (uuid) - References profiles
  - `request_id` (uuid) - References requests
  - `rating` (integer) - Rating 1-5
  - `comment` (text, nullable) - Review text
  - `created_at` (timestamptz)

  ## 2. Security
  - Enable RLS on all tables
  - Users can read their own profile data
  - Users can update their own profiles
  - Public read access for picker profiles and listings
  - Request creators can read/update their requests
  - Pickers can read requests and update assigned ones
  - Message participants can read their conversations
  - Clients can create reviews for completed requests
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email text NOT NULL,
  full_name text NOT NULL,
  user_type text NOT NULL CHECK (user_type IN ('picker', 'client')),
  avatar_url text,
  bio text,
  created_at timestamptz DEFAULT now()
);

-- Create picker_profiles table
CREATE TABLE IF NOT EXISTS picker_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE UNIQUE,
  current_location text NOT NULL DEFAULT '',
  regions text[] DEFAULT '{}',
  specialties text[] DEFAULT '{}',
  rating numeric DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  total_reviews integer DEFAULT 0,
  verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create listings table
CREATE TABLE IF NOT EXISTS listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL DEFAULT '',
  region text NOT NULL,
  price numeric NOT NULL CHECK (price >= 0),
  image_url text,
  images text[] DEFAULT '{}',
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create requests table
CREATE TABLE IF NOT EXISTS requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  picker_id uuid REFERENCES picker_profiles ON DELETE SET NULL,
  title text NOT NULL,
  description text NOT NULL,
  region text NOT NULL,
  category text NOT NULL DEFAULT '',
  budget numeric CHECK (budget >= 0),
  status text DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'in_progress', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Create reviews table
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES picker_profiles ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES requests ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(request_id, client_id)
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE picker_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Picker profiles policies
CREATE POLICY "Anyone can view picker profiles"
  ON picker_profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can update own profile"
  ON picker_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Pickers can insert own profile"
  ON picker_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Listings policies
CREATE POLICY "Anyone can view available listings"
  ON listings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Pickers can create listings"
  ON listings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can update own listings"
  ON listings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

CREATE POLICY "Pickers can delete own listings"
  ON listings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM picker_profiles
      WHERE picker_profiles.id = picker_id
      AND picker_profiles.user_id = auth.uid()
    )
  );

-- Requests policies
CREATE POLICY "Users can view relevant requests"
  ON requests FOR SELECT
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    ) OR
    (status = 'open' AND picker_id IS NULL)
  );

CREATE POLICY "Clients can create requests"
  ON requests FOR INSERT
  TO authenticated
  WITH CHECK (client_id = auth.uid());

CREATE POLICY "Request owners can update"
  ON requests FOR UPDATE
  TO authenticated
  USING (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    client_id = auth.uid() OR
    picker_id IN (
      SELECT id FROM picker_profiles WHERE user_id = auth.uid()
    )
  );

-- Messages policies
CREATE POLICY "Users can view their messages"
  ON messages FOR SELECT
  TO authenticated
  USING (sender_id = auth.uid() OR recipient_id = auth.uid());

CREATE POLICY "Users can send messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update their received messages"
  ON messages FOR UPDATE
  TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- Reviews policies
CREATE POLICY "Anyone can view reviews"
  ON reviews FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Clients can create reviews"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    client_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM requests
      WHERE requests.id = request_id
      AND requests.client_id = auth.uid()
      AND requests.status = 'completed'
    )
  );

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_picker_profiles_user_id ON picker_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_listings_picker_id ON listings(picker_id);
CREATE INDEX IF NOT EXISTS idx_listings_region ON listings(region);
CREATE INDEX IF NOT EXISTS idx_requests_client_id ON requests(client_id);
CREATE INDEX IF NOT EXISTS idx_requests_picker_id ON requests(picker_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON requests(status);
CREATE INDEX IF NOT EXISTS idx_messages_request_id ON messages(request_id);
CREATE INDEX IF NOT EXISTS idx_reviews_picker_id ON reviews(picker_id);

-- =========================================
-- Migration: 20260110212634_consolidate_missing_profile_fields_and_auth.sql
-- =========================================

/*
  # Consolidate Missing Profile Fields and Auth Setup

  1. Changes
    - Add all missing subscription fields to profiles table
    - Add billing and social media fields
    - Add default delivery address field
    - Add admin flag
    - Create profile creation trigger for auth

  2. Security
    - Maintains existing RLS policies
    - Creates trigger with SECURITY DEFINER
*/

-- Add subscription fields
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS trial_started_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz DEFAULT (now() + interval '30 days'),
ADD COLUMN IF NOT EXISTS subscription_status text DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'cancelled')),
ADD COLUMN IF NOT EXISTS subscription_started_at timestamptz,
ADD COLUMN IF NOT EXISTS last_payment_date timestamptz,
ADD COLUMN IF NOT EXISTS next_payment_due timestamptz,
ADD COLUMN IF NOT EXISTS payment_failed boolean DEFAULT false;

-- Add billing fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS company_name text,
ADD COLUMN IF NOT EXISTS billing_address text,
ADD COLUMN IF NOT EXISTS billing_city text,
ADD COLUMN IF NOT EXISTS billing_postal_code text,
ADD COLUMN IF NOT EXISTS billing_country text,
ADD COLUMN IF NOT EXISTS tax_id text,
ADD COLUMN IF NOT EXISTS billing_email text,
ADD COLUMN IF NOT EXISTS billing_phone text;

-- Add delivery address
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS default_delivery_address text;

-- Add social media fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS facebook_url text,
ADD COLUMN IF NOT EXISTS twitter_url text,
ADD COLUMN IF NOT EXISTS instagram_url text,
ADD COLUMN IF NOT EXISTS threads_url text;

-- Add admin flag
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Create profile creation trigger function
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  full_name_val text;
  user_type_val text;
BEGIN
  -- Extract metadata
  full_name_val := COALESCE(NEW.raw_user_meta_data->>'full_name', 'User');
  user_type_val := COALESCE(NEW.raw_user_meta_data->>'user_type', 'client');
  
  -- Check if profile already exists
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    -- Determine if we should create profile now
    -- Case 1: Email confirmation disabled (email_confirmed_at set immediately on INSERT)
    -- Case 2: Email confirmation enabled and user just confirmed (UPDATE with email_confirmed_at changing from NULL to timestamp)
    IF (TG_OP = 'INSERT' AND NEW.email_confirmed_at IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND NEW.email_confirmed_at IS NOT NULL AND OLD.email_confirmed_at IS NULL) THEN
      
      -- Create profile
      INSERT INTO profiles (
        id,
        email,
        full_name,
        user_type,
        trial_started_at,
        trial_ends_at,
        subscription_status
      ) VALUES (
        NEW.id,
        NEW.email,
        full_name_val,
        user_type_val,
        now(),
        now() + interval '30 days',
        'trial'
      );
      
      -- Create picker profile if needed
      IF user_type_val = 'picker' THEN
        INSERT INTO picker_profiles (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
      
      RAISE LOG 'Profile created for user %', NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for INSERT (handles auto-confirm case)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Create trigger for UPDATE (handles email confirmation case)
CREATE TRIGGER on_auth_user_confirmed
  AFTER UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Update existing profiles to have subscription data
UPDATE profiles
SET 
  trial_started_at = COALESCE(trial_started_at, created_at),
  trial_ends_at = COALESCE(trial_ends_at, created_at + interval '30 days'),
  subscription_status = COALESCE(subscription_status, 'trial'),
  payment_failed = COALESCE(payment_failed, false)
WHERE trial_started_at IS NULL OR trial_ends_at IS NULL OR subscription_status IS NULL;

-- Add comment
COMMENT ON FUNCTION handle_new_user() IS 'Automatically creates profile and picker_profile when user is created (auto-confirm) or confirms email (email confirmation enabled)';
