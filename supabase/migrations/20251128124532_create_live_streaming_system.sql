/*
  # Live Streaming System

  1. New Tables
    - `live_streams`
      - Active live streams from pickers
      - Stream metadata and status
      - Location and viewer counts

    - `stream_viewers`
      - Track who is watching streams
      - Real-time viewer analytics

    - `stream_chat_messages`
      - Live chat during streams
      - Real-time messaging

    - `stream_item_requests`
      - Collectors can request items during live streams
      - Real-time shopping experience

  2. Security
    - Enable RLS on all tables
    - Anyone can view active streams
    - Only pickers can create streams
    - Authenticated users can chat and request items

  3. Features
    - Real-time viewer tracking
    - Live chat functionality
    - Item request system
    - Stream analytics
*/

-- Live streams table
CREATE TABLE IF NOT EXISTS live_streams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  thumbnail_url text,
  stream_url text,
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  status text NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'ended')),
  viewer_count integer DEFAULT 0,
  peak_viewers integer DEFAULT 0,
  total_views integer DEFAULT 0,
  started_at timestamptz DEFAULT now(),
  ended_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS live_streams_picker_id_idx ON live_streams(picker_id);
CREATE INDEX IF NOT EXISTS live_streams_status_idx ON live_streams(status);
CREATE INDEX IF NOT EXISTS live_streams_started_at_idx ON live_streams(started_at DESC);

-- Stream viewers table
CREATE TABLE IF NOT EXISTS stream_viewers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  left_at timestamptz,
  is_active boolean DEFAULT true,
  UNIQUE(stream_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS stream_viewers_stream_id_idx ON stream_viewers(stream_id);
CREATE INDEX IF NOT EXISTS stream_viewers_viewer_id_idx ON stream_viewers(viewer_id);
CREATE INDEX IF NOT EXISTS stream_viewers_is_active_idx ON stream_viewers(is_active);

-- Stream chat messages table
CREATE TABLE IF NOT EXISTS stream_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stream_chat_messages_stream_id_idx ON stream_chat_messages(stream_id);
CREATE INDEX IF NOT EXISTS stream_chat_messages_created_at_idx ON stream_chat_messages(created_at DESC);

-- Stream item requests table
CREATE TABLE IF NOT EXISTS stream_item_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id uuid NOT NULL REFERENCES live_streams(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  description text,
  max_price decimal(10, 2),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'fulfilled')),
  linked_listing_id uuid REFERENCES listings(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stream_item_requests_stream_id_idx ON stream_item_requests(stream_id);
CREATE INDEX IF NOT EXISTS stream_item_requests_requester_id_idx ON stream_item_requests(requester_id);
CREATE INDEX IF NOT EXISTS stream_item_requests_status_idx ON stream_item_requests(status);

-- Enable RLS
ALTER TABLE live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_viewers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE stream_item_requests ENABLE ROW LEVEL SECURITY;

-- Live streams policies
CREATE POLICY "Anyone can view active streams"
  ON live_streams FOR SELECT
  USING (true);

CREATE POLICY "Pickers can create streams"
  ON live_streams FOR INSERT
  TO authenticated
  WITH CHECK (
    picker_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND user_type = 'picker')
  );

CREATE POLICY "Pickers can update own streams"
  ON live_streams FOR UPDATE
  TO authenticated
  USING (picker_id = auth.uid())
  WITH CHECK (picker_id = auth.uid());

-- Stream viewers policies
CREATE POLICY "Anyone can view stream viewers"
  ON stream_viewers FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can join streams"
  ON stream_viewers FOR INSERT
  TO authenticated
  WITH CHECK (viewer_id = auth.uid());

CREATE POLICY "Users can update own viewer status"
  ON stream_viewers FOR UPDATE
  TO authenticated
  USING (viewer_id = auth.uid())
  WITH CHECK (viewer_id = auth.uid());

-- Stream chat policies
CREATE POLICY "Anyone can view stream chat"
  ON stream_chat_messages FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can send chat messages"
  ON stream_chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Stream item requests policies
CREATE POLICY "Anyone can view item requests"
  ON stream_item_requests FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create item requests"
  ON stream_item_requests FOR INSERT
  TO authenticated
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Picker can update requests for their stream"
  ON stream_item_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM live_streams
      WHERE live_streams.id = stream_item_requests.stream_id
      AND live_streams.picker_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM live_streams
      WHERE live_streams.id = stream_item_requests.stream_id
      AND live_streams.picker_id = auth.uid()
    )
  );

-- Function to update viewer count
CREATE OR REPLACE FUNCTION update_stream_viewer_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_count integer;
  stream_peak integer;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.is_active THEN
    UPDATE live_streams
    SET viewer_count = viewer_count + 1,
        total_views = total_views + 1
    WHERE id = NEW.stream_id
    RETURNING viewer_count, peak_viewers INTO current_count, stream_peak;
    
    IF current_count > stream_peak THEN
      UPDATE live_streams
      SET peak_viewers = current_count
      WHERE id = NEW.stream_id;
    END IF;
    
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_active AND NOT NEW.is_active THEN
      UPDATE live_streams
      SET viewer_count = viewer_count - 1
      WHERE id = NEW.stream_id;
    ELSIF NOT OLD.is_active AND NEW.is_active THEN
      UPDATE live_streams
      SET viewer_count = viewer_count + 1
      WHERE id = NEW.stream_id
      RETURNING viewer_count, peak_viewers INTO current_count, stream_peak;
      
      IF current_count > stream_peak THEN
        UPDATE live_streams
        SET peak_viewers = current_count
        WHERE id = NEW.stream_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_stream_viewer_change
  AFTER INSERT OR UPDATE ON stream_viewers
  FOR EACH ROW
  EXECUTE FUNCTION update_stream_viewer_count();