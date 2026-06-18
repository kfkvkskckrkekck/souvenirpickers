# Email Notification System - Complete Setup Guide

## Overview

The SouvenirPickers platform now has a fully automated email notification system using **Resend API** and **Supabase Edge Functions**. Emails are sent automatically when specific events occur in the database.

---

## What Was Implemented

### 1. Updated Edge Function: `send-email-notification`

**Location:** `supabase/functions/send-email-notification/index.ts`

**Key Features:**
- Uses Resend API for reliable email delivery (replaced Nodemailer/SMTP)
- Supports multiple email types with beautiful HTML templates
- Includes proper CORS headers and error handling
- Detailed logging for debugging

**Supported Email Types:**
- `new_order_picker` - Notify picker about new orders
- `order_confirmation` - Confirm order received by client
- `order_status_update` - Notify client of status changes
- `message_received` - Notify user of new messages
- `wishlist_price_drop` - Alert users to price drops
- `new_listing_match` - Notify users of matching listings
- `custom_order_response` - Notify client of picker responses
- `payment_confirmation` - Confirm payment received

### 2. Database Triggers (Automatic)

Created three database functions with triggers that automatically call the Edge Function:

#### A. `notify_new_order()`
**Trigger:** When a new order is inserted into the `orders` table

**Sends:**
1. Email to **picker** - "You have a new order!"
2. Email to **client** - "Your order is confirmed!"

**Data included:**
- Order ID
- Item title
- Quantity
- Total amount
- Customer/Picker names

#### B. `notify_order_status_change()`
**Trigger:** When an order status is updated in the `orders` table

**Sends:**
- Email to **client** - "Your order status has changed"

**Data included:**
- Order ID
- New status (pending, accepted, in_progress, delivered, etc.)
- Optional notes from the picker

#### C. `notify_new_message()`
**Trigger:** When a new message is inserted into `conversation_messages` table

**Sends:**
- Email to **all participants** in the conversation (except the sender)

**Data included:**
- Sender name
- Message preview (first 100 characters)
- Link to view full message

---

## How It Works

```
┌─────────────────┐
│  User Action    │  (e.g., Client places order)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Database Event  │  (INSERT into orders table)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Trigger Fires   │  (trigger_new_order_notification)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Function Runs   │  (notify_new_order)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Calls Edge Fn   │  (send-email-notification)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Resend API      │  (Sends beautiful HTML email)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ User Receives   │  ✉️ Email delivered!
└─────────────────┘
```

---

## Environment Variables Required

### In Supabase Edge Function Settings:

You need to configure the **Resend API Key**:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to: **Edge Functions** → **Settings**
3. Add secret:
   - **Key:** `RESEND_API_KEY`
   - **Value:** Your Resend API key from [resend.com](https://resend.com)

**Getting a Resend API Key:**
1. Sign up at [resend.com](https://resend.com)
2. Verify your sending domain (or use their test domain)
3. Create an API key in the dashboard
4. Copy and paste into Supabase

---

## Email Templates

All emails use professional HTML templates with:
- Branded header with gradient (blue to orange)
- Clean, readable content area
- Call-to-action buttons
- Footer with branding

**Example: New Order Email (to Picker)**
```
Subject: New Order Received - Order #abc12345

Hi [Picker Name],

Great news! You received a new order from [Customer Name].

Order #: abc12345
Item: [Item Title]
Quantity: 2
Amount: $45.00

Please log in to accept and process this order.

[View Order Details] (button)
```

---

## Testing the System

### Manual Test (via Edge Function directly):

```javascript
const supabase = createClient(supabaseUrl, supabaseKey);

const { data, error } = await supabase.functions.invoke('send-email-notification', {
  body: {
    to: 'test@example.com',
    subject: 'Test Email',
    type: 'order_confirmation',
    data: {
      customer_name: 'John Doe',
      order_id: 'test-123',
      item_title: 'Eiffel Tower Keychain',
      total_amount: '25.00'
    }
  }
});

console.log('Email sent:', data);
```

### Automatic Test (via database action):

1. **Create a test order** through the app
2. Check the Edge Function logs in Supabase
3. Verify email was received

---

## Monitoring & Debugging

### Check Edge Function Logs:

1. Go to **Supabase Dashboard** → **Edge Functions**
2. Click on `send-email-notification`
3. View **Logs** tab

**You should see:**
```
Processing email notification: { to: 'user@example.com', type: 'new_order_picker', ... }
Email sent successfully via Resend: { id: 're_...' }
```

### Check Database Trigger Logs:

Run this query in the SQL Editor:
```sql
-- View recent orders that should have triggered emails
SELECT
  o.id,
  o.created_at,
  o.status,
  cp.email as client_email,
  pp.email as picker_email
FROM orders o
JOIN profiles cp ON cp.id = o.client_id
JOIN profiles pp ON pp.id = o.picker_id
ORDER BY o.created_at DESC
LIMIT 10;
```

---

## Troubleshooting

### ❌ Emails Not Sending

**Check:**
1. Is `RESEND_API_KEY` configured in Edge Function settings?
2. Is the email address valid?
3. Is Resend domain verified? (for custom domains)
4. Check Edge Function logs for errors

### ❌ Triggers Not Firing

**Check:**
```sql
-- Verify triggers exist
SELECT * FROM pg_trigger WHERE tgname LIKE '%notification%';

-- Test trigger manually
INSERT INTO orders (client_id, picker_id, listing_id, total_price, quantity)
VALUES (...);
```

### ❌ Net Extension Missing

If you see errors about `net.http_post`, enable the `http` extension:
```sql
CREATE EXTENSION IF NOT EXISTS http;
```

---

## Key Pieces That Must Be Maintained

✅ **Valid Resend API Key** - Without this, emails won't send
✅ **Edge Function Deployed** - Must be active and updated
✅ **Database Triggers** - Must remain enabled
✅ **User Email Addresses** - Must be valid in profiles table
✅ **Sender Domain** - Configured in Resend (or use their test domain)

---

## Future Enhancements

You can easily add more email notifications by:

1. **Adding a new email type** to the Edge Function
2. **Creating a new database trigger** for the event
3. **Calling the Edge Function** with the new type

**Example:** Notify picker when order is delivered:
```sql
CREATE OR REPLACE FUNCTION notify_order_delivered()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'delivered' THEN
    -- Call send-email-notification with type 'order_delivered'
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## Summary

✅ **Resend API** integrated for reliable email delivery
✅ **Edge Function** deployed with beautiful HTML templates
✅ **Database triggers** automatically send emails on events
✅ **No manual intervention** required - fully automated
✅ **Proper error handling** - won't break database operations
✅ **Detailed logging** for debugging and monitoring

**The system is now live and will automatically send emails when:**
- A new order is placed
- Order status changes
- New messages are sent

🎉 **Your email notification system is complete and ready to use!**
