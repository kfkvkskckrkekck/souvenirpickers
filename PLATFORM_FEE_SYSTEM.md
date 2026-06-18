# Platform Fee System

## Overview

The SouveniRpickers platform charges a **10% platform fee** on all item sales. This fee covers platform operation, payment processing, escrow services, and customer support.

## How It Works

### For Pickers (Sellers)

When you list an item:
- **You set the listing price** that collectors will pay
- **The platform deducts 10%** from your earnings
- **You receive 90%** of the listing price after delivery confirmation

### Example Calculation

If you list an item for €100:
```
Listing price:          €100.00
Platform fee (10%):     -€10.00
Your net earnings:       €90.00
```

### Additional Earnings

**Shipping costs** are passed through to you at 100% (no platform fee):
- When you provide a shipping quote to collectors
- The shipping amount is released immediately when you ship the order
- You receive the full shipping amount to cover courier costs

### Visual Warning System

When pickers create or edit listings, they will see:
1. **Yellow warning box** showing the fee breakdown
2. **Real-time calculation** as they enter the price
3. **Clear display** of what they will actually receive

Example display:
```
Platform Fee Notice: 10% will be deducted

Your listing price:     €100.00
Platform fee (10%):     -€10.00
─────────────────────────────────
You receive:             €90.00
```

## Payment Flow

### Step 1: Collector Pays
- Collector pays **100% of listing price + shipping**
- Funds held in **escrow** for protection

### Step 2: Picker Ships
- Picker provides shipping quote
- Picker ships the item
- **Shipping costs released immediately** (100%, no fee)
- Item payment stays in escrow

### Step 3: Delivery Confirmed
- Collector confirms delivery, OR
- Auto-confirmation after 14 days
- **Item earnings released** (90% after platform fee)

### Step 4: Automatic Payout
- Funds transferred to picker's connected bank account
- Arrives in 2-3 business days
- Transparent breakdown in earnings dashboard

## Fee Structure Details

| Component | Platform Fee | Picker Receives |
|-----------|--------------|-----------------|
| Item Price | 10% | 90% |
| Shipping Costs | 0% | 100% |
| Stripe Processing Fees | Absorbed by platform | N/A |

## Why This Model?

This fee structure ensures:
- **Fair pricing** - Pickers know exactly what they'll earn
- **Transparent costs** - No hidden fees or surprises
- **Quality service** - Platform revenue supports features and support
- **Secure payments** - Escrow protection for both parties
- **Simple accounting** - Clear breakdown of all earnings

## Stripe Processing Fees

The platform absorbs all Stripe payment processing fees (~2.9% + €0.30 per transaction), so pickers don't have to worry about:
- Payment gateway costs
- International transaction fees
- Currency conversion fees
- Transfer fees

## Earnings Dashboard

Pickers can track:
- **Total earned** - Lifetime earnings across all orders
- **Available balance** - Ready for payout after delivery confirmations
- **Pending payout** - In escrow awaiting delivery confirmation
- **Paid out** - Already transferred to bank account

## Implementation Files

Key files implementing this system:

1. **Frontend Warning**: `src/components/ListingsView.tsx`
   - Real-time fee calculation display
   - Visual breakdown of earnings

2. **Earnings Display**: `src/components/EarningsView.tsx`
   - Dashboard showing fee deductions
   - Payout history with clear amounts

3. **Backend Processing**: `supabase/functions/process-picker-payout/index.ts`
   - Automatic 10% fee deduction
   - Transfer to picker's bank account

4. **Database**: `picker_payouts` table
   - Records all payouts with amounts
   - Tracks platform fees separately

## Best Practices for Pickers

1. **Price appropriately** - Consider the 10% fee when setting prices
2. **Accurate shipping quotes** - Shipping costs pass through at 100%
3. **Quality service** - Better reviews = more sales = more earnings
4. **Fast shipping** - Get shipping costs released immediately

## Support

For questions about fees or earnings:
- View your **Earnings & Payouts** dashboard
- Contact support through the platform
- Review payout history for detailed breakdowns
