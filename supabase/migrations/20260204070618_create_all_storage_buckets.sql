/*
  # Create All Required Storage Buckets
  
  1. Storage Buckets Created
    - `listing-images` - For listing/product images
    - `listing-videos` - For listing/product videos
    - `profile-avatars` - For user profile pictures
    - `pickup-videos` - For order pickup/delivery videos
    - `media` - For social feed stories and general media
  
  2. Security
    - All buckets are public (files are publicly accessible via URL)
    - RLS policies control who can upload/update/delete
    - Authenticated users can upload to their own folders
    - Users can only delete their own files
*/

-- Create listing-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'listing-images',
  'listing-images',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- Create listing-videos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'listing-videos',
  'listing-videos',
  true,
  52428800, -- 50MB
  ARRAY['video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime'];

-- Create profile-avatars bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-avatars',
  'profile-avatars',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- Create pickup-videos bucket (already exists in migrations but ensuring it's created)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pickup-videos',
  'pickup-videos',
  true,
  52428800, -- 50MB
  ARRAY['video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime'];

-- Create media bucket (for social feed/stories)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  52428800, -- 50MB
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'];

-- RLS Policies for listing-images bucket
CREATE POLICY "Authenticated users can upload listing images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listing-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can view listing images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'listing-images');

CREATE POLICY "Users can update their own listing images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listing-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own listing images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listing-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS Policies for listing-videos bucket
CREATE POLICY "Authenticated users can upload listing videos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'listing-videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can view listing videos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'listing-videos');

CREATE POLICY "Users can update their own listing videos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'listing-videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own listing videos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'listing-videos' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS Policies for profile-avatars bucket
CREATE POLICY "Authenticated users can upload profile avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Anyone can view profile avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-avatars');

CREATE POLICY "Users can update their own profile avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own profile avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-avatars' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS Policies for pickup-videos bucket (if not already created)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Authenticated users can upload pickup videos'
  ) THEN
    CREATE POLICY "Authenticated users can upload pickup videos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'pickup-videos' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Anyone can view pickup videos'
  ) THEN
    CREATE POLICY "Anyone can view pickup videos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'pickup-videos');
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can update their own pickup videos'
  ) THEN
    CREATE POLICY "Users can update their own pickup videos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
      bucket_id = 'pickup-videos' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can delete their own pickup videos'
  ) THEN
    CREATE POLICY "Users can delete their own pickup videos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'pickup-videos' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;

-- RLS Policies for media bucket (if not already created)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Authenticated users can upload media'
  ) THEN
    CREATE POLICY "Authenticated users can upload media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'media' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Anyone can view media'
  ) THEN
    CREATE POLICY "Anyone can view media"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'media');
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can update their own media'
  ) THEN
    CREATE POLICY "Users can update their own media"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
      bucket_id = 'media' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can delete their own media'
  ) THEN
    CREATE POLICY "Users can delete their own media"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'media' AND
      (storage.foldername(name))[1] = auth.uid()::text
    );
  END IF;
END $$;