/*
  # Add dispute_type Column to Disputes Table

  1. Changes
    - Add `dispute_type` column to disputes table
    - This column categorizes the type of dispute
    - Update trigger function to include dispute_type in notifications
  
  2. Security
    - Maintain existing RLS policies
*/

-- Add dispute_type column to disputes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'disputes' AND column_name = 'dispute_type'
  ) THEN
    ALTER TABLE disputes ADD COLUMN dispute_type text NOT NULL DEFAULT 'other'
      CHECK (dispute_type IN ('non_delivery', 'wrong_item', 'damaged_item', 'quality_issue', 'refund_request', 'other'));
    
    -- Remove default after adding the column
    ALTER TABLE disputes ALTER COLUMN dispute_type DROP DEFAULT;
  END IF;
END $$;

-- Update the dispute notification trigger function to include dispute_type
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
      'reason', NEW.reason,
      'dispute_type', NEW.dispute_type
    )
  );
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error sending dispute notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the support ticket creation function to include dispute_type
CREATE OR REPLACE FUNCTION create_support_ticket_from_dispute()
RETURNS TRIGGER AS $$
DECLARE
  v_filer_name text;
  v_against_name text;
  v_order_id text;
  v_ticket_id uuid;
BEGIN
  -- Get user names
  SELECT full_name INTO v_filer_name FROM profiles WHERE id = NEW.raised_by;
  SELECT full_name INTO v_against_name FROM profiles WHERE id = NEW.against_user;
  
  v_order_id := substring(NEW.order_id::text, 1, 8);
  
  -- Create a support ticket for the dispute
  INSERT INTO support_tickets (
    user_id,
    subject,
    message,
    category,
    priority,
    status,
    dispute_id
  ) VALUES (
    NEW.raised_by,
    'Dispute Filed - Order #' || v_order_id,
    'Dispute Details:
- Filer: ' || COALESCE(v_filer_name, 'Unknown') || '
- Against: ' || COALESCE(v_against_name, 'Unknown') || '
- Type: ' || NEW.dispute_type || '
- Reason: ' || NEW.reason || '
- Description: ' || NEW.description,
    'dispute',
    CASE 
      WHEN NEW.dispute_type IN ('non_delivery', 'refund_request') THEN 'high'
      WHEN NEW.dispute_type IN ('wrong_item', 'damaged_item') THEN 'medium'
      ELSE 'normal'
    END,
    'open',
    NEW.id
  )
  RETURNING id INTO v_ticket_id;
  
  -- Notify support team
  INSERT INTO notifications (user_id, type, title, message, metadata)
  SELECT 
    id,
    'new_dispute',
    'New Dispute Requires Review',
    'A dispute has been filed for order #' || v_order_id || ' by ' || COALESCE(v_filer_name, 'a user'),
    jsonb_build_object(
      'dispute_id', NEW.id,
      'ticket_id', v_ticket_id,
      'order_id', NEW.order_id
    )
  FROM profiles
  WHERE user_type = 'admin';
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating support ticket from dispute: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS on_dispute_support_ticket ON disputes;
CREATE TRIGGER on_dispute_support_ticket
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION create_support_ticket_from_dispute();