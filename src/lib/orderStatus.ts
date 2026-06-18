/**
 * Order Status Helper Functions
 * Simplified status system based on actual user workflow
 */

export type OrderStatus =
  | 'awaiting_quote'     // Collector placed order, waiting for shipping quote
  | 'quote_provided'     // Picker provided quote, waiting for payment
  | 'payment_pending'    // Payment being processed
  | 'paid'               // Payment successful, picker can ship
  | 'shipped'            // Item shipped by picker
  | 'delivered'          // Item delivered to collector
  | 'completed'          // Collector confirmed, payment released
  | 'cancelled'          // Order cancelled
  | 'refunded';          // Payment refunded

export type UserType = 'collector' | 'client' | 'picker';

/**
 * Get display-friendly status text based on user type
 */
export function getStatusDisplay(status: OrderStatus, userType: UserType): string {
  const isCollector = userType === 'collector' || userType === 'client';

  if (isCollector) {
    switch (status) {
      case 'awaiting_quote': return 'Waiting for Shipping Quote';
      case 'quote_provided': return 'Review Quote & Pay';
      case 'payment_pending': return 'Processing Payment';
      case 'paid': return 'Paid - Picker Preparing Item';
      case 'shipped': return 'In Transit - Auto-release in 14 Days';
      case 'delivered': return 'Delivered - Confirm to Release Payment';
      case 'completed': return 'Order Complete';
      case 'cancelled': return 'Cancelled';
      case 'refunded': return 'Refunded';
      default: return status;
    }
  } else {
    switch (status) {
      case 'awaiting_quote': return 'Provide Shipping Quote';
      case 'quote_provided': return 'Quote Sent - Awaiting Payment';
      case 'payment_pending': return 'Payment Processing';
      case 'paid': return 'Paid - Prepare & Ship Item';
      case 'shipped': return 'Shipped - Payment Auto-releases in 14 Days';
      case 'delivered': return 'Delivered - Payment Auto-releases in 14 Days';
      case 'completed': return 'Completed - Payment Released';
      case 'cancelled': return 'Cancelled';
      case 'refunded': return 'Refunded';
      default: return status;
    }
  }
}

/**
 * Get status color classes for badges
 */
export function getStatusColor(status: OrderStatus): string {
  switch (status) {
    case 'awaiting_quote':
      return 'bg-yellow-100 text-yellow-800 border-yellow-300';
    case 'quote_provided':
      return 'bg-amber-100 text-amber-800 border-amber-300';
    case 'payment_pending':
      return 'bg-blue-100 text-blue-800 border-blue-300';
    case 'paid':
      return 'bg-teal-100 text-teal-800 border-teal-300';
    case 'shipped':
      return 'bg-cyan-100 text-cyan-800 border-cyan-300';
    case 'delivered':
      return 'bg-emerald-100 text-emerald-800 border-emerald-300';
    case 'completed':
      return 'bg-green-100 text-green-800 border-green-300';
    case 'cancelled':
      return 'bg-red-100 text-red-800 border-red-300';
    case 'refunded':
      return 'bg-orange-100 text-orange-800 border-orange-300';
    default:
      return 'bg-gray-100 text-gray-800 border-gray-300';
  }
}

/**
 * Get icon component name for status
 */
export function getStatusIconName(status: OrderStatus): string {
  switch (status) {
    case 'awaiting_quote': return 'Clock';
    case 'quote_provided': return 'FileText';
    case 'payment_pending': return 'CreditCard';
    case 'paid': return 'DollarSign';
    case 'shipped': return 'Truck';
    case 'delivered': return 'Home';
    case 'completed': return 'CheckCircle';
    case 'cancelled': return 'XCircle';
    case 'refunded': return 'RefreshCw';
    default: return 'Package';
  }
}

/**
 * Get available actions for an order based on status and user type
 */
export function getAvailableActions(
  status: OrderStatus,
  userType: UserType,
  hasPickupVideo: boolean,
  hasShippingTracking: boolean,
  paymentStatus: string,
  shippingQuoteStatus?: string
): string[] {
  const isCollector = userType === 'collector' || userType === 'client';
  const actions: string[] = [];

  if (isCollector) {
    switch (status) {
      case 'awaiting_quote':
        actions.push('message_picker');
        actions.push('cancel_order');
        break;
      case 'quote_provided':
        actions.push('pay_now');
        actions.push('message_picker');
        actions.push('cancel_order');
        break;
      case 'payment_pending':
        actions.push('view_payment_status');
        break;
      case 'paid':
        actions.push('message_picker');
        actions.push('track_order');
        break;
      case 'shipped':
        actions.push('track_order');
        actions.push('message_picker');
        break;
      case 'delivered':
        actions.push('confirm_delivery');
        actions.push('report_issue');
        break;
      case 'completed':
        actions.push('leave_review');
        actions.push('reorder');
        break;
    }
  } else {
    // Picker actions
    switch (status) {
      case 'awaiting_quote':
        actions.push('provide_quote');
        actions.push('message_collector');
        break;
      case 'quote_provided':
        actions.push('update_quote');
        actions.push('message_collector');
        break;
      case 'payment_pending':
        actions.push('view_payment_status');
        break;
      case 'paid':
        if (!hasPickupVideo) {
          actions.push('upload_pickup_video');
        }
        actions.push('mark_shipped');
        actions.push('message_collector');
        break;
      case 'shipped':
        actions.push('update_tracking');
        actions.push('message_collector');
        break;
      case 'delivered':
        actions.push('message_collector');
        break;
      case 'completed':
        actions.push('view_payout');
        break;
    }
  }

  return actions;
}

/**
 * Get filter options based on user type
 * Ultra-simplified for BOTH collectors and pickers
 */
export function getFilterOptions(userType: UserType): { value: string; label: string }[] {
  const isCollector = userType === 'collector' || userType === 'client';

  if (isCollector) {
    return [
      { value: 'all', label: 'All Orders' },
      { value: 'action_required', label: 'Action Required' },
      { value: 'completed', label: 'Completed' },
    ];
  } else {
    // Pickers: Also simplified to 3 tabs
    return [
      { value: 'all', label: 'All Orders' },
      { value: 'action_required', label: 'Action Required' },
      { value: 'completed', label: 'Completed' },
    ];
  }
}

/**
 * Check if order requires action based on user type
 */
export function requiresCollectorAction(status: OrderStatus): boolean {
  return status === 'quote_provided' || status === 'delivered';
}

export function requiresPickerAction(status: OrderStatus): boolean {
  return status === 'awaiting_quote' || status === 'paid';
}

/**
 * Get next status in the workflow
 */
export function getNextStatus(currentStatus: OrderStatus, userType: UserType): OrderStatus | null {
  const isCollector = userType === 'collector' || userType === 'client';

  if (isCollector) {
    switch (currentStatus) {
      case 'quote_provided': return 'payment_pending';
      case 'payment_pending': return 'paid';
      case 'delivered': return 'completed';
      default: return null;
    }
  } else {
    switch (currentStatus) {
      case 'awaiting_quote': return 'quote_provided';
      case 'paid': return 'shipped';
      default: return null;
    }
  }
}
