# Shipping Quote Workflow Guide

## Overview

The platform now uses a **quote-based shipping cost system** instead of automatic distance calculations. This ensures accurate, competitive shipping costs based on real courier quotes tailored to each order's specific requirements.

---

## For Collectors (Buyers)

### How to Order with Shipping Quotes

#### 1. **Add Items to Cart or Place Direct Order**
- Browse listings and add items you want to your cart
- Alternatively, purchase directly from a listing page
- Enter your complete delivery address with all required fields:
  - Street address
  - Apartment/suite (if applicable)
  - City
  - Postal code
  - Country

#### 2. **Submit Your Order**
- Review the item price (shipping not yet included)
- Click **"Place Order & Request Shipping Quote"**
- Your order is created with status: **"Pending Shipping Quote"**
- Payment is **NOT** processed yet

#### 3. **Wait for Picker's Shipping Quote**
- The picker receives a notification about your order
- They will:
  - Check your delivery address
  - Get quotes from courier companies
  - Consider package weight and dimensions
  - Account for any special shipping requirements

#### 4. **Review and Approve the Quote**
- You'll receive a notification when the picker provides the shipping quote
- Review the quote details including:
  - Shipping cost
  - Estimated delivery time
  - Courier service details
  - Any special notes from the picker
- **You can:**
  - ✅ Approve the quote and proceed to payment
  - 💬 Message the picker to discuss alternatives
  - ❌ Cancel the order if the shipping cost doesn't work for you

#### 5. **Complete Payment**
- Once you approve the shipping cost, the final total is calculated
- Proceed to secure payment through the platform
- Payment is held in escrow until delivery is confirmed

---

## For Pickers (Sellers)

### How to Provide Shipping Quotes

#### 1. **Receive Order Notification**
- You'll get a notification when a collector places an order
- View order details including:
  - Item(s) ordered
  - Quantity
  - Complete delivery address
  - Any special delivery instructions

#### 2. **Calculate Accurate Shipping Cost**
**Steps to get the best quote:**

a. **Prepare Package Information**
   - Weigh the item(s) accurately
   - Measure package dimensions (length × width × height)
   - Consider packaging materials weight
   - Note any fragile items requiring special handling

b. **Get Courier Quotes**
   - Contact multiple courier services (DHL, UPS, FedEx, national postal service, etc.)
   - Provide them with:
     - Origin location (your location)
     - Destination address (collector's address)
     - Package weight and dimensions
     - Declared value (for insurance)
   - Compare quotes for best rates and delivery times

c. **Consider Additional Costs**
   - Insurance (if valuable items)
   - Tracking services
   - Signature on delivery
   - Customs fees (for international shipping)
   - Packaging materials

#### 3. **Update Order with Shipping Quote**
- Navigate to **Orders > Pending Quotes**
- Find the order and click **"Provide Shipping Quote"**
- Enter:
  - **Shipping Cost:** The total shipping amount
  - **Estimated Weight:** Package weight in kg
  - **Shipping Notes:** Include details like:
    - Courier service name
    - Estimated delivery time
    - Tracking availability
    - Any special conditions
- Click **"Submit Shipping Quote"**

#### 4. **Communicate with Collector**
- The collector will be notified of your quote
- Be responsive to any questions through the order messaging system
- Be prepared to:
  - Explain your shipping cost breakdown
  - Offer alternative shipping options if requested
  - Adjust the quote if package requirements change

#### 5. **Await Payment Confirmation**
- Once the collector approves and pays
- You'll receive payment confirmation
- Proceed with item preparation and shipping
- Update order status as you progress

---

## Best Practices

### For Collectors

✅ **Provide accurate delivery addresses**
- Double-check all address fields
- Include apartment/unit numbers
- Add delivery instructions if needed

✅ **Respond promptly to shipping quotes**
- Review quotes within 24-48 hours
- Ask questions if anything is unclear
- Communicate if you need more time to decide

✅ **Be realistic about shipping costs**
- International shipping can be expensive
- Heavy or large items cost more to ship
- Faster delivery options cost more

### For Pickers

✅ **Get accurate measurements**
- Weigh items precisely
- Measure package dimensions correctly
- Account for packaging materials

✅ **Compare multiple courier options**
- Don't settle for the first quote
- Balance cost vs. delivery speed
- Consider reliability and tracking

✅ **Be transparent**
- Provide detailed breakdown of shipping costs
- Explain any additional fees
- Set realistic delivery timeframes

✅ **Respond quickly**
- Aim to provide quotes within 24 hours
- Fast response time improves customer satisfaction
- Communication builds trust

---

## Order Statuses Related to Shipping

| Status | Description |
|--------|-------------|
| **Pending Shipping Quote** | Order placed, waiting for picker to provide shipping cost |
| **Quote Provided** | Picker has provided shipping quote, waiting for collector approval |
| **Quote Approved - Payment Pending** | Collector approved quote, payment processing |
| **Paid** | Payment completed, picker can proceed with shipping |
| **In Transit** | Item shipped, on the way to collector |
| **Delivered** | Collector received the item |

---

## Frequently Asked Questions

### For Collectors

**Q: How long does it take to get a shipping quote?**
A: Most pickers provide quotes within 24-48 hours. You'll receive a notification when it's ready.

**Q: Can I negotiate the shipping cost?**
A: Yes! Use the order messaging system to discuss alternatives with the picker.

**Q: What if the shipping cost is too high?**
A: You can message the picker to discuss cheaper options, or cancel the order before payment.

**Q: Is shipping cost refundable if I cancel?**
A: If you cancel before paying, there are no charges. After payment, refer to the cancellation policy.

### For Pickers

**Q: What if the package weighs more than estimated?**
A: Contact the collector immediately through order messaging to discuss additional costs before shipping.

**Q: Can I update the shipping cost after submitting a quote?**
A: Yes, but only before the collector approves and pays. Communicate any changes clearly.

**Q: What if the collector doesn't respond to my quote?**
A: Send a follow-up message after 48 hours. Orders can be auto-cancelled after 7 days of inactivity.

**Q: Should I include packaging costs in the shipping quote?**
A: Yes, include all costs: courier fees, packaging materials, insurance, and any handling fees.

---

## Technical Implementation

### Database Fields (Cart Items & Orders)

- `transportation_cost` - Shipping cost set by picker
- `shipping_quote_status` - Track quote workflow
  - `no_quote_needed` - Default state
  - `quote_requested` - Collector waiting for quote
  - `quote_provided` - Picker provided quote
  - `quote_expired` - Quote needs updating
- `shipping_notes` - Picker's notes about shipping
- `quote_requested_at` - Timestamp when quote requested
- `quote_provided_at` - Timestamp when quote provided
- `delivery_street`, `delivery_city`, `delivery_postal_code`, `delivery_country` - Structured address
- `estimated_weight_kg` - Package weight for accurate quotes

### Notifications

- Pickers receive notifications when quotes are requested
- Collectors receive notifications when quotes are provided
- Real-time updates keep both parties informed

---

## Support

For questions or issues with the shipping quote system:
- Use the in-app messaging system for order-specific questions
- Contact platform support for technical issues
- Check the FAQ section for common answers
