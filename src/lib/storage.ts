import { supabase } from './supabase';

export type UploadResult = {
  url: string;
  path: string;
};

const MAX_IMAGE_SIZE = 5 * 1024 * 1024;
const MAX_VIDEO_SIZE = 50 * 1024 * 1024;

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/webm', 'video/quicktime'];

export async function uploadImage(file: File, userId: string): Promise<UploadResult> {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new Error('Invalid file type. Allowed: JPG, PNG, WebP');
  }

  if (file.size > MAX_IMAGE_SIZE) {
    throw new Error('Image size must be less than 5MB');
  }

  const fileExt = file.name.split('.').pop();
  const fileName = `${userId}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;

  const { data, error } = await supabase.storage
    .from('listing-images')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
    });

  if (error) throw error;

  const { data: urlData } = supabase.storage
    .from('listing-images')
    .getPublicUrl(data.path);

  return {
    url: urlData.publicUrl,
    path: data.path,
  };
}

export async function uploadVideo(file: File, userId: string): Promise<UploadResult> {
  if (!ALLOWED_VIDEO_TYPES.includes(file.type)) {
    throw new Error('Invalid file type. Please use MP4 (H.264) or WebM format. MOV files may not be compatible with all browsers.');
  }

  if (file.size > MAX_VIDEO_SIZE) {
    throw new Error('Video size must be less than 50MB');
  }

  if (file.type === 'video/quicktime') {
    console.warn('MOV format detected - may not play in all browsers. MP4 with H.264 codec recommended.');
  }

  const fileExt = file.name.split('.').pop()?.toLowerCase();
  const fileName = `${userId}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;

  let contentType = file.type;
  if (fileExt === 'mp4' && !contentType) {
    contentType = 'video/mp4';
  } else if (fileExt === 'webm' && !contentType) {
    contentType = 'video/webm';
  }

  const { data, error } = await supabase.storage
    .from('listing-videos')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: contentType,
    });

  if (error) throw error;

  const { data: urlData } = supabase.storage
    .from('listing-videos')
    .getPublicUrl(data.path);

  return {
    url: urlData.publicUrl,
    path: data.path,
  };
}

export async function uploadAvatar(file: File, userId: string): Promise<UploadResult> {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new Error('Invalid file type. Allowed: JPG, PNG, WebP');
  }

  if (file.size > MAX_IMAGE_SIZE) {
    throw new Error('Image size must be less than 5MB');
  }

  const fileExt = file.name.split('.').pop();
  const fileName = `${userId}/avatar.${fileExt}`;

  const { data, error } = await supabase.storage
    .from('profile-avatars')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: true,
    });

  if (error) throw error;

  const { data: urlData } = supabase.storage
    .from('profile-avatars')
    .getPublicUrl(data.path);

  return {
    url: urlData.publicUrl,
    path: data.path,
  };
}

export async function uploadPickupVideo(file: File, userId: string, orderId: string): Promise<UploadResult> {
  if (!ALLOWED_VIDEO_TYPES.includes(file.type)) {
    const error = new Error(`Invalid file type: ${file.type}. Allowed types: ${ALLOWED_VIDEO_TYPES.join(', ')}`);
    throw error;
  }

  if (file.size > MAX_VIDEO_SIZE) {
    const error = new Error(`Video size ${(file.size / 1024 / 1024).toFixed(2)}MB exceeds limit of 50MB`);
    throw error;
  }

  if (file.size === 0) {
    const error = new Error('File is empty (0 bytes)');
    throw error;
  }

  const fileExt = file.name.split('.').pop();
  const fileName = `${userId}/pickup-${orderId}-${Date.now()}.${fileExt}`;

  const { data, error } = await supabase.storage
    .from('pickup-videos')
    .upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type,
    });

  if (error) {
    if (error.message.includes('duplicate') || error.message.includes('already exists')) {
      throw new Error('A video with this name already exists. Please try again.');
    } else if (error.message.includes('size')) {
      throw new Error(`Video file is too large: ${(file.size / 1024 / 1024).toFixed(2)}MB`);
    } else if (error.message.includes('type') || error.message.includes('mime')) {
      throw new Error(`Invalid video format: ${file.type}`);
    } else if (error.message.includes('policy') || error.message.includes('permission')) {
      throw new Error('Permission denied. Please ensure you are logged in.');
    }

    throw new Error(`Storage error: ${error.message}`);
  }

  if (!data || !data.path) {
    throw new Error('Upload returned no data');
  }

  const { data: urlData } = supabase.storage
    .from('pickup-videos')
    .getPublicUrl(data.path);

  if (!urlData || !urlData.publicUrl) {
    throw new Error('Failed to get public URL for uploaded video');
  }

  // Test if URL is accessible
  try {
    const testResponse = await fetch(urlData.publicUrl, { method: 'HEAD' });
  } catch (testError) {
  }

  return {
    url: urlData.publicUrl,
    path: data.path,
  };
}

export async function deleteFile(bucket: string, path: string): Promise<void> {
  const { error } = await supabase.storage.from(bucket).remove([path]);
  if (error) throw error;
}

async function triggerMediaVerification(
  mediaUrl: string,
  mediaType: 'image' | 'video',
  storageBucket: string,
  storagePath: string,
  uploaderId: string
): Promise<string | undefined> {
  try {
    const response = await fetch(
      `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/verify-media`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          mediaUrl,
          mediaType,
          storageBucket,
          storagePath,
          uploaderId,
        }),
      }
    );

    if (!response.ok) {
      return undefined;
    }

    const result = await response.json();
    return result.verificationId;
  } catch (error) {
    return undefined;
  }
}
