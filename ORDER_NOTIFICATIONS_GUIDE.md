# Order Notifications System

## Overview

Both collectors and pickers receive clear, actionable notifications at every stage of the order process. Notifications are sent both **in-app** and via **email**, ensuring users never miss important updates.

---

## Notification Types

### 1. Shipping Quote Provided

**When:** Picker provides shipping cost for an order

**Collector Receives:**
- **In-App:** "Shipping Quote Ready! - Your picker has provided a shipping quote of $X. Review and proceed to payment to complete your order."
- **Email Subject:** "Your Shipping Quote is Ready - [Item Name]"
- **Email Content:**
  - Item details
  - Item price
  - Shipping cost
  - Total amount
  - **NEXT STEP:** Review Quote & Pay Now
  - Direct link to orders page

**Action Required:** Collector must review and pay

---

### 2. Payment Received

**When:** Collector completes payment

**Picker Receives:**
- **In-App:** "Payment Received - Time to Ship! - Payment of $X has been received. Prepare and ship the item to the collector."
- **Email Subject:** "Payment Received - Ship Order #[Order ID]"
- **Email Content:**
  - Item details
  - Payment amount
  - Complete delivery address
  - **NEXT STEPS:**
    1. Prepare the item
    2. Upload a pickup video (recommended)
    3. Ship the item
    4. Mark as shipped in orders
  - Direct link to orders page

**Action Required:** Picker must prepare and ship item

---

### 3. Order Shipped

**When:** Picker marks order as shipped

**Collector Receives:**
- **In-App:** "Your Order Has Been Shipped! - Your item is on its way! Track your order with: [Tracking Number]"
- **Email Subject:** "Your Order is On Its Way! - [Item Name]"
- **Email Content:**
  - Item details
  - Tracking number (if provided)
  - **NEXT STEP:** Watch for delivery and confirm receipt
  - Direct link to track order

**Action Required:** Collector waits for delivery

---

### 4. Order Delivered

**When:** Item is delivered (carrier confirmation or manual)

**Collector Receives:**
- **In-App:** "Order Delivered - Please Confirm - Your order has been delivered! Please confirm receipt so we can release payment to your picker."
- **Email Subject:** "Please Confirm Delivery - [Item Name]"
- **Email Content:**
  - Item details
  - **IMPORTANT:** Confirm delivery to release payment to picker
  - Note about reporting issues before confirming
  - Direct link to confirm delivery

**Action Required:** Collector must confirm receipt

---

### 5. Delivery Confirmed (Order Complete)

**When:** Collector confirms receipt

**Picker Receives:**
- **In-App:** "Delivery Confirmed - Payment Released! - The collector has confirmed delivery. Your payment of $X has been released."
- **Email Subject:** "Payment Released - Order Complete!"
- **Email Content:**
  - Item details
  - Payment amount
  - Note that payment will be transferred to bank account
  - **NEXT STEP:** Encourage collector to leave a review
  - Direct link to earnings page

**Action Required:** None - payment automatically transferred

---

### 6. Order Cancelled

**When:** Either party cancels the order

**Other Party Receives:**
- **In-App:** "Order Cancelled - Order for '[Item]' has been cancelled."
- **Email Subject:** "Order Cancelled - [Item Name]"
- **Email Content:**
  - Item details
  - Note to contact support with questions
  - Direct link to orders page

**Action Required:** None

---

### 7. Refund Processed

**When:** Payment is refunded to collector

**Collector Receives:**
- **In-App:** "Refund Processed - Your refund of $X has been processed and will appear in your account within 5-10 business days."
- **Email Subject:** "Refund Processed - [Item Name]"
- **Email Content:**
  - Item details
  - Refund amount
  - Timeline: 5-10 business days
  - Note to contact support with questions

**Action Required:** None - refund automatically processed

---

## Notification Features

### In-App Notifications
- Real-time alerts in notification bell
- Includes metadata with action URLs
- Direct links to relevant pages
- Mark as read functionality
- Persistent until read

### Email Notifications
- Professional branded design
- Clear subject lines
- Formatted with item details
- Bold call-to-action buttons
- Direct action links
- Mobile-responsive layout

---

## User Experience

### Clear Next Actions

Every notification tells users:
1. **What happened** - Clear status change description
2. **What you need to do** - Explicit next action
3. **How to do it** - Direct link to take action

### Example Flow

**Collector Journey:**
1. Places order → Waits for quote
2. Gets notification → "Review Quote & Pay" → Clicks email link
3. Pays → Waits for shipment
4. Gets notification → "Order Shipped" → Tracks package
5. Gets notification → "Confirm Delivery" → Confirms receipt
6. Gets confirmation → "Order Complete" → Can leave review

**Picker Journey:**
1. Gets notification → "Provide Shipping Quote" → Adds shipping cost
2. Gets notification → "Payment Received" → Prepares item
3. Ships item → Uploads tracking → Marks as shipped
4. Gets notification → "Delivery Confirmed" → Payment released
5. Views earnings → Payment in bank account

---

## Automatic Triggers

All notifications are automatically sent when:
- Order status changes
- Payment is processed
- Shipping information is updated
- Delivery is confirmed

No manual intervention required - the system handles everything!

---

## Email Delivery

Emails are sent via:
- **SMTP Provider:** Titan Email (BlueHost)
- **From Address:** support@souvenirpickers.com
- **Delivery Time:** Immediate (within seconds)
- **Reliability:** Professional SMTP server with high deliverability

---

## Technical Implementation

### Database Triggers
- `notify_quote_provided` - Fires when shipping quote is provided
- `notify_payment_success` - Fires when payment completes
- `notify_order_status_changes` - Fires on all status changes

### Edge Function
- `send-email-notification` - Handles email delivery
- Supports both structured and plain-text formats
- Fetches user email from auth system
- Uses Nodemailer with SMTP transport

### Notification Function
- `send_order_notification` - Unified notification sender
- Creates in-app notification
- Triggers email notification
- Includes all metadata for actions

---

## Benefits

### For Collectors
- Never miss order updates
- Know exactly what to do next
- Track orders easily
- Quick access to actions

### For Pickers
- Immediate payment alerts
- Clear shipping instructions
- Delivery confirmation alerts
- Automatic payout notifications

### For Platform
- Reduced support tickets
- Better user engagement
- Faster order completion
- Higher satisfaction rates

---

## Support

If notifications are not received:
1. Check spam/junk folder
2. Verify email address in profile
3. Check in-app notification bell
4. Contact support@souvenirpickers.com

All notifications are logged and can be reviewed by support team.
