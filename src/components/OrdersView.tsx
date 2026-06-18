import { useState, useEffect, useRef } from 'react';
import { Package, Clock, CheckCircle, XCircle, DollarSign, MapPin, User, AlertTriangle, AlertCircle, Video, Upload, CreditCard, Loader, Truck, RefreshCw } from 'lucide-react';
import { supabase, Order, Listing, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { ReviewForm } from './ReviewForm';
import { EscrowStatusDisplay } from './EscrowStatusDisplay';
import { uploadPickupVideo } from '../lib/storage';
import OrderConfirmation from './OrderConfirmation';
import { CartPaymentModal } from './CartPaymentModal';
import { getStatusDisplay, getStatusColor, getAvailableActions, getFilterOptions, requiresCollectorAction, requiresPickerAction, type OrderStatus } from '../lib/orderStatus';

type EscrowRecord = {
  id: string;
  status: 'held' | 'released' | 'refunded';
  amount: number;
  held_at: string;
  released_at?: string;
  notes?: string;
};

type OrderWithDetails = Order & {
  listing?: Listing;
  client?: Profile;
  picker?: Profile;
  escrow?: EscrowRecord;
  has_review?: boolean;
};

type OrdersViewProps = {
  onViewChange?: (view: string) => void;
  initialOrderId?: string | null;
};

export function OrdersView({ onViewChange, initialOrderId }: OrdersViewProps = {}) {
  const { profile } = useAuth();
  const toast = useToast();
  const [orders, setOrders] = useState<OrderWithDetails[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>('all');
  const [reviewingOrder, setReviewingOrder] = useState<OrderWithDetails | null>(null);
  const [disputingOrder, setDisputingOrder] = useState<string | null>(null);
  const [disputeReason, setDisputeReason] = useState('');
  const [uploadingVideo, setUploadingVideo] = useState<string | null>(null);
  const [providingQuoteFor, setProvidingQuoteFor] = useState<string | null>(null);
  const [shippingCost, setShippingCost] = useState('');
  const [shippingNotes, setShippingNotes] = useState('');
  const [estimatedWeight, setEstimatedWeight] = useState('');
  const [paymentModalOrder, setPaymentModalOrder] = useState<{ orderId: string; clientSecret: string; amount: number } | null>(null);
  const [acceptingQuote, setAcceptingQuote] = useState<string | null>(null);
  const [payoutSetupComplete, setPayoutSetupComplete] = useState<boolean>(true);
  const [markingShipped, setMarkingShipped] = useState<string | null>(null);
  const [trackingNumber, setTrackingNumber] = useState('');
  const [cancelingQuote, setCancelingQuote] = useState<string | null>(null);
  const [highlightedOrderId, setHighlightedOrderId] = useState<string | null>(initialOrderId ?? null);
  const orderRefs = useRef<Record<string, HTMLDivElement | null>>({});

  useEffect(() => {
    if (profile) {
      loadOrders();
      if (profile.user_type === 'picker') {
        checkPayoutSetup();
      }
    }
  }, [profile]);

  const checkPayoutSetup = async () => {
    if (!profile || profile.user_type !== 'picker') return;

    try {
      // Use the same check as PayoutSetup component - check Stripe Express account status
      const { data, error } = await supabase.functions.invoke(
        'check-express-account-status',
        { body: { picker_id: profile.id } }
      );

      if (error) {
        console.error('Error checking payout setup:', error);
        setPayoutSetupComplete(false);
        return;
      }

      // Account is set up if it's verified (same logic as PayoutSetup)
      setPayoutSetupComplete(data.is_verified === true);
    } catch (error) {
      console.error('Error checking payout setup:', error);
      setPayoutSetupComplete(false);
    }
  };

  const loadOrders = async () => {
    if (!profile) return;

    try {
      const isClient = profile.user_type === 'client';
      let query = supabase
        .from('orders')
        .select(`
          *,
          listing:listings(*),
          client:profiles!orders_client_id_fkey(*),
          picker:profiles!orders_picker_id_fkey(*),
          escrow:payment_escrow(*)
        `);

      if (isClient) {
        query = query.eq('client_id', profile.id);
      } else {
        // For pickers, picker_id references profiles.id directly
        query = query.eq('picker_id', profile.id);
      }

      query = query.order('created_at', { ascending: false });

      const { data, error } = await query;

      if (error) throw error;

      // Check for existing reviews if user is a client
      const ordersWithEscrow = await Promise.all((data || []).map(async (order) => {
        let has_review = false;

        if (isClient) {
          const { data: reviewData } = await supabase
            .from('reviews')
            .select('id')
            .eq('order_id', order.id)
            .eq('client_id', profile.id)
            .maybeSingle();

          has_review = !!reviewData;
        }

        return {
          ...order,
          escrow: Array.isArray(order.escrow) && order.escrow.length > 0 ? order.escrow[0] : undefined,
          has_review
        };
      }));

      setOrders(ordersWithEscrow);

      // Scroll to highlighted order after orders load
      if (initialOrderId) {
        setTimeout(() => {
          const el = orderRefs.current[initialOrderId];
          if (el) {
            el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
          // Clear highlight after 4 seconds
          setTimeout(() => setHighlightedOrderId(null), 4000);
        }, 200);
      }
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const confirmDelivery = async (orderId: string) => {
    if (!profile) return;

    try {
      const order = orders.find(o => o.id === orderId);
      if (!order?.escrow) return;

      // Update order status to 'received'
      const { error: statusError } = await supabase
        .from('orders')
        .update({
          status: 'received',
          goods_confirmed_at: new Date().toISOString()
        })
        .eq('id', orderId);

      if (statusError) throw statusError;

      // Release escrow payment to picker
      const { error } = await supabase.rpc('release_escrow_to_picker', {
        escrow_id: order.escrow.id,
        picker_user_id: order.picker_id
      });

      if (error) throw error;

      toast.showToast('Delivery confirmed! Payment released to picker.', 'success');
      await loadOrders();
    } catch (error) {
      console.error('Error confirming delivery:', error);
      toast.showToast('Failed to confirm delivery', 'error');
    }
  };

  const handleProvideShippingQuote = async (orderId: string) => {
    if (!profile || !shippingCost) return;

    try {
      const cost = parseFloat(shippingCost);
      if (isNaN(cost) || cost < 0) {
        alert('Please enter a valid shipping cost');
        return;
      }

      const { error } = await supabase
        .from('orders')
        .update({
          transportation_cost: cost,
          shipping_quote_status: 'quote_provided',
          quote_provided_at: new Date().toISOString(),
          shipping_notes: shippingNotes || null,
          estimated_weight_kg: estimatedWeight ? parseFloat(estimatedWeight) : null,
        })
        .eq('id', orderId);

      if (error) throw error;

      setProvidingQuoteFor(null);
      setShippingCost('');
      setShippingNotes('');
      setEstimatedWeight('');
      await loadOrders();
    } catch (error) {
      alert('Failed to provide shipping quote. Please try again.');
    }
  };

  const handleAcceptQuote = async (order: OrderWithDetails) => {
    if (!profile || !order.transportation_cost) return;

    try {
      setAcceptingQuote(order.id);

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error('Please log in to continue');
      }

      const productAmount = Number(order.total_price);
      const shippingAmount = Number(order.transportation_cost);
      const totalAmount = productAmount + shippingAmount;

      // Update the order to mark quote as approved (total_price already updated by picker)
      const { error: updateError } = await supabase
        .from('orders')
        .update({
          shipping_quote_status: 'quote_approved'
        })
        .eq('id', order.id);

      if (updateError) {
        throw new Error('Failed to update order: ' + updateError.message);
      }

      // Create the payment intent with split payment amounts
      // Shipping will be paid immediately, product held in escrow
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-payment-intent`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            orderId: order.id,
            amount: totalAmount,
            productAmount: productAmount,
            shippingAmount: shippingAmount,
            currency: 'eur',
          }),
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to create payment intent');
      }

      const paymentData = await response.json();

      setPaymentModalOrder({
        orderId: order.id,
        clientSecret: paymentData.clientSecret,
        amount: totalAmount,
      });

      setAcceptingQuote(null);
    } catch (error: any) {
      setAcceptingQuote(null);

      // Check if error is about picker's payout account
      const errorMessage = error.message || '';
      if (errorMessage.includes('payout account') || errorMessage.includes('Stripe Connect')) {
        alert('Cannot process payment: The picker has not set up their payout account yet. Please contact them to complete their account setup before you can complete this purchase.');
      } else {
        alert('Failed to process quote acceptance: ' + errorMessage);
      }
    }
  };

  const handleCancelQuote = async (orderId: string) => {
    if (!profile) return;

    const confirmCancel = window.confirm(
      'Are you sure you want to cancel this shipping quote? You can request a new quote from the picker if needed.'
    );

    if (!confirmCancel) return;

    setCancelingQuote(orderId);

    try {
      const order = orders.find(o => o.id === orderId);
      if (!order) throw new Error('Order not found');

      // Reset the shipping quote status and transportation cost
      const { error } = await supabase
        .from('orders')
        .update({
          shipping_quote_status: 'pending_quote',
          transportation_cost: null,
          quote_provided_at: null,
          shipping_notes: null,
          estimated_weight_kg: null,
        })
        .eq('id', orderId);

      if (error) throw error;

      toast.addToast('Shipping quote canceled successfully', 'success');
      await loadOrders();
    } catch (error: any) {
      console.error('Error canceling quote:', error);
      toast.addToast('Failed to cancel quote: ' + error.message, 'error');
    } finally {
      setCancelingQuote(null);
    }
  };

  const handlePaymentSuccess = async () => {
    if (!paymentModalOrder) return;

    await supabase
      .from('orders')
      .update({
        payment_status: 'paid',
        status: 'confirmed',
      })
      .eq('id', paymentModalOrder.orderId);

    setPaymentModalOrder(null);
    await loadOrders();
  };

  const handleMarkShipped = async (orderId: string) => {
    if (!profile) return;

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        alert('Please log in to continue');
        return;
      }

      const { data, error } = await supabase.rpc('picker_mark_shipped', {
        p_order_id: orderId,
        p_tracking_number: trackingNumber.trim() || null
      });

      if (error) throw error;

      if (data?.success) {
        // If there's a shipping amount to release, call the payout edge function
        if (data.shipping_amount && data.shipping_amount > 0 && data.escrow_id) {
          fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/process-picker-payout`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${session.access_token}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                escrowId: data.escrow_id,
                pickerId: profile.id,
                releaseType: 'shipping_only'
              }),
            }
          ).catch(err => {
            console.error('Shipping payout processing error (non-blocking):', err);
          });
        }

        setMarkingShipped(null);
        setTrackingNumber('');
        await loadOrders();
        alert('Order marked as shipped! Shipping cost will be paid immediately.');
      } else {
        alert(data?.error || 'Failed to mark as shipped');
      }
    } catch (error: any) {
      alert('Failed to mark as shipped: ' + error.message);
    }
  };

  const handleDispute = async (orderId: string) => {
    if (!profile || !disputeReason.trim()) return;

    try {
      const order = orders.find(o => o.id === orderId);
      if (!order) return;

      const isPicker = profile.user_type === 'picker';
      const againstUser = isPicker ? order.client_id : order.picker_id;

      const { error } = await supabase
        .from('disputes')
        .insert({
          order_id: orderId,
          raised_by: profile.id,
          filed_by: profile.id,
          against_user: againstUser,
          dispute_type: isPicker ? 'other' : 'quality_issue',
          reason: disputeReason,
          description: disputeReason,
          status: 'open',
          evidence_urls: []
        });

      if (error) throw error;

      alert('Dispute filed successfully. Our team will review it shortly.');
      setDisputingOrder(null);
      setDisputeReason('');
      await loadOrders();
    } catch (error) {

      alert('Failed to file dispute. Please try again.');
    }
  };

  const handleUploadPickupVideo = async (orderId: string, file: File) => {
    if (!profile) {
      toast.error('Profile not found. Please refresh the page.');
      return;
    }

    try {
      setUploadingVideo(orderId);

      // Validate file before upload
      if (file.size === 0) {
        throw new Error('Selected file is empty');
      }

      if (file.size > 50 * 1024 * 1024) {
        throw new Error(`Video file is too large (${(file.size / 1024 / 1024).toFixed(2)}MB). Maximum size is 50MB`);
      }

      const allowedTypes = ['video/mp4', 'video/webm', 'video/quicktime'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('Invalid video format. Please use MP4, WebM, or MOV');
      }

      const { data: { session }, error: sessionError } = await supabase.auth.getSession();

      if (sessionError || !session) {
        throw new Error('Your session has expired. Please log in again');
      }

      // Upload video to storage
      const result = await uploadPickupVideo(file, profile.id, orderId);

      // Update order with video URL
      const { data: updateData, error: updateError } = await supabase
        .from('orders')
        .update({
          pickup_video_url: result.url,
          pickup_video_uploaded_at: new Date().toISOString(),
        })
        .eq('id', orderId)
        .select();

      if (updateError) {
        throw new Error('Failed to save video information. Please try again');
      }

      toast.success('Pickup video uploaded successfully!');
      await loadOrders();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to upload video. Please try again';
      toast.error(errorMessage);
    } finally {
      setUploadingVideo(null);
    }
  };

  const updateOrderStatus = async (orderId: string, newStatus: OrderStatus) => {
    if (!profile) return;

    try {
      const updateData: any = {
        status: newStatus,
      };

      // Set timestamps for specific status changes
      if (newStatus === 'shipped' && !orders.find(o => o.id === orderId)?.shipped_at) {
        updateData.shipped_at = new Date().toISOString();
      }
      if (newStatus === 'received') {
        updateData.goods_confirmed_at = new Date().toISOString();
      }
      if (newStatus === 'cancelled') {
        updateData.cancelled_at = new Date().toISOString();
      }

      const { error: updateError } = await supabase
        .from('orders')
        .update(updateData)
        .eq('id', orderId);

      if (updateError) throw updateError;

      await supabase
        .from('order_status_history')
        .insert({
          order_id: orderId,
          status: newStatus,
          notes: `Status changed to ${newStatus}`,
          changed_by: profile.id,
        });

      toast.showToast('Order status updated successfully', 'success');
      await loadOrders();
    } catch (error) {
      console.error('Error updating order status:', error);
      toast.showToast('Failed to update order status', 'error');
    }
  };

  const getStatusIcon = (status: OrderStatus) => {
    switch (status) {
      case 'unpaid':
        return <Clock className="w-5 h-5 text-yellow-600" />;
      case 'paid':
        return <DollarSign className="w-5 h-5 text-blue-600" />;
      case 'accepted':
        return <CheckCircle className="w-5 h-5 text-purple-600" />;
      case 'processing':
        return <Package className="w-5 h-5 text-indigo-600" />;
      case 'shipped':
        return <Truck className="w-5 h-5 text-cyan-600" />;
      case 'received':
        return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'cancelled':
        return <XCircle className="w-5 h-5 text-red-600" />;
      case 'refunded':
        return <RefreshCw className="w-5 h-5 text-orange-600" />;
      default:
        return <Package className="w-5 h-5 text-gray-600" />;
    }
  };

  const filteredOrders = orders.filter(order => {
    if (filter === 'all') return true;

    // For "Action Required" filter
    if (filter === 'action_required') {
      const isCollector = profile?.user_type === 'client' || profile?.user_type === 'collector';

      if (isCollector) {
        // Collectors: Orders needing pay or confirm delivery
        const needsAction = requiresCollectorAction(order.status);
        console.log(`[Collector] Order ${order.id} status: ${order.status}, needs action: ${needsAction}`);
        return needsAction;
      } else {
        // Pickers: Orders needing quote or shipping
        const needsAction = requiresPickerAction(order.status);
        console.log(`[Picker] Order ${order.id} status: ${order.status}, needs action: ${needsAction}`);
        return needsAction;
      }
    }

    // For "Completed" filter
    if (filter === 'completed') {
      return order.status === 'completed';
    }

    // Default: match status directly
    return order.status === filter;
  });

  // Get filter options based on user type
  const filterOptions = profile ? getFilterOptions(profile.user_type as 'collector' | 'picker') : [];

  // Debug logging
  console.log('=== ORDER FILTER DEBUG ===');
  console.log('User type:', profile?.user_type);
  console.log('Current filter:', filter);
  console.log('Total orders:', orders.length);
  console.log('Order statuses:', orders.map(o => `${o.id}: ${o.status}`));
  console.log('Filtered orders:', filteredOrders.length);
  console.log('=========================');

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Loading orders...</div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">
          {profile?.user_type === 'client' ? 'My Orders' : 'Orders to Fulfill'}
        </h1>
        <p className="text-gray-600 mt-1">
          {profile?.user_type === 'client'
            ? 'Track your souvenir orders'
            : 'Manage customer orders'}
        </p>
      </div>

      {profile?.user_type === 'picker' && !payoutSetupComplete && (
        <div className="bg-red-50 border-2 border-red-300 rounded-lg p-5 mb-6">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-6 h-6 text-red-600 flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-base font-bold text-red-900 mb-2">
                Bank Account Setup Required
              </p>
              <p className="text-sm text-red-800 mb-3">
                You cannot receive payments until you set up your bank account. Collectors will see an error if they try to pay for your listings.
              </p>
              <button
                onClick={() => onViewChange?.('profile')}
                className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors font-medium text-sm inline-flex items-center gap-2"
              >
                <DollarSign className="w-4 h-4" />
                Set Up Bank Account Now
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="mb-6 flex flex-wrap gap-2">
        {filterOptions.map((option) => (
          <button
            key={option.value}
            onClick={() => setFilter(option.value)}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              filter === option.value
                ? 'bg-blue-600 text-white shadow-md'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>

      <div className="space-y-4">
        {filteredOrders.length === 0 ? (
          <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
            <Package className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 text-lg">No orders found</p>
          </div>
        ) : (
          filteredOrders.map((order) => (
            <div
              key={order.id}
              ref={(el) => { orderRefs.current[order.id] = el; }}
              className={`rounded-2xl shadow-lg p-6 hover:shadow-xl transition-all duration-500 ${
                highlightedOrderId === order.id
                  ? 'bg-blue-50 border-2 border-blue-400 shadow-blue-200'
                  : 'bg-white'
              }`}
            >
              <div className="flex gap-6">
                {order.listing?.images[0] && (
                  <img
                    src={order.listing.images[0]}
                    alt={order.listing.title}
                    className="w-32 h-32 object-cover rounded-lg"
                  />
                )}
                <div className="flex-1">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <h3 className="text-xl font-bold text-gray-900">
                        {order.listing?.title}
                      </h3>
                      <p className="text-sm text-gray-500 mt-1">
                        Order #{order.id.slice(0, 8)}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      {getStatusIcon(order.status as OrderStatus)}
                      <span
                        className={`px-3 py-1 rounded-full text-sm font-medium border ${getStatusColor(
                          order.status as OrderStatus
                        )}`}
                      >
                        {profile && getStatusDisplay(order.status as OrderStatus, profile.user_type as 'collector' | 'picker', order.payment_status)}
                      </span>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4 mb-4">
                    <div className="flex items-center gap-2 text-gray-600">
                      <User className="w-4 h-4" />
                      {profile?.user_type === 'client' ? (
                        <span>Picker: {order.picker?.full_name}</span>
                      ) : (
                        <span>Client: {order.client?.full_name}</span>
                      )}
                    </div>
                    <div className="flex items-center gap-2 text-gray-600">
                      <Package className="w-4 h-4" />
                      <span>Quantity: {order.quantity}</span>
                    </div>
                    <div className="flex items-center gap-2 text-gray-600">
                      <DollarSign className="w-4 h-4" />
                      <span className="font-semibold">${order.total_price.toFixed(2)}</span>
                    </div>
                    <div className="flex items-center gap-2 text-gray-600">
                      <Clock className="w-4 h-4" />
                      <span>{new Date(order.created_at).toLocaleDateString()}</span>
                    </div>
                  </div>

                  {order.delivery_address && (
                    <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                      <div className="flex items-start gap-2 text-sm">
                        <MapPin className="w-4 h-4 text-gray-500 mt-0.5" />
                        <div className="flex-1">
                          <p className="font-medium text-gray-700">Delivery Address:</p>
                          <p className="text-gray-600">{order.delivery_address}</p>
                          {order.delivery_instructions && (
                            <p className="text-gray-500 mt-1 text-xs">
                              Instructions: {order.delivery_instructions}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Shipping Quote Section */}
                  {order.shipping_quote_status === 'quote_requested' && profile?.user_type === 'picker' && (
                    <div className="mb-4 p-4 bg-amber-50 border-2 border-amber-200 rounded-lg">
                      <div className="flex items-start gap-3 mb-3">
                        <DollarSign className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h4 className="font-semibold text-gray-900 mb-1">Shipping Quote Requested</h4>
                          <p className="text-sm text-gray-600 mb-3">
                            The collector has requested a shipping quote. Check the delivery address below, get a quote from your preferred courier service (DHL, UPS, FedEx, local post, etc.), and provide the actual shipping cost for this specific delivery.
                          </p>

                          {providingQuoteFor === order.id ? (
                            <div className="space-y-3 bg-white p-4 rounded-lg">
                              <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                  Shipping Cost (€)*
                                </label>
                                <input
                                  type="number"
                                  step="0.01"
                                  min="0"
                                  value={shippingCost}
                                  onChange={(e) => setShippingCost(e.target.value)}
                                  placeholder="0.00"
                                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                                  required
                                />
                              </div>

                              <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                  Estimated Weight (kg)
                                </label>
                                <input
                                  type="number"
                                  step="0.1"
                                  min="0"
                                  value={estimatedWeight}
                                  onChange={(e) => setEstimatedWeight(e.target.value)}
                                  placeholder="Package weight"
                                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                                />
                              </div>

                              <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                  Shipping Notes
                                </label>
                                <textarea
                                  value={shippingNotes}
                                  onChange={(e) => setShippingNotes(e.target.value)}
                                  placeholder="Include courier service, estimated delivery time, tracking info, etc."
                                  rows={3}
                                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                                />
                              </div>

                              <div className="flex gap-2">
                                <button
                                  onClick={() => handleProvideShippingQuote(order.id)}
                                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
                                >
                                  Submit Quote
                                </button>
                                <button
                                  onClick={() => {
                                    setProvidingQuoteFor(null);
                                    setShippingCost('');
                                    setShippingNotes('');
                                    setEstimatedWeight('');
                                  }}
                                  className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition-colors"
                                >
                                  Cancel
                                </button>
                              </div>
                            </div>
                          ) : (
                            <button
                              onClick={() => setProvidingQuoteFor(order.id)}
                              className="px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors text-sm"
                            >
                              Provide Shipping Quote
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  {(order.shipping_quote_status === 'quote_provided' || order.shipping_quote_status === 'quote_approved') && order.transportation_cost !== null && (
                    <div className="mb-4 p-4 bg-blue-50 border-2 border-blue-200 rounded-lg">
                      <div className="flex items-start gap-3">
                        <CheckCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h4 className="font-semibold text-gray-900 mb-1">
                            {order.shipping_quote_status === 'quote_approved' ? 'Quote Accepted - Complete Payment' : 'Shipping Quote Provided'}
                          </h4>
                          <div className="space-y-1 text-sm">
                            <p className="text-gray-700">
                              <span className="font-medium">Shipping Cost:</span> €{order.transportation_cost.toFixed(2)}
                            </p>
                            {order.estimated_weight_kg && (
                              <p className="text-gray-700">
                                <span className="font-medium">Package Weight:</span> {order.estimated_weight_kg} kg
                              </p>
                            )}
                            {order.shipping_notes && (
                              <p className="text-gray-700 mt-2">
                                <span className="font-medium">Notes:</span> {order.shipping_notes}
                              </p>
                            )}
                          </div>
                          {profile?.user_type === 'client' && order.payment_status !== 'paid' && (
                            <div className="mt-4 p-4 bg-white border border-blue-300 rounded-lg">
                              <div className="flex items-center justify-between mb-2">
                                <div>
                                  <p className="font-semibold text-gray-900">Payment Breakdown</p>
                                  {order.shipping_quote_status === 'quote_provided' && (
                                    <div className="mt-2 space-y-1 text-sm text-gray-700">
                                      <div className="flex justify-between">
                                        <span>Item Price (held in escrow):</span>
                                        <span className="font-medium">€{(Number(order.total_price) - Number(order.transportation_cost)).toFixed(2)}</span>
                                      </div>
                                      <div className="flex justify-between">
                                        <span>Shipping (paid immediately):</span>
                                        <span className="font-medium">€{Number(order.transportation_cost).toFixed(2)}</span>
                                      </div>
                                      <div className="border-t border-gray-300 pt-1 mt-1"></div>
                                    </div>
                                  )}
                                  <p className="text-2xl font-bold text-blue-600 mt-2">
                                    Total: €{Number(order.total_price).toFixed(2)}
                                  </p>
                                  <p className="text-xs text-gray-500 mt-1">
                                    Product funds released after delivery confirmation
                                  </p>
                                </div>
                              </div>
                              <div className="flex gap-3 mt-3">
                                {order.shipping_quote_status === 'quote_provided' && (
                                  <button
                                    onClick={() => handleCancelQuote(order.id)}
                                    disabled={cancelingQuote === order.id || acceptingQuote === order.id}
                                    className="flex-1 bg-red-600 text-white py-3 rounded-lg font-semibold hover:bg-red-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                                  >
                                    {cancelingQuote === order.id ? (
                                      <>
                                        <Loader className="w-5 h-5 animate-spin" />
                                        Canceling...
                                      </>
                                    ) : (
                                      <>
                                        <XCircle className="w-5 h-5" />
                                        Cancel Quote
                                      </>
                                    )}
                                  </button>
                                )}
                                <button
                                  onClick={() => handleAcceptQuote(order)}
                                  disabled={acceptingQuote === order.id || cancelingQuote === order.id}
                                  className={`${order.shipping_quote_status === 'quote_provided' ? 'flex-1' : 'w-full'} bg-green-600 text-white py-3 rounded-lg font-semibold hover:bg-green-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2`}
                                >
                                  {acceptingQuote === order.id ? (
                                    <>
                                      <Loader className="w-5 h-5 animate-spin" />
                                      Processing...
                                    </>
                                  ) : (
                                    <>
                                      <CreditCard className="w-5 h-5" />
                                      {order.shipping_quote_status === 'quote_approved' ? 'Complete Payment' : 'Accept Quote & Pay Now'}
                                    </>
                                  )}
                                </button>
                              </div>
                            </div>
                          )}
                          {profile?.user_type === 'client' && order.payment_status === 'paid' && (
                            <div className="mt-3 space-y-2">
                              <p className="text-sm text-green-700 p-2 bg-green-50 rounded border border-green-200">
                                <CheckCircle className="w-4 h-4 inline mr-1" />
                                Payment received. Picker will process your order soon!
                              </p>
                              {order.shipping_paid && order.transportation_cost && (
                                <p className="text-sm text-blue-700 p-2 bg-blue-50 rounded border border-blue-200">
                                  <DollarSign className="w-4 h-4 inline mr-1" />
                                  Shipping funds (€{order.transportation_cost.toFixed(2)}) transferred to picker
                                  {order.shipping_paid_at && (
                                    <span className="text-xs text-blue-600 ml-1">
                                      on {new Date(order.shipping_paid_at).toLocaleDateString()}
                                    </span>
                                  )}
                                </p>
                              )}
                            </div>
                          )}
                          {profile?.user_type === 'picker' && order.shipping_paid && order.transportation_cost && (
                            <p className="text-sm text-green-700 mt-3 p-2 bg-green-50 rounded border border-green-200">
                              <CheckCircle className="w-4 h-4 inline mr-1" />
                              Shipping funds (€{order.transportation_cost.toFixed(2)}) received
                              {order.shipping_paid_at && (
                                <span className="text-xs text-green-600 ml-1">
                                  on {new Date(order.shipping_paid_at).toLocaleDateString()}
                                </span>
                              )}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  {order.notes && (
                    <p className="text-sm text-gray-600 mb-4 p-3 bg-gray-50 rounded-lg">
                      <span className="font-medium">Notes:</span> {order.notes}
                    </p>
                  )}

                  {order.pickup_video_url && (
                    <div className="mb-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg border-2 border-blue-200">
                      <div className="flex items-center gap-2 mb-3">
                        <Video className="w-5 h-5 text-blue-600" />
                        <h4 className="font-semibold text-gray-900">Pickup Moment</h4>
                        <span className="text-xs text-gray-500 ml-auto">
                          {new Date(order.pickup_video_uploaded_at || '').toLocaleDateString()}
                        </span>
                      </div>
                      <video
                        src={order.pickup_video_url}
                        controls
                        preload="metadata"
                        playsInline
                        controlsList="nodownload"
                        className="w-full rounded-lg shadow-lg bg-black"
                        style={{ maxHeight: '300px' }}
                        onError={(e) => {

                        }}
                        onLoadStart={() => {

                        }}
                        onLoadedMetadata={(e) => {

                        }}
                      >
                        <source src={order.pickup_video_url} type="video/mp4" />
                        <source src={order.pickup_video_url} type="video/webm" />
                        <source src={order.pickup_video_url} type="video/quicktime" />
                        Your browser does not support the video tag.
                      </video>
                      <div className="flex items-center justify-between mt-3 flex-wrap gap-3">
                        <p className="text-sm text-gray-600">
                          {profile?.user_type === 'picker'
                            ? 'Your pickup video has been shared with the collector'
                            : 'Watch the moment your souvenir was picked up!'}
                        </p>
                        <a
                          href={order.pickup_video_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors shadow-md text-sm whitespace-nowrap"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                          </svg>
                          Open in New Tab
                        </a>
                      </div>
                    </div>
                  )}

                  {order.escrow && (
                    <div className="mb-4">
                      <EscrowStatusDisplay
                        status={order.escrow.status}
                        amount={order.escrow.amount}
                        heldAt={order.escrow.held_at}
                        releasedAt={order.escrow.released_at}
                        notes={order.escrow.notes}
                        orderStatus={order.status}
                        deliveredAt={order.delivered_at}
                      />
                    </div>
                  )}

                  {profile?.user_type === 'client' && (
                    <div className="mb-4">
                      <OrderConfirmation
                        orderId={order.id}
                        orderStatus={order.status}
                        goodsConfirmed={order.goods_confirmed || false}
                        pickerName={order.picker?.full_name || 'the picker'}
                        onConfirmed={loadOrders}
                      />
                    </div>
                  )}

                  <div className="flex flex-wrap gap-3">
                    {profile?.user_type === 'picker' && ['processing', 'shipped'].includes(order.status) && !order.pickup_video_url && (
                      <>
                        <input
                          type="file"
                          accept="video/mp4,video/webm,video/quicktime"
                          className="hidden"
                          id={`video-upload-${order.id}`}
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                              handleUploadPickupVideo(order.id, file);
                              e.target.value = '';
                            }
                          }}
                        />
                        <button
                          onClick={() => {
                            const input = document.getElementById(`video-upload-${order.id}`) as HTMLInputElement;
                            input?.click();
                          }}
                          disabled={uploadingVideo === order.id}
                          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg font-medium hover:from-blue-700 hover:to-purple-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg"
                        >
                          {uploadingVideo === order.id ? (
                            <>
                              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                              Uploading...
                            </>
                          ) : (
                            <>
                              <Upload className="w-4 h-4" />
                              Share Pickup Video
                            </>
                          )}
                        </button>
                      </>
                    )}

                    {profile?.user_type === 'picker' && order.status === 'paid' && (
                      <>
                        <button
                          onClick={() => updateOrderStatus(order.id, 'processing')}
                          className="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
                        >
                          ✓ Accept & Start Order
                        </button>
                        <button
                          onClick={() => updateOrderStatus(order.id, 'cancelled')}
                          className="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
                        >
                          ✕ Decline Order
                        </button>
                      </>
                    )}

                    {profile?.user_type === 'picker' && order.status === 'processing' && !order.shipped_at && (
                      <>
                        {markingShipped === order.id ? (
                          <div className="flex gap-2 w-full">
                            <input
                              type="text"
                              value={trackingNumber}
                              onChange={(e) => setTrackingNumber(e.target.value)}
                              placeholder="Tracking number (optional)"
                              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                            />
                            <button
                              onClick={() => handleMarkShipped(order.id)}
                              className="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors whitespace-nowrap"
                            >
                              Confirm Shipped
                            </button>
                            <button
                              onClick={() => {
                                setMarkingShipped(null);
                                setTrackingNumber('');
                              }}
                              className="px-4 py-2 bg-gray-500 text-white rounded-lg font-medium hover:bg-gray-600 transition-colors"
                            >
                              Cancel
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => setMarkingShipped(order.id)}
                            className="px-4 py-2 bg-gradient-to-r from-green-600 to-blue-600 text-white rounded-lg font-medium hover:from-green-700 hover:to-blue-700 transition-all shadow-md"
                          >
                            📦 Mark as Shipped
                          </button>
                        )}
                      </>
                    )}

                    {profile?.user_type === 'picker' && order.shipped_at && (
                      <div className="w-full p-3 bg-green-50 border border-green-200 rounded-lg">
                        <div className="flex items-center gap-2 text-green-700 text-sm">
                          <CheckCircle className="w-4 h-4" />
                          <span className="font-medium">
                            Shipped on {new Date(order.shipped_at).toLocaleDateString()}
                          </span>
                        </div>
                        {order.tracking_number && (
                          <div className="mt-1 text-xs text-green-600">
                            Tracking: {order.tracking_number}
                          </div>
                        )}
                        {order.auto_release_at && !order.goods_confirmed && (
                          <div className="mt-2 text-xs text-gray-600">
                            Auto-release: {new Date(order.auto_release_at).toLocaleDateString()}
                          </div>
                        )}
                      </div>
                    )}

                    {profile?.user_type === 'picker' && ['processing', 'shipped'].includes(order.status) && (
                      <button
                        onClick={() => setDisputingOrder(order.id)}
                        className="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
                      >
                        File Dispute
                      </button>
                    )}

                    {profile?.user_type === 'client' && order.status === 'shipped' && (
                      <>
                        {order.escrow?.status === 'held' && (
                          <button
                            onClick={() => confirmDelivery(order.id)}
                            className="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
                          >
                            ✓ Confirm Delivery
                          </button>
                        )}
                        <button
                          onClick={() => setDisputingOrder(order.id)}
                          className="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
                        >
                          ⚠ File Dispute
                        </button>
                      </>
                    )}

                    {profile?.user_type === 'client' && order.status === 'processing' && (
                      <button
                        onClick={() => setDisputingOrder(order.id)}
                        className="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
                      >
                        ⚠ File Dispute
                      </button>
                    )}

                    {profile?.user_type === 'client' && order.status === 'received' && (
                      order.has_review ? (
                        <div className="px-4 py-2 bg-green-100 text-green-700 rounded-lg font-medium flex items-center gap-2">
                          <CheckCircle className="w-4 h-4" />
                          Review Submitted
                        </div>
                      ) : (
                        <button
                          onClick={() => setReviewingOrder(order)}
                          className="px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
                        >
                          Write Review
                        </button>
                      )
                    )}

                    {profile?.user_type === 'client' && order.status === 'unpaid' && order.payment_status === 'pending' && (
                      <button
                        onClick={async () => {
                          if (confirm('Are you sure you want to cancel this order?')) {
                            try {
                              await supabase.from('orders').delete().eq('id', order.id);
                              await loadOrders();
                            } catch (error) {
                              alert('Failed to cancel order');
                            }
                          }
                        }}
                        className="px-4 py-2 bg-gray-600 text-white rounded-lg font-medium hover:bg-gray-700 transition-colors"
                      >
                        Cancel Order
                      </button>
                    )}
                  </div>
                </div>

                {disputingOrder === order.id && (
                  <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg">
                    <div className="flex items-start gap-2 mb-3">
                      <AlertTriangle className="w-5 h-5 text-red-600 mt-0.5" />
                      <div className="flex-1">
                        <h4 className="font-semibold text-red-900">File Dispute</h4>
                        <p className="text-sm text-red-700 mt-1">
                          {profile?.user_type === 'picker'
                            ? 'Please describe the issue with this order. Our support team will review and help resolve the matter.'
                            : 'Please provide a reason for the dispute. Our support team will review your case.'}
                        </p>
                      </div>
                    </div>
                    <textarea
                      value={disputeReason}
                      onChange={(e) => setDisputeReason(e.target.value)}
                      placeholder={profile?.user_type === 'picker'
                        ? 'Describe the issue (e.g., client communication problems, unreasonable requests, payment concerns)...'
                        : 'Explain the issue with this order (e.g., item not as described, damaged, not received)...'}
                      rows={4}
                      className="w-full px-3 py-2 border border-red-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent mb-3"
                    />
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleDispute(order.id)}
                        disabled={!disputeReason.trim()}
                        className="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        Submit Dispute
                      </button>
                      <button
                        onClick={() => {
                          setDisputingOrder(null);
                          setDisputeReason('');
                        }}
                        className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      {reviewingOrder && (
        <ReviewForm
          orderId={reviewingOrder.id}
          pickerId={reviewingOrder.picker_id}
          listingId={reviewingOrder.listing_id || undefined}
          onClose={() => setReviewingOrder(null)}
          onReviewSubmitted={() => {
            setReviewingOrder(null);
            toast.success('Review submitted successfully! The picker will be notified.');
            loadOrders();
          }}
        />
      )}

      {paymentModalOrder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4">
              <h2 className="text-2xl font-bold text-gray-900">Complete Your Payment</h2>
              <p className="text-gray-600 mt-1">
                Total Amount: <span className="font-bold text-blue-600">€{paymentModalOrder.amount.toFixed(2)}</span>
              </p>
            </div>
            <div className="p-6">
              <CartPaymentModal
                orderId={paymentModalOrder.orderId}
                clientSecret={paymentModalOrder.clientSecret}
                amount={paymentModalOrder.amount}
                totalOrders={1}
                currentOrderNumber={1}
                onSuccess={handlePaymentSuccess}
                onCancel={() => setPaymentModalOrder(null)}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
