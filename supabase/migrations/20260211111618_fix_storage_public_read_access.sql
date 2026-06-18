/*
  # Fix Storage Public Read Access
  
  1. Problem
    - Videos upload successfully but don't play after upload
    - Storage buckets are marked as public but lack SELECT policies
    - Without SELECT policies, videos cannot be retrieved even from public buckets
    
  2. Solution
    - Add SELECT policies for all public storage buckets
    - Allow anyone to view files in public buckets (listing-videos, media, pickup-videos, etc.)
    - This enables video playback in the browser
    
  3. Security
    - Only applies to buckets already marked as public
    - Upload policies remain restricted to authenticated users
    - Users can only upload to their own folders but everyone can view
*/

-- Drop existing SELECT policies if they exist
DROP POLICY IF EXISTS "Anyone can view listing images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view listing videos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view media files" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view pickup videos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile avatars" ON storage.objects;

-- Create SELECT policies for public access to all public buckets
CREATE POLICY "Anyone can view listing images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'listing-images');

CREATE POLICY "Anyone can view listing videos"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'listing-videos');

CREATE POLICY "Anyone can view media files"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'media');

CREATE POLICY "Anyone can view pickup videos"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'pickup-videos');

CREATE POLICY "Anyone can view profile avatars"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'profile-avatars');

-- Also add UPDATE and DELETE policies for authenticated users to manage their own files
DROP POLICY IF EXISTS "Users can update their own listing images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own listing images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own listing videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own listing videos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own media" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own media" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;

CREATE POLICY "Users can update their own listing images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'listing-images' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete their own listing images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'listing-images' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update their own listing videos"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'listing-videos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete their own listing videos"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'listing-videos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update their own media"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'media' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete their own media"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'media' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update their own avatars"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete their own avatars"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
