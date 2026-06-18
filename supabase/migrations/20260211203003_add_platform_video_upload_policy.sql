/*
  # Allow Platform Video Uploads to Media Bucket

  1. Changes
    - Add storage policy to allow anonymous uploads for platform-demo-video.mp4
    - This enables uploading the demo video without authentication

  2. Security
    - Policy is restricted to a single specific filename
    - Only allows INSERT and UPDATE operations
    - Applies to the media bucket only
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow platform video upload" ON storage.objects;
DROP POLICY IF EXISTS "Allow platform video update" ON storage.objects;

-- Allow anonymous users to upload the platform demo video
CREATE POLICY "Allow platform video upload"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (
  bucket_id = 'media' 
  AND name = 'platform-demo-video.mp4'
);

-- Allow anonymous users to update the platform demo video
CREATE POLICY "Allow platform video update"
ON storage.objects
FOR UPDATE
TO public
USING (
  bucket_id = 'media' 
  AND name = 'platform-demo-video.mp4'
)
WITH CHECK (
  bucket_id = 'media' 
  AND name = 'platform-demo-video.mp4'
);
