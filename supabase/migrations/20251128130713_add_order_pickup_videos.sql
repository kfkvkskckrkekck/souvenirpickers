/*
  # Add Order Pickup Videos Feature

  1. Changes
    - Add `pickup_video_url` column to orders table
    - Add `pickup_video_uploaded_at` timestamp column
    - Add `pickup_video_thumbnail_url` for video previews
    - Create notification trigger when pickup video is uploaded
    - Add RLS policies for video access

  2. Security
    - Pickers can upload videos to their own orders
    - Collectors can view videos for their orders
    - Videos are optional and enhance the customer experience

  3. Notes
    - Videos should be uploaded to Supabase Storage
    - Automatic notification sent to collector when video is added
    - Provides a personal touch and builds trust
*/

-- Add pickup video columns to orders table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_url'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_uploaded_at'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_uploaded_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'pickup_video_thumbnail_url'
  ) THEN
    ALTER TABLE orders ADD COLUMN pickup_video_thumbnail_url text;
  END IF;
END $$;

-- Create function to notify collector when pickup video is uploaded
CREATE OR REPLACE FUNCTION notify_collector_of_pickup_video()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
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

    -- Create notification for collector
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      related_id,
      created_at
    ) VALUES (
      NEW.client_id,
      'pickup_video',
      'Pickup Moment Captured! 🎥',
      v_picker_name || ' shared a video of picking up your ' || v_listing_title,
      NEW.id,
      now()
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for pickup video notifications
DROP TRIGGER IF EXISTS on_pickup_video_uploaded ON orders;
CREATE TRIGGER on_pickup_video_uploaded
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_collector_of_pickup_video();

-- Add RLS policy for pickers to update pickup videos on their orders
CREATE POLICY "Pickers can add pickup videos to their orders"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = picker_id)
  WITH CHECK (auth.uid() = picker_id);

-- Add comment for documentation
COMMENT ON COLUMN orders.pickup_video_url IS 'URL to video of picker finding/purchasing the item';
COMMENT ON COLUMN orders.pickup_video_uploaded_at IS 'Timestamp when pickup video was uploaded';
COMMENT ON COLUMN orders.pickup_video_thumbnail_url IS 'Thumbnail preview image for the pickup video';