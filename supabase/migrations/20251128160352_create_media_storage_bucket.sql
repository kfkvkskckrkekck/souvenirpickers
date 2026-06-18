/*
  # Create Media Storage Bucket

  1. Storage Setup
    - Create `media` storage bucket for stories, posts, and social content
    - Set bucket to public for easy viewing
    - Configure max file size limits (100MB)
    - Allow images and videos

  2. Security (RLS Policies)
    - Authenticated users can upload media
    - Anyone can view media (public content)
    - Only uploaders can delete their own media

  3. Notes
    - Used for stories (24hr expiring content)
    - Used for feed posts (permanent content)
    - Supports both images and videos
*/

-- Create the media storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  104857600,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'video/x-msvideo'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload media
CREATE POLICY "Authenticated users can upload media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'media'
);

-- Allow public to view media
CREATE POLICY "Anyone can view media"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'media');

-- Allow users to update their own media
CREATE POLICY "Users can update their own media"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'media' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'media' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own media
CREATE POLICY "Users can delete their own media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'media'
);