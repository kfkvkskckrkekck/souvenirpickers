/*
  # Create Automatic Support Notification for Disputes

  1. Changes
    - Creates a function to automatically generate support tickets when disputes are filed
    - Creates a trigger that executes after a dispute is inserted
    - Support team will receive a ticket for every new dispute with full context

  2. Details
    - Automatically creates a high-priority support ticket when dispute is filed
    - Includes dispute details, order info, and parties involved
    - Links the support ticket to the user who filed the dispute
    - Sets priority to 'high' for immediate attention
*/

-- Function to create support ticket when dispute is filed
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

  -- Create support ticket
  INSERT INTO support_tickets (
    user_id,
    subject,
    message,
    category,
    status,
    priority
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
    'high'
  );

  RETURN NEW;
END;
$$;

-- Create trigger to execute function after dispute insert
DROP TRIGGER IF EXISTS on_dispute_filed ON disputes;

CREATE TRIGGER on_dispute_filed
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION notify_support_of_dispute();

-- Add comment
COMMENT ON FUNCTION notify_support_of_dispute() IS 'Automatically creates a high-priority support ticket when a dispute is filed';
