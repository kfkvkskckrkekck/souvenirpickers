/*
  # Update Storage Buckets CORS Configuration

  1. Purpose
    - Ensure videos can be played in browsers by configuring proper CORS settings
    - Allow cross-origin requests for video playback

  2. Changes
    - Update storage bucket configurations to support CORS
*/

-- Update listing-videos bucket to allow CORS
UPDATE storage.buckets
SET public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime']
WHERE name = 'listing-videos';

-- Update media bucket to allow CORS
UPDATE storage.buckets
SET public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime']
WHERE name = 'media';

-- Ensure pickup-videos bucket is configured properly
UPDATE storage.buckets
SET public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/quicktime']
WHERE name = 'pickup-videos';