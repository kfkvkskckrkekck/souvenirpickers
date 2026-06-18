# Deploy LiveSouvenir Without GitHub

## Option 1: Netlify Drop (Easiest - No Account Needed Initially)

1. **Build your project** (already done!)
   ```bash
   npm run build
   ```

2. **Go to Netlify Drop**
   - Visit: https://app.netlify.com/drop
   - Drag and drop the entire `dist` folder from your project
   - Your site will be live instantly!
   - You'll get a URL like: `https://random-name-123.netlify.app`

3. **Add Stripe Secret to Supabase**
   - Go to: https://supabase.com/dashboard
   - Your project → Settings → Edge Functions → Secrets
   - Add: Name: `STRIPE_SECRET_KEY`, Value: (your Stripe key from dashboard.stripe.com)

## Option 2: Netlify CLI (More Control)

1. **Login to Netlify**
   ```bash
   netlify login
   ```
   This will open a browser - create a free Netlify account (no credit card needed)

2. **Deploy**
   ```bash
   netlify deploy --prod
   ```
   - Select "Create & configure a new site"
   - Press Enter for defaults
   - It will deploy your site automatically!

3. **Add Stripe Secret** (same as above)

## Option 3: Alternative Hosts (No Account Required for Testing)

### Vercel
```bash
npm install -g vercel
vercel
```

### Cloudflare Pages
```bash
npm install -g wrangler
wrangler pages deploy dist
```

## Recommended: Use Netlify Drop
It's the fastest way - just drag and drop the `dist` folder!

---

## Don't Forget!
After deploying, you MUST add your Stripe secret key to Supabase or payments won't work:
- https://supabase.com/dashboard → Edge Functions → Secrets → `STRIPE_SECRET_KEY`
