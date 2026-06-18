# Live Streaming Quick Start Checklist

Use this checklist to get live streaming up and running quickly.

## Prerequisites
- [ ] Node.js and npm installed
- [ ] Supabase project set up
- [ ] LiveSouvenir app running

## Step 1: Choose Your Provider (5 minutes)

### Fastest: Daily.co (Recommended for testing)
- [ ] Sign up at https://dashboard.daily.co/signup
- [ ] Copy API key from dashboard
- [ ] Estimated setup time: 1 hour

### Best for Production: Agora
- [ ] Sign up at https://console.agora.io/
- [ ] Create new project
- [ ] Copy App ID and enable App Certificate
- [ ] Estimated setup time: 2 hours

### Enterprise: Twilio Video
- [ ] Sign up at https://www.twilio.com/try-twilio
- [ ] Get Account SID and API credentials
- [ ] Estimated setup time: 3 hours

## Step 2: Configure Environment (10 minutes)

### Frontend Configuration
- [ ] Copy `.env.streaming.example` to `.env`
- [ ] Add your provider credentials to `.env`
- [ ] Set `VITE_STREAMING_PROVIDER` to your chosen provider

### Backend Configuration (Supabase)
- [ ] Go to Supabase Dashboard > Edge Functions > Environment Variables
- [ ] Add provider-specific secrets (see below)

**For Agora:**
```
AGORA_APP_ID=your_app_id
AGORA_APP_CERTIFICATE=your_certificate
```

**For Daily.co:**
```
DAILY_API_KEY=your_api_key
```

**For Twilio:**
```
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_API_KEY=your_api_key
TWILIO_API_SECRET=your_api_secret
```

## Step 3: Install Dependencies (5 minutes)

Choose based on your provider:

**For Agora:**
```bash
npm install agora-rtc-sdk-ng
```

**For Daily.co:**
```bash
npm install @daily-co/daily-js
```

**For Twilio:**
```bash
npm install twilio-video
```

## Step 4: Deploy Edge Function (15 minutes)

### For Agora
- [ ] Review code in `LIVE_STREAMING_INTEGRATION.md` (search for "generate-agora-token")
- [ ] Create the Edge Function file
- [ ] Deploy using Supabase CLI or dashboard
- [ ] Test the function returns tokens

### For Daily.co
- [ ] Review code in `LIVE_STREAMING_INTEGRATION.md` (search for "create-daily-room")
- [ ] Create the Edge Function file
- [ ] Deploy using Supabase CLI or dashboard
- [ ] Test the function creates rooms

### For Twilio
- [ ] Review Twilio documentation for token generation
- [ ] Create custom Edge Function
- [ ] Deploy and test

## Step 5: Update LiveStreamingView (30 minutes)

- [ ] Copy streaming service code from `LIVE_STREAMING_INTEGRATION.md`
- [ ] Add imports for your chosen provider
- [ ] Update `startStream` function with video initialization
- [ ] Update stream viewer with video player
- [ ] Replace placeholder video section

## Step 6: Test Everything (20 minutes)

### Basic Tests
- [ ] Start a stream from picker account
- [ ] Verify video appears for broadcaster
- [ ] Join stream from collector account
- [ ] Verify video appears for viewer
- [ ] Test chat during stream
- [ ] Test item requests during stream
- [ ] End stream and verify it stops

### Advanced Tests
- [ ] Test with multiple viewers (3+)
- [ ] Test on mobile device
- [ ] Test with poor network connection
- [ ] Test stream reconnection
- [ ] Verify viewer count updates
- [ ] Test delete stream functionality

## Step 7: Monitor and Optimize (Ongoing)

- [ ] Set up usage monitoring in provider dashboard
- [ ] Track costs per stream
- [ ] Monitor video quality metrics
- [ ] Collect user feedback
- [ ] Optimize video quality settings based on usage

## Troubleshooting Common Issues

### "Token generation failed"
- ✓ Check Edge Function environment variables
- ✓ Verify API credentials are correct
- ✓ Check Edge Function logs in Supabase

### "Video not showing"
- ✓ Check browser permissions for camera/microphone
- ✓ Verify WebRTC is supported in browser
- ✓ Check browser console for errors
- ✓ Test on different device/browser

### "Stream disconnects frequently"
- ✓ Check internet connection stability
- ✓ Lower video quality settings
- ✓ Check provider service status
- ✓ Review bandwidth usage

### "High costs"
- ✓ Monitor stream durations
- ✓ Set maximum stream time limits
- ✓ Lower video quality for mobile users
- ✓ Consider switching providers

## Cost Estimates (per month)

### Light Usage (10 hours/month)
- Daily.co: $1.20
- Agora: $0.60
- Twilio: $0.90

### Medium Usage (100 hours/month)
- Daily.co: $12.00
- Agora: $5.94
- Twilio: $9.00

### Heavy Usage (500 hours/month)
- Daily.co: $60.00
- Agora: $29.70
- Twilio: $45.00

## Success Criteria

Your live streaming is production-ready when:
- [ ] Streams start reliably within 5 seconds
- [ ] Video quality is good on stable connections
- [ ] Chat and item requests work during streams
- [ ] Multiple viewers can watch simultaneously
- [ ] Streams gracefully handle disconnections
- [ ] Costs are within budget
- [ ] User feedback is positive

## Getting Help

1. Check `LIVE_STREAMING_INTEGRATION.md` for detailed integration guides
2. Review `src/lib/streamingUtils.ts` for helper functions
3. Check provider documentation:
   - Agora: https://docs.agora.io/
   - Daily.co: https://docs.daily.co/
   - Twilio: https://www.twilio.com/docs/video

## Next Steps After Integration

1. Add stream analytics and metrics
2. Implement stream recording (optional)
3. Add stream thumbnails/preview images
4. Enable stream scheduling
5. Add viewer reactions/emojis
6. Implement co-hosting features
7. Add stream highlights/clips

---

**Estimated Total Setup Time:**
- Daily.co: 1-2 hours
- Agora: 2-3 hours
- Twilio: 3-4 hours

Good luck with your integration!
