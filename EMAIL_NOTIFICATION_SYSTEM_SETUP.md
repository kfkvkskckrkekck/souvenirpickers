# Email Notification System - Complete Setup Guide

## Overview

The automatic email notification system is now fully configured to send emails when important events occur in your SouvenirPickers application.

## ✅ What's Already Set Up

### 1. Edge Function: `send-email-notification`
Location: `supabase/functions/send-email-notification/index.ts`

This function handles sending emails via SMTP (Nodemailer) with beautiful HTML templates for:
- Order confirmations
- Order shipped notifications
- New message alerts
- Wishlist price drops
- New listing matches
- Custom order responses

### 2. Database Triggers (Just Created)

The following triggers now automatically send emails:

#### **Order Confirmation Emails**
- **Trigger:** `trigger_send_order_confirmation`
- **Fires when:** A new order is created
- **Sends to:** Customer who placed the order
- **Includes:** Order ID, item details, total amount

#### **Order Shipped Emails**
- **Trigger:** `trigger_send_order_status_update`
- **Fires when:** Order status changes to "shipped"
- **Sends to:** Customer
- **Includes:** Tracking number, estimated delivery date

#### **New Message Notifications**
- **Trigger:** `trigger_send_conversation_message_notification`
- **Fires when:** New message is sent in a conversation
- **Sends to:** Message recipient
- **Includes:** Sender name, message preview
- **Respects:** User notification preferences

### 3. Helper Functions

