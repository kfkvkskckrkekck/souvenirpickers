# Fix Video Streaming Issue

## Problem
The video shows a black screen because it's not optimized for web streaming. MP4 videos need their metadata ("moov atom") at the beginning of the file for progressive download to work in browsers.

## Solution Options

### Option 1: Use Online Tool (Easiest)
1. Go to: https://www.freeconvert.com/video-compressor
2. Upload your video: `public/Souvenir_pickers_Final.mp4`
3. In settings, ensure "Web Optimized" or "Fast Start" is enabled
4. Download the optimized video
5. Replace the file in `public/Souvenir_pickers_Final.mp4`
6. Run the upload script again

### Option 2: Use FFmpeg (Recommended)
If you have FFmpeg installed:

```bash
ffmpeg -i public/Souvenir_pickers_Final.mp4 -c copy -movflags +faststart public/Souvenir_pickers_Final_optimized.mp4
```

Then:
```bash
mv public/Souvenir_pickers_Final_optimized.mp4 public/Souvenir_pickers_Final.mp4
node upload-video-to-supabase.js
```

### Option 3: Use a Different Video
If you have another version of the video that plays correctly in Chrome, use that instead.

## What This Does
The `-movflags +faststart` flag moves the video metadata to the beginning of the file, enabling:
- Progressive download (video starts playing before fully downloaded)
- Better browser compatibility
- Instant playback on the web

## Current Video Analysis
Your current video has this structure:
- ftyp (file type) ✓
- mdat (media data) ← This is at the beginning (causes the issue)
- moov (metadata) ← This is at the end (should be near the beginning)

After optimization, it will be:
- ftyp (file type) ✓
- moov (metadata) ✓ Moved to front
- mdat (media data) ✓

## Alternative: Use a Streaming Service
For professional deployments, consider:
- Upload to Vimeo/YouTube
- Embed their player (they handle optimization automatically)
- Much better performance and global CDN
