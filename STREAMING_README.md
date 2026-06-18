# LiveSouvenir Video Streaming Documentation

Complete guide to integrating live video streaming into the LiveSouvenir platform.

## 📚 Documentation Overview

This folder contains everything you need to add live video streaming:

1. **[STREAMING_QUICKSTART.md](./STREAMING_QUICKSTART.md)** - Start here! Step-by-step checklist
2. **[LIVE_STREAMING_INTEGRATION.md](./LIVE_STREAMING_INTEGRATION.md)** - Detailed integration guide with code
3. **[STREAMING_PROVIDER_COMPARISON.md](./STREAMING_PROVIDER_COMPARISON.md)** - Compare providers and costs
4. **[.env.streaming.example](./.env.streaming.example)** - Environment variable template

## 🚀 Quick Start (5 minutes)

1. **Choose a provider:**
   - Daily.co (fastest, easiest)
   - Agora (best value, production-ready)
   - Twilio (enterprise features)

2. **Get credentials:**
   - Sign up for your chosen provider
   - Copy API keys

3. **Configure environment:**
   ```bash
   cp .env.streaming.example .env
   # Add your credentials to .env
   ```

4. **Follow the guide:**
   - Open `STREAMING_QUICKSTART.md`
   - Follow the checklist
   - You'll be streaming in 1-3 hours!

## 🎯 What You Get

The platform already has:
- ✅ Stream management (create, end, delete)
- ✅ Real-time chat during streams
- ✅ Item request system
- ✅ Viewer tracking and analytics
- ✅ Complete database schema
- ✅ RLS security policies
- ✅ Mobile-responsive UI

What you need to add:
- ⏳ Video streaming service integration (1-3 hours)

## 📊 Provider Comparison

| Provider | Setup Time | Free Tier | Cost (100 hrs) | Best For |
|----------|------------|-----------|----------------|----------|
| Daily.co | 1-2 hours | 10 rooms | $12/month | MVP/Testing |
| Agora | 2-3 hours | 10K minutes | $6/month | Production |
| Twilio | 3-4 hours | Trial credits | $9/month | Enterprise |

See [STREAMING_PROVIDER_COMPARISON.md](./STREAMING_PROVIDER_COMPARISON.md) for detailed comparison.

## 💡 Recommended Path

### For MVP (Launch in 1 week)
```
Daily.co → Quick setup → Launch fast → Iterate
```

### For Production (Launch in 2-4 weeks)
```
Agora → Better value → More control → Scale ready
```

### For Enterprise (Launch in 1-2 months)
```
Twilio → Best support → Compliance → Enterprise features
```

## 🛠️ Technical Architecture

```
┌─────────────────┐
│   LiveSouvenir  │
│   React App     │
└────────┬────────┘
         │
         ├─── Video Provider (Agora/Daily/Twilio)
         │    └─── WebRTC Streams
         │
         └─── Supabase
              ├─── Database (live_streams, chat, etc)
              ├─── Realtime (chat, requests)
              └─── Edge Functions (token generation)
```

## 📖 Integration Steps Summary

1. **Choose provider** (5 min)
2. **Sign up and get credentials** (10 min)
3. **Configure environment** (10 min)
4. **Install SDK** (5 min)
5. **Deploy Edge Function** (15 min)
6. **Update UI component** (30 min)
7. **Test everything** (20 min)

**Total time: 1-2 hours**

## 💰 Cost Calculator

Use this formula:
```
Monthly Cost = (Hours streamed per month × 60) × Provider rate

Daily.co:  hours × 60 × $0.002
Agora:     hours × 60 × $0.00099
Twilio:    hours × 60 × $0.0015
```

Example for 100 hours/month:
- Daily.co: 100 × 60 × $0.002 = $12
- Agora: 100 × 60 × $0.00099 = $5.94
- Twilio: 100 × 60 × $0.0015 = $9

## 🔧 Helper Utilities

We've included utilities in `src/lib/streamingUtils.ts`:

- `createStreamingService()` - Initialize any provider
- `checkStreamingCapabilities()` - Check device support
- `requestMediaPermissions()` - Get camera/mic access
- `getRecommendedQuality()` - Optimize for network
- `estimateCost()` - Calculate streaming costs
- `formatStreamDuration()` - Format time display

## 🔐 Security Best Practices

1. **Never expose secrets in frontend**
   - Use Edge Functions for token generation
   - Keep API keys server-side only

2. **Implement token expiration**
   - Set tokens to expire after 24 hours
   - Refresh tokens before expiry

3. **Validate permissions**
   - Only allow pickers to broadcast
   - Check user type before allowing stream creation

4. **Rate limiting**
   - Limit token generation requests
   - Prevent stream spam

## 📱 Mobile Considerations

All providers support mobile, but consider:
- Start with 720p quality for mobile
- Use adaptive bitrate streaming
- Test on 3G/4G networks
- Handle interruptions (calls, notifications)
- Optimize battery usage

## 🐛 Troubleshooting

### Common Issues:

**"Can't see video"**
```bash
# Check browser permissions
# Verify WebRTC support
# Check console for errors
```

**"Token generation failed"**
```bash
# Verify Edge Function environment variables
# Check API credentials
# Review Edge Function logs
```

**"High latency"**
```bash
# Lower video quality
# Check network connection
# Verify provider region selection
```

See full troubleshooting in `STREAMING_QUICKSTART.md`.

## 📚 Additional Resources

### Provider Documentation
- [Agora Docs](https://docs.agora.io/)
- [Daily.co Docs](https://docs.daily.co/)
- [Twilio Video Docs](https://www.twilio.com/docs/video)

### Code Examples
- See `LIVE_STREAMING_INTEGRATION.md` for complete code examples
- Check `src/lib/streamingUtils.ts` for utility functions
- Review `.env.streaming.example` for configuration options

### Community
- Agora: [Community Forum](https://www.agora.io/en/community/)
- Daily.co: [Discord](https://www.daily.co/community)
- Twilio: [Support](https://support.twilio.com/)

## 🎓 Learning Path

1. **Start Simple**
   - Use Daily.co for quick prototype
   - Get basic streaming working
   - Learn the concepts

2. **Add Features**
   - Implement chat (already done!)
   - Add item requests (already done!)
   - Customize UI

3. **Optimize**
   - Add quality selection
   - Implement reconnection logic
   - Add stream recording

4. **Scale**
   - Monitor usage and costs
   - Optimize for your use case
   - Consider switching providers if needed

## ✅ Success Checklist

Your integration is complete when:
- [ ] Pickers can start streams
- [ ] Collectors can watch streams
- [ ] Video quality is acceptable
- [ ] Chat works during streams
- [ ] Item requests work during streams
- [ ] Streams end properly
- [ ] Delete functionality works
- [ ] Mobile devices work
- [ ] Costs are within budget

## 🚀 Ready to Start?

1. Open `STREAMING_QUICKSTART.md`
2. Follow the checklist
3. You'll be live streaming in 1-3 hours!

## 💬 Need Help?

- Check the documentation files
- Review provider documentation
- Test on a simple setup first
- Start with Daily.co if unsure

Good luck with your integration! 🎉
