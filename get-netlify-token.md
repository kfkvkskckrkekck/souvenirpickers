# 🔑 Get a Fresh Netlify Token

Your current Netlify token appears to be expired. Here's how to get a new one:

---

## Quick Steps

### 1. Generate New Token

1. **Go to Netlify**
   - Visit: https://app.netlify.com/user/applications/personal
   - (Must be logged in)

2. **Create Token**
   - Click: **"New access token"**
   - Description: `souvenirpickers-deploy`
   - Click: **"Generate token"**

3. **Copy Token**
   - Token shows only ONCE
   - Copy it immediately
   - Looks like: `nfp_XXXXXXXXXXXXXXXXXXXXXX`

### 2. Update .env File

Replace the old token in your `.env` file:

```bash
# Old (expired):
NETLIFY_AUTH_TOKEN=nfp_1RMYF7yLiWvHNNLqvsiH2grbErNyMpXy4076

# New (your fresh token):
NETLIFY_AUTH_TOKEN=nfp_YOUR_NEW_TOKEN_HERE
```

### 3. Test the Token

```bash
# Export the token
export NETLIFY_AUTH_TOKEN=nfp_YOUR_NEW_TOKEN_HERE

# Test it works
npx netlify-cli status --site 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c

# Should show your site info
```

---

## What You Can Do With the Token

### Deploy Manually
```bash
./deploy-with-token.sh
```

### Link Your Site
```bash
export NETLIFY_AUTH_TOKEN=nfp_YOUR_TOKEN
npx netlify-cli link --id 4b0690b0-7d5e-46aa-9d2a-531524ae8c2c
```

### Set Environment Variables
```bash
npx netlify-cli env:set VAR_NAME "value"
```

### View Site Status
```bash
npx netlify-cli status
```

---

## Security Notes

⚠️ **Keep your token secure:**
- Never commit to GitHub
- Already in `.gitignore` ✅
- Don't share publicly
- Regenerate if exposed

✅ **Token Permissions:**
- Deploy sites
- Manage builds
- Update settings
- View logs

---

## Alternative: Use GitHub Instead

Don't want to use tokens? Set up GitHub auto-deploy instead:

See: `GITHUB_AUTODEPLOY_GUIDE.md`

With GitHub integration:
- No token needed for deploys
- Automatic on every push
- Deploy previews for PRs
- Easier team collaboration

---

## Need Help?

**Token not working?**
- Make sure it's copied correctly
- No extra spaces or line breaks
- Regenerate if needed

**Can't access Netlify?**
- Check you're logged into correct account
- Site ID: `4b0690b0-7d5e-46aa-9d2a-531524ae8c2c`

**Want to use GitHub instead?**
- Follow: `GITHUB_AUTODEPLOY_GUIDE.md`
- No tokens needed
- Auto-deploy on push

---

## Quick Reference

**Get Token:**
https://app.netlify.com/user/applications/personal

**Your Site:**
https://app.netlify.com/sites/4b0690b0-7d5e-46aa-9d2a-531524ae8c2c

**Deploy Script:**
```bash
./deploy-with-token.sh
```

**Site URLs:**
- https://souvenirpickers.netlify.app
- https://souvenirpickers.com
