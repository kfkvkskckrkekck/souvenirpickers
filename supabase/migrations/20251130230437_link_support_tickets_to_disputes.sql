/*
  # Link Support Tickets to Disputes

  1. Changes
    - Adds optional dispute_id column to support_tickets table
    - Creates foreign key relationship between tickets and disputes
    - Allows support team to quickly navigate from ticket to dispute

  2. Security
    - No RLS changes needed (inherits from existing policies)
*/

-- Add dispute_id column to support_tickets
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