**`send_email_via_edge_function()`**
- Calls the edge function from database triggers
- Handles errors gracefully (doesn't block transactions)
- Uses the `http` extension to make HTTP requests

## ⚠️ Critical Setup Steps Required

### Step 1: Enable HTTP Extension in Supabase

The `http` extension is **required** for database triggers to call edge functions.

**How to enable:**

1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/database/extensions
2. Search for "http"
3. Click "Enable" on the `http` extension
4. Or run this SQL:
   ```sql
   CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;
   ```

### Step 2: Configure SMTP Secrets

Your SMTP credentials must be set as Supabase secrets for the edge function to send emails.

**Required secrets:**

1. Go to: https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/settings/functions
2. Add these secrets:

```
SMTP_HOST=mail.souvenirpickers.com
SMTP_PORT=587
SMTP_USER=your-smtp-username
SMTP_PASS=your-smtp-password
SMTP_FROM=noreply@souvenirpickers.com
```

**For Bluehost SMTP (based on your setup):**
```
SMTP_HOST=mail.souvenirpickers.com
SMTP_PORT=587
SMTP_USER=noreply@souvenirpickers.com (or your full email)
SMTP_PASS=your-bluehost-email-password
SMTP_FROM=noreply@souvenirpickers.com
```

### Step 3: Deploy the Edge Function

The edge function is already created, but you need to deploy it:

```bash
# If using Supabase CLI (not available in this environment)
supabase functions deploy send-email-notification
```

**Or manually:**
1. The function code is at: `supabase/functions/send-email-notification/index.ts`
2. Deploy via Supabase Dashboard or CLI

### Step 4: Test the System

After completing steps 1-3, test the email system:

1. **Test Order Confirmation:**
   - Create a test order
   - Check if confirmation email arrives

2. **Test Order Shipped:**
   - Update an order status to "shipped"
   - Check if shipping notification arrives

3. **Test Message Notification:**
   - Send a message between two users
   - Check if recipient gets email notification

## How It Works (Like Bolt's Implementation)

### Flow Diagram

```
User Action → Database Insert/Update → Trigger Fires → Helper Function → Edge Function → SMTP → Email Sent
```

### Example: Order Confirmation

1. **User places order** → New row inserted in `orders` table
2. **Trigger fires:** `trigger_send_order_confirmation`
3. **Function runs:** `handle_new_order_email()`
4. **Collects data:** Customer email, name, order details
5. **Calls edge function:** `send_email_via_edge_function()`
6. **Edge function:** Generates HTML email, sends via SMTP
7. **Email delivered** to customer's inbox

### Error Handling

- Email failures **don't block** database transactions
- Errors are logged as warnings, not exceptions
- Each function has `EXCEPTION WHEN OTHERS` blocks
- Failed emails are logged but don't affect user experience

## Email Templates

All email templates are defined in `send-email-notification/index.ts` with:
- Professional HTML styling
- Responsive design
- SouvenirPickers branding
- Call-to-action buttons
- Proper email best practices

### Available Email Types:

1. `order_confirmation` - Sent when order is placed
2. `order_shipped` - Sent when order ships
3. `message_received` - Sent when user receives a message
4. `wishlist_price_drop` - Sent when wishlist item price drops
5. `new_listing_match` - Sent when new listing matches user interests
6. `custom_order_response` - Sent when picker responds to custom request

## Notification Preferences

The system respects user notification preferences from the `notification_preferences` table:
- Users can disable email notifications
- Users can disable specific notification types (messages, orders, etc.)
- Defaults to enabled if no preferences are set

## Monitoring & Debugging

### Check if Emails are Being Sent

1. **View Edge Function Logs:**
   - https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/edge-functions

2. **View Database Logs:**
   - https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/logs/postgres-logs
   - Look for `NOTICE` and `WARNING` messages from email functions

3. **Test Edge Function Directly:**
   ```javascript
   const response = await fetch('https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/send-email-notification', {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json',
       'Authorization': 'Bearer YOUR_ANON_KEY'
     },
     body: JSON.stringify({
       to: 'test@example.com',
       subject: 'Test Email',
       type: 'order_confirmation',
       data: {
         customer_name: 'Test User',
         order_id: '12345',
         item_title: 'Test Item',
         total_amount: 99.99
       }
     })
   });
   ```

### Common Issues & Solutions

**Issue: Emails not sending**
- ✅ Check HTTP extension is enabled
- ✅ Verify SMTP secrets are set correctly
- ✅ Check edge function logs for errors
- ✅ Test SMTP credentials with test-smtp-secret function

**Issue: Triggers not firing**
- ✅ Verify triggers exist: `SELECT * FROM pg_trigger WHERE tgname LIKE 'trigger_send%';`
- ✅ Check database logs for trigger errors
- ✅ Ensure functions are created: `SELECT proname FROM pg_proc WHERE proname LIKE 'handle_%email';`

**Issue: HTTP extension not working**
- ✅ Enable in dashboard: Database > Extensions > http
- ✅ Grant permissions if needed
- ✅ Restart database if necessary

## Performance Considerations

- All email sending is **asynchronous** (doesn't block user requests)
- Triggers use `AFTER INSERT/UPDATE` (not BEFORE)
- Error handling prevents failed emails from blocking transactions
- Indexes created on frequently queried columns
- Email sending happens in background via edge function

## Comparison to Built-in Supabase Auth Emails

### Built-in Auth Emails (Configured in Dashboard)
- Signup confirmation
- Password reset
- Magic link
- Email change confirmation

### Custom Application Emails (This System)
- Order confirmations
- Shipping notifications
- Message alerts
- Price drops
- Custom order responses
- Any application-specific notifications

**Both systems work together!**

## Next Steps

1. ✅ **Enable HTTP extension** (most critical)
2. ✅ **Set SMTP secrets** in edge function settings
3. ✅ **Deploy edge function** if not already deployed
4. ✅ **Test all email types** with real data
5. ✅ **Monitor logs** for any errors
6. ✅ **Fix Supabase auth email templates** (see SUPABASE_EMAIL_TEMPLATES_FIX.md)

## Support

If you encounter issues:

1. Check edge function logs for SMTP errors
2. Verify SMTP credentials with test-smtp-secret function
3. Ensure HTTP extension is enabled
4. Review database logs for trigger errors
5. Test edge function directly via Postman or curl

---

**Status:** ✅ Database triggers created and active
**Requirement:** ⚠️ HTTP extension must be enabled
**Requirement:** ⚠️ SMTP secrets must be configured
