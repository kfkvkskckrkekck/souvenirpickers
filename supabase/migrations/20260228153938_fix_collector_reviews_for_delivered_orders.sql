/*
  # Fix Collector Reviews for Delivered Orders

  1. Changes
    - Drop and recreate the "Users can create reviews for completed orders" policy to allow reviews for delivered orders
    - Add check to prevent duplicate reviews for the same order
    - Add notification trigger when a collector submits a review

  2. Security
    - Maintains RLS on reviews table
    - Ensures collectors can only review their own orders
    - Ensures orders are in delivered status before review
*/

-- Drop the existing policy that requires 'completed' status
DROP POLICY IF EXISTS "Users can create reviews for completed orders" ON reviews;

-- Create new policy that allows reviews for delivered orders
CREATE POLICY "Collectors can create reviews for delivered orders"
  ON reviews FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = client_id AND
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_id 
      AND orders.client_id = auth.uid()
      AND orders.status = 'delivered'
    )
    AND NOT EXISTS (
      SELECT 1 FROM reviews
      WHERE reviews.order_id = order_id
      AND reviews.client_id = auth.uid()
    )
  );

-- Function to notify picker when they receive a review
CREATE OR REPLACE FUNCTION notify_picker_on_review()
RETURNS TRIGGER AS $$
BEGIN
  -- Create notification for the picker
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    metadata,
    read
  )
  VALUES (
    NEW.picker_id,
    'review_received',
    'New Review Received',
    'You received a ' || NEW.rating || '-star review from a collector.',
    jsonb_build_object(
      'review_id', NEW.id,
      'order_id', NEW.order_id,
      'rating', NEW.rating,
      'client_id', NEW.client_id
    ),
    false
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to send notification when review is created
DROP TRIGGER IF EXISTS trigger_notify_picker_on_review ON reviews;
CREATE TRIGGER trigger_notify_picker_on_review
  AFTER INSERT ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION notify_picker_on_review();