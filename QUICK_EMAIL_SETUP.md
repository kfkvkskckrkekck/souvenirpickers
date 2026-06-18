# Quick Email Template Setup (2 Minutes)

## Option 1: Use Supabase Default Templates (Fastest)

### Step 1: Get Default Templates
1. Go to: https://github.com/supabase/auth/blob/master/README.md
2. Scroll down to find the **Default Email Templates** section
3. Copy the default templates for:
   - Confirm signup
   - Reset password
   - Magic Link
   - Change Email Address

### Step 2: Configure in Dashboard
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/auth/templates
2. Paste each default template into the corresponding template editor
3. Click **Save** for each template

### Step 3: Configure SMTP
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/settings/auth
2. Scroll to **SMTP Settings**
3. Enable **Enable Custom SMTP**
4. Enter your BlueHost SMTP settings:
   ```
   Host: mail.souvenirpickers.com
   Port: 587
   Username: support@souvenirpickers.com
   Password: (your password)
   Sender name: SouvenirPickers
   Sender email: support@souvenirpickers.com
   ```
5. Click **Save**

### Step 4: Configure Redirect URLs
1. Go to: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/auth/url-configuration
2. Add these redirect URLs:
   ```
   https://souvenirpickers.com/auth/callback
   https://souvenirpickers.com/reset-password
   http://localhost:5173/auth/callback
   http://localhost:5173/reset-password
   ```

## Option 2: Use Custom Branded Templates

If you want branded templates with your colors and design, use the templates in `SETUP_AUTH_EMAILS_NOW.md` instead.

## Important Variables

Supabase uses Go template variables in emails. DO NOT modify these:

- `{{ .ConfirmationURL }}` - The magic link/confirmation URL
- `{{ .Token }}` - The confirmation token (if needed)
- `{{ .TokenHash }}` - Hashed token (if needed)
- `{{ .SiteURL }}` - Your site URL from settings

## Test Your Setup

After configuring:

1. Try signing up a new test user
2. Check your email for the confirmation
3. Try password reset flow
4. Check spam folder if emails don't arrive

## Troubleshooting

**No emails arriving?**
- Verify SMTP credentials are correct
- Check Supabase logs: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/logs/explorer
- Test SMTP connection with: `/public/test-smtp.html`
- Verify sender email is authorized in BlueHost

**Emails going to spam?**
- Set up SPF records in your domain DNS
- Set up DKIM authentication
- Use a consistent "From" email address

**Links not working?**
- Verify redirect URLs are configured correctly
- Check that your app handles the auth callback properly
- Make sure Site URL is set: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/settings/general

## Need Help?

- Supabase Auth Docs: https://supabase.com/docs/guides/auth
- Email Template Docs: https://supabase.com/docs/guides/auth/auth-email-templates
- Support: https://supabase.com/support
