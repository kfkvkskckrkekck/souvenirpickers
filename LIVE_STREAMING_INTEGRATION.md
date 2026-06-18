# Live Streaming Integration Guide

This guide explains how to integrate video streaming services with the LiveSouvenir platform.

## Current Implementation

The platform currently has the complete infrastructure for live streaming:
- ✅ Database tables (live_streams, stream_viewers, stream_chat_messages, stream_item_requests)
- ✅ Real-time chat functionality
- ✅ Item request system
- ✅ Viewer tracking and analytics
- ✅ Stream management (create, end, delete)
- ⏳ **Video streaming requires external service integration**

## Recommended Streaming Services

### 1. **Agora (Recommended)**
- **Best for:** Real-time video streaming with low latency
- **Pricing:** Free tier: 10,000 minutes/month
- **Pros:** Easy to use, excellent documentation, great for interactive streaming
- **Setup time:** ~2 hours

### 2. **Twilio Video**
- **Best for:** Enterprise-grade reliability
- **Pricing:** Pay-as-you-go, starts at $0.0015/min
- **Pros:** Robust, scalable, great support
- **Setup time:** ~3 hours

### 3. **Daily.co**
- **Best for:** Quick implementation
- **Pricing:** Free tier: 10 rooms, 20 participants
- **Pros:** Simplest integration, pre-built UI components
- **Setup time:** ~1 hour

### 4. **Mux**
- **Best for:** Professional broadcasting
- **Pricing:** $0.005/minute watched
- **Pros:** High quality, built for streaming, great analytics
- **Setup time:** ~4 hours

### 5. **WebRTC (DIY)**
- **Best for:** Full control, no external costs
- **Pricing:** Free (infrastructure costs apply)
- **Pros:** Complete control, no per-minute fees
- **Setup time:** ~2 weeks
- **Note:** Requires significant development effort

## Integration Steps

### Option A: Agora Integration (Recommended)

