/*
  # Fix Storage Upload Policies

  1. Problem
    - INSERT policies for storage buckets don't have WITH CHECK conditions
    - This can cause upload failures because the policy can't validate bucket access

  2. Solution
    - Add proper WITH CHECK conditions to ensure uploads go to the correct buckets
    - Ensure authenticated users can upload files to their own folders
*/

-- Drop existing INSERT policies
DROP POLICY IF EXISTS "Authenticated users can upload listing images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload listing videos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload pickup videos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile avatars" ON storage.objects;

-- Create new INSERT policies with proper WITH CHECK conditions
CREATE POLICY "Authenticated users can upload listing images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'listing-images');

CREATE POLICY "Authenticated users can upload listing videos"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'listing-videos');

CREATE POLICY "Authenticated users can upload media"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'media');

CREATE POLICY "Authenticated users can upload pickup videos"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'pickup-videos');

CREATE POLICY "Authenticated users can upload profile avatars"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'profile-avatars');