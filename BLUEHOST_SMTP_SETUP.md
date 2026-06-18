# BlueHost SMTP Setup Guide for SouvenirPickers

Your email functions have been updated to use SMTP with BlueHost. Follow these steps to configure SMTP credentials in Supabase.

## 📧 Required SMTP Credentials

You need to add the following environment variables to your Supabase Edge Functions:

### 1. SMTP_HOST
- **Value:** `mail.souvenirpickers.com`
- **Description:** Your BlueHost mail server hostname

### 2. SMTP_PORT
- **Value:** `587` (for TLS) or `465` (for SSL)
- **Description:** SMTP port number
- **Recommended:** Use `587` for TLS

### 3. SMTP_USER
- **Value:** Your full email address (e.g., `noreply@souvenirpickers.com`)
- **Description:** Email account username for authentication

### 4. SMTP_PASS
- **Value:** Your email account password
- **Description:** Password for the email account

### 5. SMTP_FROM (Optional)
- **Value:** `noreply@souvenirpickers.com` (or any email address you want to send from)
- **Description:** Default "from" email address
- **Note:** If not set, functions will use defaults like `noreply@souvenirpickers.com`, `billing@souvenirpickers.com`, or `orders@souvenirpickers.com`

---

## 🔧 How to Add Secrets to Supabase

### Step 1: Get Your BlueHost SMTP Credentials

1. Log in to your BlueHost cPanel
2. Navigate to **Email Accounts**
3. Find or create email addresses you want to use:
   - `noreply@souvenirpickers.com` (for general notifications)
   - `billing@souvenirpickers.com` (for invoices)
   - `orders@souvenirpickers.com` (for order confirmations)
4. Note down the passwords for these accounts

### Step 2: Add Secrets to Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Project Settings** → **Edge Functions** → **Secrets**
4. Add each secret one by one:

   ```
   Name: SMTP_HOST
   Value: mail.souvenirpickers.com
   ```

   ```
   Name: SMTP_PORT
   Value: 587
   ```

   ```
   Name: SMTP_USER
   Value: noreply@souvenirpickers.com
   ```

   ```
   Name: SMTP_PASS
   Value: [your-email-password]
   ```

   ```
   Name: SMTP_FROM
   Value: noreply@souvenirpickers.com
   ```

### Step 3: Redeploy Edge Functions (If Needed)

After adding secrets, your edge functions should automatically use them. No redeployment is required.

---

## ✅ Updated Edge Functions

The following functions now support SMTP email sending:

1. **send-email-notification** - General notifications (order confirmations, shipping updates, messages, etc.)
2. **send-invoice-email** - Monthly invoices for picker subscriptions
3. **send-payment-confirmation** - Payment confirmation emails

---

## 🧪 Testing Email Delivery

Once you've added the SMTP credentials:

1. Create a test order in your application
2. Check the Edge Function logs in Supabase Dashboard → **Edge Functions** → **Logs**
3. Look for messages like:
   - `Email sent successfully to [email]` ✅ (Success)
   - `SMTP not configured. Email notification prepared but not sent.` ⚠️ (SMTP not configured)

---

## 📝 BlueHost SMTP Settings Reference

| Setting | Value |
|---------|-------|
| **Incoming Server (IMAP)** | mail.souvenirpickers.com |
| **IMAP Port** | 993 (SSL) |
| **Outgoing Server (SMTP)** | mail.souvenirpickers.com |
| **SMTP Port** | 465 (SSL) or 587 (TLS) |
| **Username** | Full email address |
| **Password** | Your email password |
| **Authentication** | Required |

---

## 🔐 Security Best Practices

1. **Use Strong Passwords:** Create complex passwords for email accounts
2. **Create Dedicated Email Accounts:** Use separate accounts for different purposes
   - `noreply@souvenirpickers.com` - General notifications
   - `billing@souvenirpickers.com` - Invoices
   - `orders@souvenirpickers.com` - Order confirmations
   - `support@souvenirpickers.com` - Support emails
3. **Enable SPF/DKIM:** Configure these in BlueHost to improve email deliverability
4. **Monitor Email Logs:** Regularly check Supabase Edge Function logs for email delivery issues

---

## 🚀 What Happens Next

After configuration:
- ✅ Order confirmations will be sent automatically
- ✅ Payment receipts will be emailed to customers
- ✅ Shipping notifications will be delivered
- ✅ Monthly invoices will be sent to pickers
- ✅ All notifications will be sent via email

---

## ❓ Troubleshooting

### Emails Not Sending?

1. **Check SMTP credentials are correct**
   - Verify hostname: `mail.souvenirpickers.com`
   - Verify username is the full email address
   - Verify password is correct

2. **Check Edge Function logs**
   - Look for error messages
   - Verify SMTP configuration is being detected

3. **Verify BlueHost email account is active**
   - Log in to cPanel
   - Check email account status

4. **Test SMTP connection**
   - Use an SMTP testing tool
   - Verify you can connect to `mail.souvenirpickers.com:465`

### Common Issues

- **"SMTP not configured"** - Secrets not added to Supabase
- **"Authentication failed"** - Wrong username or password
- **"Connection refused"** - Wrong port or hostname
- **Emails going to spam** - Configure SPF, DKIM, and DMARC records in BlueHost DNS

---

## 📞 Need Help?

If you encounter issues:
1. Check BlueHost documentation for SMTP settings
2. Verify email accounts are properly configured in cPanel
3. Review Supabase Edge Function logs for detailed error messages
4. Contact BlueHost support for email server issues
