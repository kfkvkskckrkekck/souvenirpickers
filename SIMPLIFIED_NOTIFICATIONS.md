# Simplified Order Notifications

## Philosophy

**Collectors only get notified when they need to take action.**

No spam. No unnecessary updates. Just two simple notifications:
1. Pay Now
2. Confirm Delivery

---

## Collector Notifications (2 Only)

### 1. Ready to Pay
**When:** Picker provides shipping quote
**What:** "Ready to Pay - Quote Received"
**Message:** "Shipping quote ready: $X. Total: $Y"
**Action:** Pay Now

### 2. Confirm Delivery
**When:** Item is delivered
**What:** "Delivered - Confirm Receipt"
**Message:** "Your order arrived! Confirm delivery to release payment."
**Action:** Confirm Delivery

**That's it. Just 2 notifications for collectors.**

---

## Picker Notifications

### 1. Ship Item
**When:** Payment received
**What:** "Payment Received - Ship Item"
**Message:** "Payment received: $X. Prepare and ship the item."
**Action:** Ship the item and mark as shipped

### 2. Payment Released
**When:** Collector confirms delivery
**What:** "Completed - Payment Released"
**Message:** "Delivery confirmed! Payment of $X released to your account."
**Action:** None - just confirmation

---

## What Collectors DON'T Get Notified About

- ❌ Order shipped (they don't need to do anything)
- ❌ Order in transit (they don't need to do anything)
- ❌ Picker preparing item (they don't need to do anything)

**They only get notified when action is required.**

---

## Order Flow

### Collector Experience:
1. Places order
2. **NOTIFICATION:** "Pay Now" → Pays
3. *[Silent waiting]*
4. **NOTIFICATION:** "Confirm Delivery" → Confirms
5. Done!

### Picker Experience:
1. Gets order request
2. Provides shipping quote
3. **NOTIFICATION:** "Ship Item" → Ships item
4. **NOTIFICATION:** "Payment Released" → Gets paid
5. Done!

---

## Benefits

### For Collectors:
- Zero notification spam
- Only 2 emails total per order
- Clear what action to take
- No confusion about "what's happening now"

### For Pickers:
- Clear when payment arrives
- Clear when to ship
- Clear when payment releases

### For Platform:
- Reduced notification fatigue
- Better user experience
- Higher engagement on important actions

---

## Technical Implementation

### Triggers:
- `notify_collector_pay_now` - Only fires when quote is ready
- `notify_picker_ship_item` - Only fires when payment received
- `notify_action_required_only` - Only for delivery confirmation and completion

### No Intermediate Status Notifications:
- Shipped status: Silent for collector
- In transit: Silent for collector
- Preparing: Silent for collector

**Result: Clean, simple, action-focused notifications.**
