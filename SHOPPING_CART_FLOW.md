# Shopping Cart & Payment Flow

## Complete Implementation Summary

### Flow Overview

1. **Browse & Add to Cart**
   - Collectors browse listings in the "Browse Listings" tab
   - Click "Add to Cart" button on any listing
   - Items are added to cart with quantity of 1
   - If item already in cart, quantity is incremented
   - Cart count badge updates in real-time in header

2. **View Shopping Cart**
   - Click shopping cart icon in header (shows badge with item count)
   - Or navigate to "Shopping Cart" in sidebar
   - View all cart items with:
     - Item images
     - Title and location
     - Price per item
     - Quantity controls (+/-)
     - Remove item option
     - Subtotal per item
   - See order summary with total

3. **Checkout Process**
   - Click "Proceed to Checkout"
   - Enter delivery address (auto-filled from profile if available)
   - Add delivery instructions (optional)
   - Select payment method from saved cards
   - Or add new payment method
   - Click "Place Order"

4. **Payment Processing**
   - System creates orders for each cart item
   - Generates Stripe payment intents for each order
   - Opens payment modal with Stripe Elements
   - Displays total amount and order details
   - For multiple orders, processes payments sequentially
   - Enter cardholder name
   - Enter payment details (card, digital wallet, etc.)
   - Click "Pay" to complete transaction

5. **Payment Confirmation**
   - Success screen displays with green checkmark
   - Order confirmation message
   - Options to:
     - View My Orders
     - Continue Shopping
   - Cart is cleared
   - Orders are marked as confirmed
   - Payment status updated to "paid"

### Key Features

- **Real-time Updates**: Cart count updates instantly across the app
- **Multi-order Support**: Handles multiple items from different sellers
- **Escrow System**: Payments held in escrow until delivery confirmed
- **Secure Payments**: Stripe integration with PCI compliance
- **Payment Methods**: Save and manage multiple payment methods
- **Order Tracking**: All orders viewable in "My Orders" section
- **Platform Fees**: 10% platform fee automatically calculated
- **Direct Transfers**: Funds transferred directly to picker's Stripe Connect account

### Components

- **CartView**: Main shopping cart interface
- **CartPaymentModal**: Stripe payment processing modal
- **CollectorPaymentSetup**: Payment method management
- **Header**: Cart badge and quick access
- **Sidebar**: Shopping cart navigation

### Database Tables

- `cart_items`: Stores cart items with client_id, listing_id, quantity
- `orders`: Created from cart items with delivery details
- `payment_intents`: Stripe payment intent records
- `payment_escrow`: Escrow records for each payment
- `collector_payment_methods`: Saved payment methods

### Edge Functions

- `create-payment-intent`: Creates Stripe payment intent for orders
- `stripe-webhook`: Handles Stripe payment confirmations
- `process-escrow-releases`: Releases funds after delivery

### Security

- Row Level Security (RLS) enabled on all tables
- Users can only access their own cart items
- Payment methods securely stored
- Stripe handles sensitive card data
- Escrow system protects both buyers and sellers

## User Experience Flow

```
Browse Listings → Add to Cart → View Cart → Enter Delivery Details
→ Select Payment → Process Payment → Confirmation → View Orders
```

All existing functionality remains intact and undisturbed.
