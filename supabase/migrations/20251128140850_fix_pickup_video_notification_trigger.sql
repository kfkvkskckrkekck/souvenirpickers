/*
  # Fix Pickup Video Notification Trigger

  1. Changes
    - Update the `notify_collector_of_pickup_video` function to use correct notification columns
    - Remove the non-existent `related_id` column reference
    - Add the order link to the notification instead

  2. Notes
    - The notifications table doesn't have a `related_id` column
    - Use the `link` column to provide a direct link to the order
*/

-- Drop and recreate the function with correct column references
CREATE OR REPLACE FUNCTION public.notify_collector_of_pickup_video()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_picker_name text;
  v_listing_title text;
BEGIN
  -- Only proceed if pickup_video_url was just added (changed from null to a value)
  IF OLD.pickup_video_url IS NULL AND NEW.pickup_video_url IS NOT NULL THEN
    -- Get picker name and listing title
    SELECT p.full_name, l.title
    INTO v_picker_name, v_listing_title
    FROM profiles p
    JOIN listings l ON l.id = NEW.listing_id
    WHERE p.id = NEW.picker_id;

    -- Create notification for collector (using correct column names)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      link,
      read,
      created_at
    ) VALUES (
      NEW.client_id,
      'pickup_video',
      'Pickup Moment Captured! 🎥',
      v_picker_name || ' shared a video of picking up your ' || v_listing_title,
      '/orders',
      false,
      now()
    );
  END IF;

  RETURN NEW;
END;
$function$;
