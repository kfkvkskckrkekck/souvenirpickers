# Video Streaming Integration Flow

Visual guide showing exactly how video streaming integrates with LiveSouvenir.

## 📋 Documentation Files Created

```
project/
├── STREAMING_README.md                    ← START HERE
├── STREAMING_QUICKSTART.md                ← Step-by-step checklist
├── LIVE_STREAMING_INTEGRATION.md          ← Detailed code examples
├── STREAMING_PROVIDER_COMPARISON.md       ← Provider comparison
├── .env.streaming.example                 ← Environment template
└── src/
    └── lib/
        └── streamingUtils.ts              ← Helper utilities
```

## 🔄 Integration Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. PICKER STARTS STREAM                                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ LiveStreamingView Component              │
    │ - User clicks "Go Live" button          │
    │ - Enters stream title/description        │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Create Stream in Database                │
    │ INSERT INTO live_streams                 │
    │ - picker_id, title, description          │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Request Token from Edge Function         │
    │ POST /functions/v1/generate-token        │
    │ - streamId, role: "host"                │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Edge Function Generates Token            │
    │ - Uses Agora/Daily/Twilio API           │
    │ - Returns secure token (24hr expiry)    │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Initialize Video Provider SDK            │
    │ - Join channel with token               │
    │ - Start camera/microphone               │
    │ - Publish video/audio tracks            │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Display Video in Browser                 │
    │ - Render video track to DOM element     │
    │ - Show chat and item requests           │
    └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 2. COLLECTOR WATCHES STREAM                                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Collector Clicks on Stream Card          │
    │ - Views stream thumbnail                 │
    │ - Sees live indicator and viewer count   │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Request Token as Viewer                  │
    │ POST /functions/v1/generate-token        │
    │ - streamId, role: "audience"            │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Join Stream as Viewer                    │
    │ - Subscribe to picker's video/audio     │
    │ - Update viewer count in database       │
    └─────────────────────────────────────────┘
                          │
                          ▼
    ┌─────────────────────────────────────────┐
    │ Display Picker's Video + Chat            │
    │ - Render remote video track             │
    │ - Enable chat and item requests         │
    └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 3. REAL-TIME INTERACTIONS                                   │
└─────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
   ┌────────┐      ┌──────────┐     ┌──────────┐
   │  Chat  │      │  Item    │     │  Viewer  │
   │Messages│      │Requests  │     │ Tracking │
   └────────┘      └──────────┘     └──────────┘
        │                 │                 │
        ▼                 ▼                 ▼
   Real-time        Database           Database
   Supabase         INSERT             UPDATE
   Channel          notifications      counts
```

## 🔑 Key Integration Points

### 1. Frontend (React Component)
**File:** `src/components/LiveStreamingView.tsx`

**Current State:**
```typescript
// ✅ Already implemented
- Stream list display
- Chat functionality
- Item requests
- Viewer tracking
- Stream management (create/end/delete)

// ⏳ Needs integration
- Video provider SDK initialization
- Camera/microphone access
- Video track rendering
```

### 2. Backend (Edge Functions)
**File:** `supabase/functions/generate-agora-token/index.ts` (or similar)

**Needs to be created:**
```typescript
// Generate secure tokens for streaming
- Validate user permissions
- Generate time-limited tokens
- Return to frontend securely
```

### 3. Database (Supabase)
**Status:** ✅ Already complete

**Tables:**
- `live_streams` - Stream metadata
- `stream_viewers` - Viewer tracking
- `stream_chat_messages` - Chat messages
- `stream_item_requests` - Item requests

### 4. Configuration (Environment)
**File:** `.env`

**Needs to be added:**
```bash
# Frontend (in .env)
VITE_STREAMING_PROVIDER=agora
VITE_AGORA_APP_ID=your_app_id

