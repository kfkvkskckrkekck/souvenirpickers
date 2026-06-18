# Cancel Shipping Quote Feature - Implemented

## Overview
Added functionality for collectors to cancel shipping quotes after receiving them from pickers, giving them the option to reject unwanted quotes and request new ones.

## What Was Implemented

### 1. Cancel Quote Button
- Added a red "Cancel Quote" button next to the "Accept Quote & Pay Now" button
- Button appears only when shipping quote is in `quote_provided` status
- Shows loading state while processing cancellation
- Requires confirmation before canceling

### 2. Quote Cancellation Logic
- Resets shipping quote status back to `pending_quote`
- Clears transportation cost, shipping notes, and estimated weight
- Allows picker to provide a new quote if requested
- Shows success/error toast messages

### 3. Picker Notification System
- Database trigger automatically notifies picker when their quote is canceled
- Picker receives in-app notification titled "Shipping Quote Canceled"
- Notification includes order details and allows picker to provide new quote

### 4. User Experience
- Confirmation dialog prevents accidental cancellations
- Both buttons disabled while processing to prevent double-clicks
- Clear visual feedback with loading indicators
- Automatic page refresh after successful cancellation

## How It Works

### For Collectors (Clients):
1. Receive shipping quote from picker
2. Review the transportation cost and details
3. Choose to either:
   - **Accept Quote & Pay Now** - Proceed with payment
   - **Cancel Quote** - Reject the quote and reset the order

### For Pickers:
1. Automatically receive notification when collector cancels quote
2. Can provide a new shipping quote through the order details
3. Process repeats until collector accepts or order is canceled

## Technical Details

### Files Modified:
- `src/components/OrdersView.tsx` - Added cancel button and handler function
- Database migration - Added trigger for picker notifications

### Database Changes:
- New trigger: `on_shipping_quote_canceled`
- New function: `notify_picker_quote_canceled()`

### States Updated When Canceling:
```typescript
{
  shipping_quote_status: 'pending_quote',
  transportation_cost: null,
  quote_provided_at: null,
  shipping_notes: null,
  estimated_weight_kg: null
}
```

## Benefits
- Gives collectors more control over their purchasing decisions
- Allows negotiation through multiple quote iterations
- Prevents collectors from feeling locked into unwanted shipping costs
- Improves transparency in the shipping quote workflow
- Maintains proper order state management
