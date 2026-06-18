# Deploy in ONE STEP

## You need to do ONE thing:

### Go to this URL and drag the `dist` folder:
**https://app.netlify.com/sites/YOUR-SITE-NAME/deploys**

(Replace YOUR-SITE-NAME with your actual site name in Netlify)

---

## Steps:

1. **Find your `dist` folder** in this project
2. **Open Netlify**: https://app.netlify.com
3. **Click on** your souvenirpickers.com site
4. **Click on** "Deploys" tab at the top
5. **Drag and drop** the entire `dist` folder into the deploy zone
6. **Wait 30 seconds** for upload to complete

---

## After deployment (1-2 minutes):

**Test signup here**: https://souvenirpickers.com/test-auth-live.html

Or go directly to the main site: https://souvenirpickers.com

---

## If you can't find the Netlify site:

Run this command in your terminal from this project folder:

```bash
netlify deploy --prod --dir=dist
```

If `netlify` command is not found, first run:
```bash
npm install -g netlify-cli
netlify login
netlify deploy --prod --dir=dist
```

---

That's it. The site is built and ready. You just need to upload the `dist` folder to Netlify.