#### Step 1: Sign Up and Get Credentials
1. Go to [Agora Console](https://console.agora.io/)
2. Create a new project
3. Get your App ID and App Certificate
4. Add to `.env`:
```env
VITE_AGORA_APP_ID=your_app_id_here
```

#### Step 2: Install Agora SDK
```bash
npm install agora-rtc-sdk-ng
```

#### Step 3: Create Agora Service (src/lib/agoraService.ts)
```typescript
import AgoraRTC, {
  IAgoraRTCClient,
  ICameraVideoTrack,
  IMicrophoneAudioTrack,
} from 'agora-rtc-sdk-ng';

const APP_ID = import.meta.env.VITE_AGORA_APP_ID;

export class AgoraService {
  private client: IAgoraRTCClient | null = null;
  private localVideoTrack: ICameraVideoTrack | null = null;
  private localAudioTrack: IMicrophoneAudioTrack | null = null;

  async initialize() {
    this.client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
  }

  async startStreaming(streamId: string, token: string) {
    if (!this.client) await this.initialize();

    // Set user role as host (broadcaster)
    await this.client?.setClientRole('host');

    // Join channel
    await this.client?.join(APP_ID, streamId, token);

    // Create local tracks
    this.localAudioTrack = await AgoraRTC.createMicrophoneAudioTrack();
    this.localVideoTrack = await AgoraRTC.createCameraVideoTrack();

    // Publish tracks
    await this.client?.publish([this.localAudioTrack, this.localVideoTrack]);

    return this.localVideoTrack;
  }

  async watchStream(streamId: string, token: string, onRemoteUser: Function) {
    if (!this.client) await this.initialize();

    // Set user role as audience
    await this.client?.setClientRole('audience');

    // Join channel
    await this.client?.join(APP_ID, streamId, token);

    // Listen for remote users
    this.client?.on('user-published', async (user, mediaType) => {
      await this.client?.subscribe(user, mediaType);
      if (mediaType === 'video') {
        onRemoteUser(user.videoTrack);
      }
    });
  }

  async stopStreaming() {
    this.localAudioTrack?.close();
    this.localVideoTrack?.close();
    await this.client?.leave();
  }

  getVideoTrack() {
    return this.localVideoTrack;
  }
}
```

#### Step 4: Create Token Generation Edge Function

Create `supabase/functions/generate-agora-token/index.ts`:
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token@2.0.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { streamId, role } = await req.json();

    const appId = Deno.env.get('AGORA_APP_ID');
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE');

    if (!appId || !appCertificate) {
      throw new Error('Agora credentials not configured');
    }

    // Token expires in 24 hours
    const expirationTime = Math.floor(Date.now() / 1000) + 86400;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      streamId,
      0, // uid (0 for dynamic assignment)
      role === 'host' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER,
      expirationTime
    );

    return new Response(
      JSON.stringify({ token }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

Deploy the function:
```bash
# Add Agora credentials to Supabase
# Go to Project Settings > Edge Functions > Environment Variables
# Add: AGORA_APP_ID and AGORA_APP_CERTIFICATE
```

#### Step 5: Update LiveStreamingView Component

Add this to the component:
```typescript
import { AgoraService } from '../lib/agoraService';

// In component
const agoraService = useRef(new AgoraService());
const videoContainerRef = useRef<HTMLDivElement>(null);

const startStreamWithVideo = async () => {
  // First create stream in database
  const { data: stream } = await supabase
    .from('live_streams')
    .insert({ picker_id: user!.id, title: streamTitle, description: streamDescription })
    .select()
    .single();

  if (stream) {
    // Get Agora token
    const response = await fetch(
      `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/generate-agora-token`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ streamId: stream.id, role: 'host' }),
      }
    );
    const { token } = await response.json();

    // Start Agora stream
    const videoTrack = await agoraService.current.startStreaming(stream.id, token);

    // Display local video
    if (videoContainerRef.current) {
      videoTrack.play(videoContainerRef.current);
    }

    setSelectedStream(stream);
  }
};

const watchStreamWithVideo = async (stream: LiveStream) => {
  // Get Agora token
  const response = await fetch(
    `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/generate-agora-token`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ streamId: stream.id, role: 'audience' }),
    }
  );
  const { token } = await response.json();

  // Watch stream
  await agoraService.current.watchStream(stream.id, token, (videoTrack: any) => {
    if (videoContainerRef.current) {
      videoTrack.play(videoContainerRef.current);
    }
  });

  setSelectedStream(stream);
};

// Replace the placeholder video section with:
<div ref={videoContainerRef} className="flex-1 bg-gray-900" />
```

---

### Option B: Daily.co Integration (Fastest)

#### Step 1: Sign Up
1. Go to [Daily.co](https://dashboard.daily.co/signup)
2. Get your API key
3. Add to `.env`:
```env
VITE_DAILY_API_KEY=your_api_key_here
```

#### Step 2: Install Daily SDK
```bash
npm install @daily-co/daily-js
```

#### Step 3: Create Edge Function for Room Creation

Create `supabase/functions/create-daily-room/index.ts`:
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { streamId } = await req.json();
    const apiKey = Deno.env.get('DAILY_API_KEY');

    const response = await fetch('https://api.daily.co/v1/rooms', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        name: streamId,
        privacy: 'public',
        properties: {
          enable_screenshare: false,
          enable_chat: false,
          start_video_off: false,
          start_audio_off: false,
        },
      }),
    });

    const room = await response.json();

    return new Response(
      JSON.stringify({ roomUrl: room.url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

#### Step 4: Update Component
```typescript
import DailyIframe from '@daily-co/daily-js';

const dailyRef = useRef<any>(null);

const startStreamWithDaily = async () => {
  // Create room
  const response = await fetch(
    `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-daily-room`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ streamId: Date.now().toString() }),
    }
  );
  const { roomUrl } = await response.json();

  // Create stream in database with room URL
  const { data: stream } = await supabase
    .from('live_streams')
    .insert({
      picker_id: user!.id,
      title: streamTitle,
      description: streamDescription,
      stream_url: roomUrl,
    })
    .select()
    .single();

  if (stream && videoContainerRef.current) {
    dailyRef.current = DailyIframe.createFrame(videoContainerRef.current, {
      showLeaveButton: false,
      iframeStyle: {
        width: '100%',
        height: '100%',
        border: 0,
      },
    });

    await dailyRef.current.join({ url: roomUrl });
    setSelectedStream(stream);
  }
};
```

---

## Cost Comparison

| Service | Free Tier | Pay-as-you-go | Best For |
|---------|-----------|---------------|----------|
| **Agora** | 10K min/mo | $0.99/1K min | Interactive live streams |
| **Daily.co** | 10 rooms | $0.002/min | Quick MVP |
| **Twilio** | Trial credits | $0.0015/min | Enterprise |
| **Mux** | None | $0.005/min watched | Broadcasting |

## Quick Start Recommendation

**For MVP/Testing:** Use Daily.co
- Fastest integration (1-2 hours)
- Free tier is generous
- Pre-built UI components

**For Production:** Use Agora
- Better performance
- More control over UI/UX
- Lower long-term costs
- Better scalability

## Security Considerations

1. **Never expose API keys in frontend code** - Always use Edge Functions
2. **Implement token expiration** - Tokens should expire after 24 hours
3. **Validate user permissions** - Only allow stream creators to broadcast
4. **Rate limiting** - Prevent abuse of token generation endpoints

## Testing

After integration, test:
- [ ] Stream creation from mobile and desktop
- [ ] Multiple viewers watching simultaneously
- [ ] Network quality indicators
- [ ] Graceful disconnection handling
- [ ] Chat continues working during stream
- [ ] Item requests work during stream

## Support

For integration support:
- Agora: https://docs.agora.io/
- Daily: https://docs.daily.co/
- Twilio: https://www.twilio.com/docs/video

## Next Steps

1. Choose a streaming service based on your needs
2. Set up credentials and environment variables
3. Deploy the token generation Edge Function
4. Update LiveStreamingView component with video integration
5. Test thoroughly with multiple users
6. Monitor usage and costs
