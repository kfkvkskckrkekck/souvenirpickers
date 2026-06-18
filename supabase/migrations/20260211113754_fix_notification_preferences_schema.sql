/*
  # Fix Notification Preferences Schema

  1. Changes
    - Add missing notification preference columns to match the NotificationSettings component
    - The component is saving: email_new_message, email_order_status, email_payment_received, etc.
    - The table currently has: email_enabled, push_enabled, order_updates, new_messages, etc.
    
  2. New Columns Added
    - email_new_message
    - email_order_status
    - email_payment_received
    - email_review_received
    - email_marketing
    - push_new_message
    - push_order_status
    - push_payment_received
    - sms_order_shipped
    - sms_order_delivered
*/

-- Add new columns with default values matching the component's expectations
DO $$
BEGIN
  -- Email notification columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'email_new_message'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN email_new_message boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'email_order_status'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN email_order_status boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'email_payment_received'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN email_payment_received boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'email_review_received'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN email_review_received boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'email_marketing'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN email_marketing boolean DEFAULT false;
  END IF;

  -- Push notification columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'push_new_message'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN push_new_message boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'push_order_status'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN push_order_status boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'push_payment_received'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN push_payment_received boolean DEFAULT true;
  END IF;

  -- SMS notification columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'sms_order_shipped'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN sms_order_shipped boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notification_preferences' AND column_name = 'sms_order_delivered'
  ) THEN
    ALTER TABLE notification_preferences ADD COLUMN sms_order_delivered boolean DEFAULT false;
  END IF;
END $$;