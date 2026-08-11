export type OrderStatus =
  | 'pending'
  | 'unpaid'
  | 'accepted'
  | 'in_progress'
  | 'processing'
  | 'paid'
  | 'label_created'
  | 'shipped'
  | 'delivered'
  | 'received'
  | 'completed'
  | 'cancelled'
  | 'refunded';

export type UserType = 'collector' | 'client' | 'picker';

export function getStatusDisplay(status: OrderStatus, userType: UserType, _paymentStatus?: string): string {
  const isCollector = userType === 'collector' || userType === 'client';

  if (isCollector) {
    switch (status) {
      case 'pending': return 'Order Placed';
      case 'accepted': return 'Order Accepted';
      case 'in_progress': return 'Being Prepared';
      case 'paid': return 'Paid - Being Prepared';
      case 'label_created': return 'Shipping Label Created';
      case 'shipped': return 'In Transit';
      case 'delivered': return 'Delivered - Confirm to Release Payment';
      case 'completed': return 'Order Complete';
      case 'cancelled': return 'Cancelled';
      case 'refunded': return 'Refunded';
      default: return status;
    }
  }

  switch (status) {
    case 'pending': return 'Order Placed';
    case 'accepted': return 'Order Accepted';
    case 'in_progress': return 'Being Prepared';
    case 'paid': return 'Paid - Prepare Item';
    case 'label_created': return 'Label Ready';
    case 'shipped': return 'Shipped';
    case 'delivered': return 'Delivered';
    case 'completed': return 'Completed - Payment Released';
    case 'cancelled': return 'Cancelled';
    case 'refunded': return 'Refunded';
    default: return status;
  }
}

export function getStatusColor(status: OrderStatus): string {
  switch (status) {
    case 'pending': return 'bg-yellow-100 text-yellow-800 border-yellow-300';
    case 'accepted': return 'bg-blue-100 text-blue-800 border-blue-300';
    case 'in_progress': return 'bg-indigo-100 text-indigo-800 border-indigo-300';
    case 'paid': return 'bg-teal-100 text-teal-800 border-teal-300';
    case 'label_created': return 'bg-green-100 text-green-800 border-green-300';
    case 'shipped': return 'bg-cyan-100 text-cyan-800 border-cyan-300';
    case 'delivered': return 'bg-emerald-100 text-emerald-800 border-emerald-300';
    case 'completed': return 'bg-green-100 text-green-800 border-green-300';
    case 'cancelled': return 'bg-red-100 text-red-800 border-red-300';
    case 'refunded': return 'bg-orange-100 text-orange-800 border-orange-300';
    default: return 'bg-gray-100 text-gray-800 border-gray-300';
  }
}

export function getStatusIconName(status: OrderStatus): string {
  switch (status) {
    case 'pending': return 'Clock';
    case 'accepted': return 'CheckCircle';
    case 'in_progress': return 'Package';
    case 'paid': return 'DollarSign';
    case 'label_created': return 'Truck';
    case 'shipped': return 'Truck';
    case 'delivered': return 'Home';
    case 'completed': return 'CheckCircle';
    case 'cancelled': return 'XCircle';
    case 'refunded': return 'RefreshCw';
    default: return 'Package';
  }
}

export function getAvailableActions(
  status: OrderStatus,
  userType: UserType,
  hasPickupVideo: boolean,
  _hasShippingTracking: boolean,
  _paymentStatus: string
): string[] {
  const isCollector = userType === 'collector' || userType === 'client';
  const actions: string[] = [];

  if (isCollector) {
    switch (status) {
      case 'pending':
      case 'accepted':
      case 'in_progress':
      case 'paid':
        actions.push('message_picker');
        break;
      case 'label_created':
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
    switch (status) {
      case 'pending':
      case 'accepted':
      case 'in_progress':
        actions.push('message_collector');
        break;
      case 'paid':
        if (!hasPickupVideo) actions.push('upload_pickup_video');
        actions.push('message_collector');
        break;
      case 'label_created':
      case 'shipped':
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

export function getFilterOptions(_userType: UserType): { value: string; label: string }[] {
  return [
    { value: 'all', label: 'All Orders' },
    { value: 'action_required', label: 'Action Required' },
    { value: 'completed', label: 'Completed' },
  ];
}

export function requiresCollectorAction(status: OrderStatus): boolean {
  return status === 'delivered';
}

export function requiresPickerAction(status: OrderStatus): boolean {
  return status === 'paid';
}

export function getNextStatus(currentStatus: OrderStatus, userType: UserType): OrderStatus | null {
  const isCollector = userType === 'collector' || userType === 'client';

  if (isCollector) {
    switch (currentStatus) {
      case 'pending': return 'accepted';
      case 'accepted': return 'in_progress';
      case 'in_progress': return 'paid';
      case 'delivered': return 'completed';
      default: return null;
    }
  }

  switch (currentStatus) {
    case 'pending': return 'accepted';
    case 'accepted': return 'in_progress';
    case 'paid': return 'label_created';
    case 'label_created': return 'shipped';
    default: return null;
  }
}
