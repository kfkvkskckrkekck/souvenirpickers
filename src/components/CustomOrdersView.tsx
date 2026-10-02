import { useState, useEffect } from 'react';
import { Package, DollarSign, Clock, CheckCircle, XCircle, Truck as TruckIcon, MessageCircle, Info } from 'lucide-react';
import { supabase, Profile, CollectorPaymentMethod } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

type CustomOrder = {
  id: string;
  picker_id: string;
  client_id: string;
  title: string;
  description: string;
  base_price: number | null;
  transportation_cost: number | null;
  total_price: number | null;
  quantity: number | null;
  images: string[];
  delivery_address: string | null;
  notes: string | null;
  status: string;
  expires_at: string;
  accepted_at: string | null;
  order_id: string | null;
  created_at: string;
  picker?: Profile;
  client?: Profile;
};

export function CustomOrdersView() {
  const { user, profile } = useAuth();
  const [customOrders, setCustomOrders] = useState<CustomOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedOrder, setSelectedOrder] = useState<CustomOrder | null>(null);
  const [accepting, setAccepting] = useState(false);
  const [paymentMethods, setPaymentMethods] = useState<CollectorPaymentMethod[]>([]);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<string>('');

  useEffect(() => {
    if (user) {
      loadCustomOrders();
      if (profile?.user_type === 'client') {
        loadPaymentMethods();
      }
    }
  }, [user, profile]);

  const loadCustomOrders = async () => {
    try {
      let query = supabase
        .from('custom_orders')
        .select('*')
        .order('created_at', { ascending: false });

      if (profile?.user_type === 'picker') {
        // For pickers, we need to join through picker_profiles to match user_id
        const { data: pickerProfile } = await supabase
          .from('picker_profiles')
          .select('id')
          .eq('user_id', user?.id)
          .maybeSingle();

        if (pickerProfile) {
          query = query.eq('picker_id', pickerProfile.id);
        }
      } else {
        // For collectors, client_id directly references profiles.id
        query = query.eq('client_id', profile?.id);
      }

      const { data: orders, error } = await query;

      if (error) throw error;

      // Fetch related picker and client profiles separately
      if (orders && orders.length > 0) {
        const pickerIds = [...new Set(orders.map(o => o.picker_id))];
        const clientIds = [...new Set(orders.map(o => o.client_id))];

        // Fetch picker profiles
        const { data: pickerProfiles } = await supabase
          .from('picker_profiles')
          .select('id, user_id, profiles!picker_profiles_user_id_fkey(*)')
          .in('id', pickerIds);

        // Fetch client profiles
        const { data: clientProfiles } = await supabase
          .from('profiles')
          .select('*')
          .in('id', clientIds);

        // Map profiles to orders
        const ordersWithProfiles = orders.map(order => ({
          ...order,
          picker: pickerProfiles?.find(p => p.id === order.picker_id)?.profiles,
          client: clientProfiles?.find(c => c.id === order.client_id)
        }));

        setCustomOrders(ordersWithProfiles);
      } else {
        setCustomOrders([]);
      }
    } catch (error) {
      console.error('Error loading custom orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadPaymentMethods = async () => {
    try {
      const { data, error } = await supabase
        .from('collector_payment_methods')
        .select('*')
        .eq('client_id', user?.id)
        .order('is_default', { ascending: false });

      if (error) throw error;
      setPaymentMethods(data || []);

      const defaultMethod = data?.find(m => m.is_default);
      if (defaultMethod) {
        setSelectedPaymentMethod(defaultMethod.id);
      }
    } catch (error) {

    }
  };

  const handleAcceptOrder = async (order: CustomOrder) => {
    if (!selectedPaymentMethod) {
      alert('Please select a payment method');
      return;
    }

    setAccepting(true);
    try {
      const { data: newOrder, error: orderError } = await supabase
        .from('orders')
        .insert({
          client_id: order.client_id,
          picker_id: order.picker_id,
          listing_id: null,
          quantity: order.quantity || 1,
          total_price: (order.total_price || 0) * (order.quantity || 1),
          delivery_address: order.delivery_address,
          notes: order.notes,
          status: 'pending',
          payment_status: 'pending',
        })
        .select()
        .single();

      if (orderError) throw orderError;

      const { error: updateError } = await supabase
        .from('custom_orders')
        .update({
          status: 'accepted',
          accepted_at: new Date().toISOString(),
          order_id: newOrder.id,
        })
        .eq('id', order.id);

      if (updateError) throw updateError;

      await supabase
        .from('order_status_history')
        .insert({
          order_id: newOrder.id,
          status: 'pending',
          notes: 'Order created from custom order',
          changed_by: user!.id,
        });

      setSelectedOrder(null);
      loadCustomOrders();
      alert('Custom order accepted! Payment will be processed.');
    } catch (error: any) {

      alert('Failed to accept order: ' + error.message);
    } finally {
      setAccepting(false);
    }
  };

  const handleRejectOrder = async (orderId: string) => {
    try {
      const { error } = await supabase
        .from('custom_orders')
        .update({ status: 'rejected' })
        .eq('id', orderId);

      if (error) throw error;

      setSelectedOrder(null);
      loadCustomOrders();
    } catch (error) {

      alert('Failed to reject order');
    }
  };

  const getStatusBadge = (status: string) => {
    const badges = {
      open: { color: 'bg-orange-100 text-orange-800', text: 'Action Required' },
      pending: { color: 'bg-yellow-100 text-yellow-800', text: 'Awaiting Response' },
      accepted: { color: 'bg-green-100 text-green-800', text: 'Accepted' },
      rejected: { color: 'bg-red-100 text-red-800', text: 'Rejected' },
      expired: { color: 'bg-gray-100 text-gray-800', text: 'Expired' },
      completed: { color: 'bg-blue-100 text-blue-800', text: 'Completed' },
    };
    const badge = badges[status as keyof typeof badges] || badges.pending;
    return (
      <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${badge.color}`}>
        {badge.text}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading custom orders..." />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Custom Orders</h1>
        <p className="text-gray-600 mt-1">
          {profile?.user_type === 'picker'
            ? 'Custom orders you have sent to collectors'
            : 'Custom order offers from pickers'}
        </p>
      </div>

      <div className="mb-8 bg-gradient-to-r from-blue-50 to-green-50 rounded-2xl p-6 border-2 border-blue-200">
        <div className="flex items-start gap-4">
          <div className="bg-blue-600 p-3 rounded-lg flex-shrink-0">
            <Info className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-gray-900 mb-2">
              {profile?.user_type === 'picker'
                ? 'How Custom Orders Work for Pickers'
                : 'About Custom Orders'}
            </h3>
            {profile?.user_type === 'picker' ? (
              <div className="space-y-3 text-gray-700">
                <p className="flex items-start gap-2">
                  <MessageCircle className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Create custom orders while chatting:</strong> When messaging with collectors, click the green "Custom Order" button to create personalized offers based on their specific requests and demands.
                  </span>
                </p>
                <p className="flex items-start gap-2">
                  <Package className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Tailored to their needs:</strong> Custom orders allow you to offer items that aren't in your regular listings, set custom prices, and include transportation costs for unique collector demands.
                  </span>
                </p>
                <p className="flex items-start gap-2">
                  <Clock className="w-5 h-5 text-orange-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Time-limited offers:</strong> Custom orders expire after 48 hours, creating urgency for collectors to accept your personalized offer.
                  </span>
                </p>
              </div>
            ) : (
              <div className="space-y-3 text-gray-700">
                <p>
                  Custom orders are personalized offers created by pickers based on your specific requests during chat conversations. These are unique items or services tailored to your exact needs.
                </p>
                <p className="flex items-start gap-2">
                  <CheckCircle className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span>
                    Review each custom order carefully and accept within 48 hours before it expires.
                  </span>
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      {customOrders.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
          <Package className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-500 text-lg">No custom orders yet</p>
          <p className="text-gray-400 text-sm mt-2">
            {profile?.user_type === 'picker'
              ? 'Send custom order offers to collectors through messages'
              : 'Custom orders from pickers will appear here'}
          </p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {customOrders.map((order) => (
            <div
              key={order.id}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow"
            >
              {order.images.length > 0 && (
                <img
                  src={order.images[0]}
                  alt={order.title}
                  className="w-full h-48 object-cover"
                />
              )}

              <div className="p-6">
                <div className="flex items-start justify-between mb-3">
                  <h3 className="text-xl font-bold text-gray-900 flex-1">{order.title}</h3>
                  {getStatusBadge(order.status)}
                </div>

                <p className="text-gray-600 mb-4 line-clamp-3">{order.description}</p>

                {profile?.user_type === 'client' && order.picker && (
                  <p className="text-sm text-gray-600 mb-3">
                    From: <span className="font-medium">{order.picker.full_name}</span>
                  </p>
                )}

                <div className="space-y-2 mb-4 text-sm">
                  <div className="flex justify-between text-gray-700">
                    <span>Item price:</span>
                    <span>€{(order.base_price || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-gray-700">
                    <span>
                      <TruckIcon className="w-4 h-4 inline mr-1" />
                      Transportation:
                    </span>
                    <span>€{(order.transportation_cost || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-gray-700">
                    <span>Quantity:</span>
                    <span>×{order.quantity || 1}</span>
                  </div>
                  <div className="border-t border-gray-200 pt-2 flex justify-between font-bold text-lg">
                    <span>Total:</span>
                    <span className="text-blue-600">€{((order.total_price || 0) * (order.quantity || 1)).toFixed(2)}</span>
                  </div>
                </div>

                <div className="flex items-center gap-2 text-sm text-gray-500 mb-4">
                  <Clock className="w-4 h-4" />
                  <span>
                    Expires: {new Date(order.expires_at).toLocaleDateString()}
                  </span>
                </div>

                {profile?.user_type === 'client' && (order.status === 'pending' || order.status === 'open') && (
                  <button
                    onClick={() => setSelectedOrder(order)}
                    className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
                  >
                    Review & Accept
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedOrder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
              <h2 className="text-2xl font-bold text-gray-900">Review Custom Order</h2>
              <button
                onClick={() => setSelectedOrder(null)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <XCircle className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              <div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">{selectedOrder.title}</h3>
                <p className="text-gray-600">{selectedOrder.description}</p>
              </div>

              {selectedOrder.images.length > 0 && (
                <div className="grid grid-cols-3 gap-3">
                  {selectedOrder.images.map((img, idx) => (
                    <img
                      key={idx}
                      src={img}
                      alt={`${selectedOrder.title} ${idx + 1}`}
                      className="w-full h-32 object-cover rounded-lg"
                    />
                  ))}
                </div>
              )}

              <div className="bg-blue-50 rounded-xl p-4">
                <h4 className="font-semibold text-gray-900 mb-3">Price Breakdown</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Base item price:</span>
                    <span>€{(selectedOrder.base_price || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Transportation cost:</span>
                    <span>€{(selectedOrder.transportation_cost || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Unit price:</span>
                    <span className="font-medium">€{(selectedOrder.total_price || 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Quantity:</span>
                    <span>×{selectedOrder.quantity || 1}</span>
                  </div>
                  <div className="border-t border-blue-200 pt-2 flex justify-between text-lg font-bold">
                    <span>Total:</span>
                    <span className="text-blue-600">
                      €{((selectedOrder.total_price || 0) * (selectedOrder.quantity || 1)).toFixed(2)}
                    </span>
                  </div>
                </div>
              </div>

              {selectedOrder.delivery_address && (
                <div>
                  <h4 className="font-semibold text-gray-900 mb-2">Suggested Delivery Address</h4>
                  <p className="text-gray-600">{selectedOrder.delivery_address}</p>
                </div>
              )}

              {selectedOrder.notes && (
                <div>
                  <h4 className="font-semibold text-gray-900 mb-2">Additional Notes</h4>
                  <p className="text-gray-600">{selectedOrder.notes}</p>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Payment Method
                </label>
                {paymentMethods.length === 0 ? (
                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-sm text-yellow-800">
                    Please add a payment method in your profile settings before accepting orders.
                  </div>
                ) : (
                  <select
                    value={selectedPaymentMethod}
                    onChange={(e) => setSelectedPaymentMethod(e.target.value)}
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  >
                    <option value="">Select a payment method</option>
                    {paymentMethods.map((method) => (
                      <option key={method.id} value={method.id}>
                        {method.card_brand} •••• {method.last_four} - {method.cardholder_name}
                      </option>
                    ))}
                  </select>
                )}
              </div>

              <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
                <p className="text-sm text-blue-800">
                  <strong>Escrow Protection:</strong> Your payment will be held securely until you confirm delivery.
                </p>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => handleRejectOrder(selectedOrder.id)}
                  className="flex-1 px-6 py-3 border border-red-300 text-red-700 rounded-lg font-medium hover:bg-red-50 transition-colors"
                >
                  Reject
                </button>
                <button
                  onClick={() => handleAcceptOrder(selectedOrder)}
                  disabled={accepting || !selectedPaymentMethod}
                  className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  <CheckCircle className="w-5 h-5" />
                  {accepting ? 'Accepting...' : 'Accept & Pay'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
