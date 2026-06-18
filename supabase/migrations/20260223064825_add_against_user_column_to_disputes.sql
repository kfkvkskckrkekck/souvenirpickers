/*
  # Add against_user Column to Disputes Table

  1. Changes
    - Add `against_user` column to disputes table
    - This column references the user the dispute is filed against
    - Update RLS policies to include against_user access
    - Update trigger function to use against_user column
  
  2. Security
    - Maintain existing RLS policies
    - Allow users to view disputes filed by them or against them
*/

-- Add against_user column to disputes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'disputes' AND column_name = 'against_user'
  ) THEN
    ALTER TABLE disputes ADD COLUMN against_user uuid REFERENCES profiles(id) ON DELETE CASCADE;
    
    -- Populate against_user from order information
    -- If raised_by is the client, against_user is the picker, and vice versa
    UPDATE disputes d
    SET against_user = CASE 
      WHEN d.raised_by = o.client_id THEN o.picker_id
      WHEN d.raised_by = o.picker_id THEN o.client_id
      ELSE NULL
    END
    FROM orders o
    WHERE d.order_id = o.id
      AND d.against_user IS NULL;
    
    -- Make it NOT NULL after population
    ALTER TABLE disputes ALTER COLUMN against_user SET NOT NULL;
  END IF;
END $$;

-- Drop existing RLS policies for disputes
DROP POLICY IF EXISTS "Users can view their disputes" ON disputes;
DROP POLICY IF EXISTS "Users can create disputes" ON disputes;
DROP POLICY IF EXISTS "Users can update their disputes" ON disputes;

-- Recreate RLS policies with against_user support
CREATE POLICY "Users can view their disputes"
  ON disputes FOR SELECT
  TO authenticated
  USING (auth.uid() = raised_by OR auth.uid() = against_user);

CREATE POLICY "Users can create disputes"
  ON disputes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = raised_by);

CREATE POLICY "Users can update their disputes"
  ON disputes FOR UPDATE
  TO authenticated
  USING (auth.uid() = raised_by OR auth.uid() = against_user);

-- Update the dispute notification trigger function
CREATE OR REPLACE FUNCTION notify_new_dispute()
RETURNS TRIGGER AS $$
DECLARE
  v_filer_name text;
  v_against_name text;
  v_order_id text;
BEGIN
  -- Get user names
  SELECT full_name INTO v_filer_name FROM profiles WHERE id = NEW.raised_by;
  SELECT full_name INTO v_against_name FROM profiles WHERE id = NEW.against_user;
  
  v_order_id := substring(NEW.order_id::text, 1, 8);
  
  -- Notify the user the dispute is filed against
  INSERT INTO notifications (user_id, type, title, message, metadata)
  VALUES (
    NEW.against_user,
    'dispute_filed',
    'Dispute Filed Against You',
    COALESCE(v_filer_name, 'A user') || ' has filed a dispute regarding order #' || v_order_id,
    jsonb_build_object(
      'dispute_id', NEW.id,
      'order_id', NEW.order_id,
      'filed_by', NEW.raised_by,
      'reason', NEW.reason
    )
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error sending dispute notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS on_dispute_created ON disputes;
CREATE TRIGGER on_dispute_created
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_dispute();