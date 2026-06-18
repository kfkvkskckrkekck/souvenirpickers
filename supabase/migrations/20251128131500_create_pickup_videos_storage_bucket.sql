/*
  # Create Pickup Videos Storage Bucket

  1. Storage Setup
    - Create `pickup-videos` storage bucket for order pickup videos
    - Set bucket to public for easy viewing by collectors
    - Configure max file size limits

  2. Security (RLS Policies)
    - Authenticated pickers can upload videos
    - Anyone can view videos (collectors need access)
    - Only uploaders can delete their own videos

  3. Notes
    - Videos are automatically verified for content
    - Provides transparency and trust in the picking process
*/

-- Create the pickup-videos storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pickup-videos',
  'pickup-videos',
  true,
  52428800,
  ARRAY['video/mp4', 'video/webm', 'video/quicktime']
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload videos
CREATE POLICY "Authenticated users can upload pickup videos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow public to view pickup videos
CREATE POLICY "Anyone can view pickup videos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'pickup-videos');

-- Allow users to update their own videos
CREATE POLICY "Users can update their own pickup videos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own videos
CREATE POLICY "Users can delete their own pickup videos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'pickup-videos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);