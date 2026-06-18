/*
  # Social Feed & Stories System

  1. New Tables
    - `stories`
      - Ephemeral content from pickers (24-hour lifespan)
      - Photos/videos from markets, events, travels
      - Links to picker's current location

    - `story_views`
      - Tracks who viewed which stories
      - Used for analytics and "seen by" features

    - `story_reactions`
      - Emoji reactions to stories
      - Real-time engagement metrics

    - `feed_posts`
      - Permanent social posts from pickers
      - Showcase completed orders, featured items
      - Community building content

    - `post_reactions`
      - Likes and reactions to feed posts

    - `post_comments`
      - Comments on feed posts
      - Enable community discussion

  2. Security
    - Enable RLS on all tables
    - Anyone can view public stories/posts
    - Only creators can manage their content
    - Authenticated users can react and comment

  3. Features
    - 24-hour auto-expiry for stories
    - Real-time view tracking
    - Multiple media per post
    - Hashtag support
    - Location tagging
*/

-- Stories table (Instagram-style stories)
CREATE TABLE IF NOT EXISTS stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  picker_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  media_url text NOT NULL,
  media_type text NOT NULL CHECK (media_type IN ('image', 'video')),
  thumbnail_url text,
  caption text,
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  view_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stories_picker_id_idx ON stories(picker_id);
CREATE INDEX IF NOT EXISTS stories_expires_at_idx ON stories(expires_at);
CREATE INDEX IF NOT EXISTS stories_created_at_idx ON stories(created_at DESC);

-- Story views tracking
CREATE TABLE IF NOT EXISTS story_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  viewed_at timestamptz DEFAULT now(),
  UNIQUE(story_id, viewer_id)
);

CREATE INDEX IF NOT EXISTS story_views_story_id_idx ON story_views(story_id);
CREATE INDEX IF NOT EXISTS story_views_viewer_id_idx ON story_views(viewer_id);

-- Story reactions
CREATE TABLE IF NOT EXISTS story_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL CHECK (reaction IN ('like', 'love', 'fire', 'clap', 'wow')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(story_id, user_id)
);

CREATE INDEX IF NOT EXISTS story_reactions_story_id_idx ON story_reactions(story_id);
CREATE INDEX IF NOT EXISTS story_reactions_user_id_idx ON story_reactions(user_id);

-- Feed posts (permanent social content)
CREATE TABLE IF NOT EXISTS feed_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  media_urls text[] DEFAULT '{}',
  media_types text[] DEFAULT '{}',
  hashtags text[] DEFAULT '{}',
  location text,
  latitude decimal(10, 8),
  longitude decimal(11, 8),
  linked_order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  linked_listing_id uuid REFERENCES listings(id) ON DELETE SET NULL,
  is_pinned boolean DEFAULT false,
  view_count integer DEFAULT 0,
  reaction_count integer DEFAULT 0,
  comment_count integer DEFAULT 0,
  share_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS feed_posts_user_id_idx ON feed_posts(user_id);
CREATE INDEX IF NOT EXISTS feed_posts_created_at_idx ON feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS feed_posts_hashtags_idx ON feed_posts USING gin(hashtags);
CREATE INDEX IF NOT EXISTS feed_posts_linked_order_id_idx ON feed_posts(linked_order_id);

-- Post reactions
CREATE TABLE IF NOT EXISTS post_reactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reaction text NOT NULL CHECK (reaction IN ('like', 'love', 'fire', 'clap', 'wow', 'celebrate')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX IF NOT EXISTS post_reactions_post_id_idx ON post_reactions(post_id);
CREATE INDEX IF NOT EXISTS post_reactions_user_id_idx ON post_reactions(user_id);

-- Post comments
CREATE TABLE IF NOT EXISTS post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content text NOT NULL,
  parent_comment_id uuid REFERENCES post_comments(id) ON DELETE CASCADE,
  is_edited boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS post_comments_post_id_idx ON post_comments(post_id);
CREATE INDEX IF NOT EXISTS post_comments_user_id_idx ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS post_comments_parent_id_idx ON post_comments(parent_comment_id);

-- Enable RLS
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Stories policies
CREATE POLICY "Anyone can view active stories"
  ON stories FOR SELECT
  USING (expires_at > now());

CREATE POLICY "Pickers can create stories"
  ON stories FOR INSERT
  TO authenticated
  WITH CHECK (
    picker_id = auth.uid() AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND user_type = 'picker')
  );

CREATE POLICY "Pickers can delete own stories"
  ON stories FOR DELETE
  TO authenticated
  USING (picker_id = auth.uid());

-- Story views policies
CREATE POLICY "Anyone can view story views"
  ON story_views FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can record story views"
  ON story_views FOR INSERT
  TO authenticated
  WITH CHECK (viewer_id = auth.uid());

-- Story reactions policies
CREATE POLICY "Anyone can view story reactions"
  ON story_reactions FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can add story reactions"
  ON story_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own story reactions"
  ON story_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Feed posts policies
CREATE POLICY "Anyone can view feed posts"
  ON feed_posts FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create posts"
  ON feed_posts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own posts"
  ON feed_posts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own posts"
  ON feed_posts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Post reactions policies
CREATE POLICY "Anyone can view post reactions"
  ON post_reactions FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can add reactions"
  ON post_reactions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own reactions"
  ON post_reactions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Post comments policies
CREATE POLICY "Anyone can view comments"
  ON post_comments FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create comments"
  ON post_comments FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own comments"
  ON post_comments FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own comments"
  ON post_comments FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Function to increment story view count
CREATE OR REPLACE FUNCTION increment_story_views()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE stories
  SET view_count = view_count + 1
  WHERE id = NEW.story_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_story_view_increment
  AFTER INSERT ON story_views
  FOR EACH ROW
  EXECUTE FUNCTION increment_story_views();

-- Function to update post reaction count
CREATE OR REPLACE FUNCTION update_post_reaction_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE feed_posts
    SET reaction_count = reaction_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE feed_posts
    SET reaction_count = reaction_count - 1
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER on_post_reaction_change
  AFTER INSERT OR DELETE ON post_reactions
  FOR EACH ROW
  EXECUTE FUNCTION update_post_reaction_count();

-- Function to update post comment count
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE feed_posts
    SET comment_count = comment_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE feed_posts
    SET comment_count = comment_count - 1
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER on_post_comment_change
  AFTER INSERT OR DELETE ON post_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_post_comment_count();