# Backend (in Supabase Dashboard)
AGORA_APP_CERTIFICATE=your_certificate
```

## 🎬 What Happens When You Click "Go Live"

### Current Implementation (Working):
1. ✅ Modal opens for stream title/description
2. ✅ Stream record created in database
3. ✅ Stream appears in list with "LIVE" badge
4. ✅ Chat becomes available
5. ✅ Item requests become available
6. ⚠️ **Video shows placeholder message**

### After Integration (Complete):
1. ✅ Everything above, PLUS...
2. ✅ Browser requests camera/mic permission
3. ✅ Video provider SDK initializes
4. ✅ Live video appears for broadcaster
5. ✅ Viewers can watch live video
6. ✅ Automatic quality adjustment
7. ✅ Network resilience

## 📊 Data Flow

```
Picker Device                 Supabase               Viewer Device
     │                           │                        │
     │ 1. Create stream          │                        │
     ├──────────────────────────>│                        │
     │                           │                        │
     │ 2. Get token              │                        │
     ├──────────────────────────>│                        │
     │<──────────────────────────┤                        │
     │                           │                        │
     │ 3. Start video ──────────────────> Video Provider  │
     │                           │              │         │
     │                           │              │         │
     │                           │    4. Viewer joins     │
     │                           │<───────────────────────┤
     │                           │                        │
     │                           │    5. Get token        │
     │                           ├───────────────────────>│
     │                           │<───────────────────────┤
     │                           │                        │
     │ <───────────────────── Video Stream ──────────────>│
     │                           │                        │
     │ 6. Send chat ────────────>│                        │
     │                           ├───────────────────────>│
     │                           │                        │
     │                           │<─── 7. Request item ───┤
     ├<──────────────────────────┤                        │
```

## 🛠️ Integration Checklist

### Before You Start
- [ ] Read `STREAMING_README.md`
- [ ] Choose provider (Agora/Daily/Twilio)
- [ ] Sign up for provider account
- [ ] Get API credentials

### Step 1: Environment Setup (10 min)
- [ ] Copy `.env.streaming.example` to `.env`
- [ ] Add provider credentials to `.env`
- [ ] Add secrets to Supabase Edge Functions

### Step 2: Install Dependencies (5 min)
- [ ] Run `npm install agora-rtc-sdk-ng` (or chosen provider)
- [ ] Verify installation

### Step 3: Create Edge Function (15 min)
- [ ] Create token generation function
- [ ] Deploy to Supabase
- [ ] Test function returns tokens

### Step 4: Update Frontend (30 min)
- [ ] Import provider SDK
- [ ] Add token request logic
- [ ] Add video initialization
- [ ] Replace placeholder with video element
- [ ] Test locally

### Step 5: Test Everything (20 min)
- [ ] Start stream from picker account
- [ ] Watch stream from collector account
- [ ] Test chat during stream
- [ ] Test item requests
- [ ] Test on mobile device

### Step 6: Deploy (10 min)
- [ ] Build production bundle
- [ ] Deploy to hosting
- [ ] Test in production
- [ ] Monitor costs and usage

## 💡 Tips for Success

1. **Start with Daily.co** if you want the fastest integration
2. **Use Agora** if you want the best value for production
3. **Test locally first** before deploying
4. **Monitor costs** from day one
5. **Add error handling** for network issues
6. **Test on real mobile devices** early

## 🚫 Common Mistakes to Avoid

❌ Exposing API secrets in frontend code
✅ Use Edge Functions for token generation

❌ Not handling camera/mic permissions
✅ Check permissions before streaming

❌ Hardcoding provider in component
✅ Use environment variables

❌ Not testing on mobile
✅ Test on iOS and Android early

❌ Forgetting about costs
✅ Monitor usage from day one

## 📈 Success Metrics

After integration, you should see:
- ✅ Streams start in < 5 seconds
- ✅ Video quality is smooth on stable connection
- ✅ Chat messages appear instantly
- ✅ Viewer count updates in real-time
- ✅ Works on mobile devices
- ✅ Costs are predictable

## 🎯 Next Steps

1. Open `STREAMING_QUICKSTART.md`
2. Follow the checklist
3. Start with Daily.co for fastest results
4. Switch to Agora for production if needed

You've got this! 🚀
