# Supabase Default Email Templates

These are minimal default templates you can use. For the official templates, visit:
https://github.com/supabase/auth/blob/master/README.md

## Confirm Signup Template

**Subject:** Confirm Your Email

**Body:**
```html
<h2>Confirm your signup</h2>

<p>Follow this link to confirm your user:</p>
<p><a href="{{ .ConfirmationURL }}">Confirm your email</a></p>
```

## Reset Password Template

**Subject:** Reset Your Password

**Body:**
```html
<h2>Reset Password</h2>

<p>Follow this link to reset the password for your user:</p>
<p><a href="{{ .ConfirmationURL }}">Reset Password</a></p>
```

## Magic Link Template

**Subject:** Your Magic Link

**Body:**
```html
<h2>Magic Link</h2>

<p>Follow this link to login:</p>
<p><a href="{{ .ConfirmationURL }}">Log In</a></p>
```

## Change Email Address Template

**Subject:** Confirm Email Change

**Body:**
```html
<h2>Confirm Change of Email</h2>

<p>Follow this link to confirm the update of your email from {{ .Email }} to {{ .NewEmail }}:</p>
<p><a href="{{ .ConfirmationURL }}">Change Email</a></p>
```

## Invite User Template

**Subject:** You have been invited

**Body:**
```html
<h2>You have been invited</h2>

<p>You have been invited to create a user on {{ .SiteURL }}. Follow this link to accept the invite:</p>
<p><a href="{{ .ConfirmationURL }}">Accept the invite</a></p>
```

## How to Use These

1. Go to your Supabase Dashboard: https://app.supabase.com/project/bfqvzxczmvfteqbhgyvx/auth/templates
2. Select each template type
3. Copy and paste the HTML body above
4. Update the subject line
5. Click Save

## Customize These Templates

You can enhance these with:
- Your brand colors and logo
- Better styling with inline CSS
- Company footer information
- Security notices
- Expiration warnings
- Better formatting

For fully styled templates, see `SETUP_AUTH_EMAILS_NOW.md`

## Important Notes

- DO NOT modify the template variables like `{{ .ConfirmationURL }}`
- These variables are populated by Supabase automatically
- Templates must be configured in the Dashboard UI (not in code)
- SMTP must be configured for emails to actually send
