# Video Format Compatibility Guide

## The Problem

Your video plays in **VLC Media Player** but not in web browsers. This is because:

- **VLC** supports almost every video codec (hundreds of formats)
- **Web Browsers** only support a few specific codecs

## Web-Compatible Video Formats

### ✅ RECOMMENDED: MP4 with H.264
- **Video Codec:** H.264 (AVC)
- **Audio Codec:** AAC
- **Container:** MP4
- **Compatibility:** Works in all modern browsers (Chrome, Firefox, Safari, Edge)

### ✅ ALTERNATIVE: WebM
- **Video Codec:** VP8 or VP9
- **Audio Codec:** Vorbis or Opus
- **Container:** WebM
- **Compatibility:** Most modern browsers (not optimal on Safari/iOS)

### ⚠️ NOT RECOMMENDED: MOV
- **Container:** QuickTime MOV
- **Problem:** May use Apple-specific codecs that don't work in all browsers
- **Note:** Can work if encoded with H.264, but MP4 is more reliable

## How to Convert Your Videos

### Option 1: Online Converter (Easiest)
1. Go to **CloudConvert** (https://cloudconvert.com/mp4-converter)
2. Upload your video
3. Select "MP4" as output format
4. Click "Convert"
5. Download the converted file

### Option 2: VLC Media Player (Free Desktop App)
1. Open VLC Media Player
2. Go to **Media → Convert/Save**
3. Add your video file
4. Click **Convert/Save** button
5. Select Profile: **Video - H.264 + MP3 (MP4)**
6. Choose destination and filename
7. Click **Start**

### Option 3: HandBrake (Free, Best Quality)
1. Download **HandBrake** (https://handbrake.fr/)
2. Open your video file
3. Select Preset: **Web → Gmail Large 3 Minutes 720p30**
4. Click **Start Encode**

### Option 4: FFmpeg (Command Line)
```bash
# Convert to web-compatible MP4
ffmpeg -i input.mov -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k output.mp4

# Alternative with smaller file size
ffmpeg -i input.mov -c:v libx264 -preset slow -crf 28 -c:a aac -b:a 96k output.mp4
```

## Recommended Settings for Best Results

### For Portfolio/Listing Videos:
- **Resolution:** 1280x720 (720p) or 1920x1080 (1080p)
- **Frame Rate:** 30 fps
- **Bitrate:** 2-5 Mbps
- **Max File Size:** 50 MB (enforced by app)

### For Quick/Short Videos:
- **Resolution:** 640x480 or 854x480
- **Frame Rate:** 24-30 fps
- **Bitrate:** 1-2 Mbps
- **Max File Size:** 20 MB recommended

## Quick Check: Is My Video Web-Compatible?

### Good Signs ✅
- File extension: `.mp4`
- Plays automatically in Chrome browser when opened
- Shows video info in browser console without errors
- File properties show "H.264" or "AVC" codec

### Bad Signs ❌
- File extension: `.mov`, `.avi`, `.wmv`, `.flv`
- Downloads instead of playing in browser
- Browser shows "format not supported" error
- Requires plugins to play

## Testing Your Converted Video

After converting:
1. Try opening the video file directly in Chrome or Firefox
2. If it plays with controls, it will work in the app
3. If it doesn't play, try converting again with different settings

## Still Having Issues?

If your converted video still doesn't play:

1. **Check the codec:** Right-click video → Properties → Details
   - Should say: `Video: H.264` and `Audio: AAC`

2. **Try a different converter:** Each tool uses slightly different encoding settings

3. **Reduce file size:** Sometimes very high bitrate videos cause issues
   - Lower resolution to 720p
   - Use a higher CRF value (lower quality = smaller size)

4. **Use the test page:** Upload to `/test-video-upload-and-playback.html` to debug

## Why This Matters

Web browsers enforce strict security and compatibility rules:
- They only support codecs with open-source or licensed implementations
- Video codecs must be hardware-accelerated for mobile devices
- Format must work across Windows, Mac, Linux, iOS, and Android

VLC doesn't have these restrictions, so it can play anything!
