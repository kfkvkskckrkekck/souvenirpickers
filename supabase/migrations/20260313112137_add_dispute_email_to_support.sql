/*
  # Add Email Notification to Support for Disputes

  1. Changes
    - Creates a function to send email to support@souvenirpickers.com when a dispute is filed
    - Creates a trigger that executes after a dispute is inserted
    - Support team will receive email notification for every new dispute
  
  2. Details
    - Sends email to support@souvenirpickers.com via Titan email
    - Includes all dispute details: type, description, order info, and parties involved
    - Works alongside the existing support ticket creation
*/

-- Function to send email to support team when dispute is filed
CREATE OR REPLACE FUNCTION send_dispute_email_to_support()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_title text;
  v_filer_name text;
  v_filer_email text;
  v_against_name text;
  v_against_email text;
  v_supabase_url text;
  v_function_url text;
  v_request_id bigint;
  v_support_email text;
  v_dispute_type_label text;
BEGIN
  -- Get order and user details
  SELECT 
    l.title,
    p1.full_name,
    p1.email,
    p2.full_name,
    p2.email
  INTO 
    v_order_title,
    v_filer_name,
    v_filer_email,
    v_against_name,
    v_against_email
  FROM orders o
  JOIN listings l ON l.id = o.listing_id
  JOIN profiles p1 ON p1.id = NEW.filed_by
  JOIN profiles p2 ON p2.id = NEW.against_user
  WHERE o.id = NEW.order_id;
  
  -- Set support email
  v_support_email := 'support@souvenirpickers.com';
  
  -- Set Supabase URL
  v_supabase_url := 'https://bfqvzxczmvfteqbhgyvx.supabase.co';
  v_function_url := v_supabase_url || '/functions/v1/send-email-notification';
  
  -- Format dispute type for readability
  v_dispute_type_label := CASE NEW.dispute_type
    WHEN 'item_not_received' THEN 'Item Not Received'
    WHEN 'item_damaged' THEN 'Item Damaged'
    WHEN 'not_as_described' THEN 'Not As Described'
    WHEN 'incorrect_item' THEN 'Incorrect Item'
    WHEN 'quality_issue' THEN 'Quality Issue'
    WHEN 'delivery_issue' THEN 'Delivery Issue'
    WHEN 'payment_issue' THEN 'Payment Issue'
    WHEN 'other' THEN 'Other'
    ELSE NEW.dispute_type
  END;
  
  -- Send email notification to support team
  BEGIN
    SELECT net.http_post(
      url := v_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
      ),
      body := jsonb_build_object(
        'to', v_support_email,
        'subject', 'URGENT: New Dispute Filed - ' || COALESCE(v_order_title, 'Order #' || NEW.order_id),
        'type', 'dispute_notification',
        'data', jsonb_build_object(
          'dispute_id', NEW.id,
          'order_id', NEW.order_id,
          'order_title', COALESCE(v_order_title, 'Unknown'),
          'dispute_type', v_dispute_type_label,
          'filed_by_name', COALESCE(v_filer_name, 'Unknown'),
          'filed_by_email', COALESCE(v_filer_email, 'unknown@example.com'),
          'against_user_name', COALESCE(v_against_name, 'Unknown'),
          'against_user_email', COALESCE(v_against_email, 'unknown@example.com'),
          'description', NEW.description,
          'status', NEW.status,
          'created_at', NEW.created_at
        )
      )
    ) INTO v_request_id;
    
    RAISE NOTICE 'Dispute email notification sent to %: dispute_id=%, request_id=%', 
      v_support_email, NEW.id, v_request_id;
    
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the dispute creation
    RAISE WARNING 'Failed to send dispute email to support: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
  END;
  
  RETURN NEW;
END;
$$;

-- Create trigger to send email after dispute is created
DROP TRIGGER IF EXISTS on_dispute_filed_send_email ON disputes;

CREATE TRIGGER on_dispute_filed_send_email
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION send_dispute_email_to_support();

-- Add comment
COMMENT ON FUNCTION send_dispute_email_to_support() IS 'Sends email notification to support@souvenirpickers.com when a dispute is filed';