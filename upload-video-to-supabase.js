import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables from .env file
const envFile = readFileSync('.env', 'utf-8');
const envVars = {};
envFile.split('\n').forEach(line => {
  const [key, ...valueParts] = line.split('=');
  if (key && !key.startsWith('#')) {
    envVars[key.trim()] = valueParts.join('=').trim();
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseAnonKey = envVars.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function uploadVideo() {
  try {
    console.log('📹 Reading video file...');
    const videoPath = './public/Souvenir_pickers_Final.mp4';
    const videoBuffer = readFileSync(videoPath);
    const fileSizeMB = (videoBuffer.length / (1024 * 1024)).toFixed(2);

    console.log(`✓ Video loaded: ${fileSizeMB} MB`);
    console.log('☁️  Uploading to Supabase Storage...');

    const fileName = 'platform-demo-video.mp4';

    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('media')
      .upload(fileName, videoBuffer, {
        contentType: 'video/mp4',
        cacheControl: '3600',
        upsert: true
      });

    if (error) {
      console.error('❌ Upload failed:', error.message);
      process.exit(1);
    }

    console.log('✅ Upload successful!');

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('media')
      .getPublicUrl(fileName);

    console.log('\n📍 Public URL:');
    console.log(publicUrl);
    console.log('\n✓ Video uploaded successfully!');
    console.log('✓ Clear your browser cache and refresh to see the video.');
    console.log('\n💡 TIP: Press Ctrl+Shift+R (or Cmd+Shift+R on Mac) to hard refresh.');

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

uploadVideo();
