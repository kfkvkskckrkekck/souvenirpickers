# Stripe Webhook Testing Guide

## ✅ Setup Complete

Your webhook has been created and the secret has been updated. Here's how to test it:

---

## 🧪 Test Methods

### Method 1: Use Test Page (Recommended)
1. Open: `/test-stripe-webhook.html` in your browser
2. Enter test card: `4242 4242 4242 4242`
3. Use any future date, any CVC
4. Click "Create Test Payment"
5. Check results

### Method 2: Stripe Dashboard Test
1. Go to [Stripe Webhooks Dashboard](https://dashboard.stripe.com/test/webhooks)
2. Click your webhook
3. Click "Send test webhook"
4. Select event: `payment_intent.succeeded`
5. Click "Send test webhook"
6. Check the response (should be 200 OK)

### Method 3: Check Webhook Logs
1. Go to [Supabase Edge Functions](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/functions)
2. Click `stripe-webhook`
3. Click "Logs" tab
4. Trigger a test event
5. Watch logs in real-time

---

## 🔍 What to Look For

### Successful Webhook Response:
```json
{
  "received": true
}
```

### Events Your Webhook Handles:
- ✅ `payment_intent.succeeded` → Updates order to "paid"
- ✅ `payment_intent.payment_failed` → Marks payment as failed
- ✅ `transfer.created` → Logs payout transfers
- ✅ `account.updated` → Updates picker Connect account status

---

## 🚨 Troubleshooting

### Webhook Returns 500 Error:
- Check Edge Function logs for errors
- Verify STRIPE_WEBHOOK_SECRET is set correctly
- Check database permissions

### Webhook Never Receives Events:
- Verify webhook URL: `https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook`
- Check webhook is enabled in Stripe
- Verify events are selected in Stripe webhook settings

### Payment Works But No Notifications:
- Check `payment_intents` table for matching records
- Check `orders` table status updates
- Check `notifications` table for new entries

---

## 📊 Verify Database Updates

After a successful test payment, check these tables:

```sql
-- Check payment intent was updated
SELECT * FROM payment_intents
WHERE stripe_payment_intent_id = 'pi_xxx'
ORDER BY created_at DESC LIMIT 1;

-- Check order was updated to "paid"
SELECT id, status, payment_status
FROM orders
ORDER BY created_at DESC LIMIT 1;

-- Check notifications were created
SELECT * FROM notifications
ORDER BY created_at DESC LIMIT 5;
```

---

## 🎯 Next Steps

1. ✅ Test with the test page
2. ✅ Verify Stripe Dashboard shows successful webhook deliveries
3. ✅ Check Supabase Edge Function logs
4. ✅ Verify database records were created/updated
5. ✅ Test payment failure scenario
6. ✅ Test with real user flow

---

## 🔗 Useful Links

- [Stripe Webhooks Dashboard](https://dashboard.stripe.com/test/webhooks)
- [Supabase Edge Functions](https://supabase.com/dashboard/project/bfqvzxczmvfteqbhgyvx/functions/stripe-webhook)
- [Test Cards](https://stripe.com/docs/testing#cards)

---

## ⚡ Quick Test Command

You can also test the webhook endpoint directly:

```bash
curl -X POST https://bfqvzxczmvfteqbhgyvx.supabase.co/functions/v1/stripe-webhook \
  -H "Content-Type: application/json" \
  -d '{"type": "payment_intent.succeeded", "data": {"object": {"id": "pi_test_123"}}}'
```

This will trigger the webhook handler without going through Stripe.
