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
