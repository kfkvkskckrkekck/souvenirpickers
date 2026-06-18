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
