import { useState, useEffect } from 'react';
import { ShoppingCart, Trash2, Plus, Minus, Loader, CheckCircle, ArrowRight, Lock, MapPin, Package, AlertCircle, ChevronDown } from 'lucide-react';
import { FunctionsHttpError } from '@supabase/supabase-js';
import { useAuth } from '../contexts/AuthContext';
import { supabase, CartItem, Listing } from '../lib/supabase';
import { COUNTRIES, toCountryCode } from '../lib/countries';
import { CartMultiOrderPayment } from './CartMultiOrderPayment';
import SouvenirLoader from './SouvenirLoader';

type CartItemWithListing = CartItem & {
  listing: Listing;
};

type CartViewProps = {
  onViewChange?: (view: string) => void;
};

type ShippingRate = {
  id: number;
  name: string;
  carrier: string;
  min_days: number;
  max_days: number;
  price: number;
};

type PendingPayment = {
  orderId: string;
  amount: number;
  title: string;
};

export function CartView({ onViewChange }: CartViewProps = {}) {
  const { user, profile } = useAuth();
  const [cartItems, setCartItems] = useState<CartItemWithListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [deliveryInstructions, setDeliveryInstructions] = useState('');
  const [showCheckout, setShowCheckout] = useState(false);
  const [message, setMessage] = useState('');
  const [orderSuccess, setOrderSuccess] = useState(false);
  const [deliveryStreet, setDeliveryStreet] = useState('');
  const [deliveryBuilding, setDeliveryBuilding] = useState('');
  const [deliveryApartment, setDeliveryApartment] = useState('');
  const [deliveryCity, setDeliveryCity] = useState('');
  const [deliveryPostalCode, setDeliveryPostalCode] = useState('');
  const [deliveryCountry, setDeliveryCountry] = useState('');
  const [referralDiscount, setReferralDiscount] = useState(0);

  const [fetchingRates, setFetchingRates] = useState(false);
  const [ratesFetched, setRatesFetched] = useState(false);
  const [shippingRatesByItem, setShippingRatesByItem] = useState<Record<string, ShippingRate[]>>({});
  const [selectedRateByItem, setSelectedRateByItem] = useState<Record<string, ShippingRate>>({});

  const [inPaymentFlow, setInPaymentFlow] = useState(false);
  const [pendingPayments, setPendingPayments] = useState<PendingPayment[]>([]);
  const [openRateItemId, setOpenRateItemId] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      loadCart();
    }
  }, [user]);

  const loadCart = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('cart_items')
        .select('*, listing:listings(*)')
        .eq('client_id', user?.id);

      if (error) throw error;
      setCartItems(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };


  const updateQuantity = async (itemId: string, newQuantity: number) => {
    if (newQuantity < 1) return;

    try {
      const { error } = await supabase
        .from('cart_items')
        .update({ quantity: newQuantity })
        .eq('id', itemId);

      if (error) throw error;
      loadCart();
    } catch (error) {

    }
  };

  const removeItem = async (itemId: string) => {
    try {
      const { error } = await supabase
        .from('cart_items')
        .delete()
        .eq('id', itemId);

      if (error) throw error;
      loadCart();
      setMessage('Item removed from cart');
      setTimeout(() => setMessage(''), 3000);
    } catch (error) {

    }
  };


  const allRatesSelected = cartItems.length > 0 && cartItems.every((item) => !!selectedRateByItem[item.id]);

  const resetCheckoutState = () => {
    setShowCheckout(false);
    setRatesFetched(false);
    setShippingRatesByItem({});
    setSelectedRateByItem({});
    setFetchingRates(false);
    setOpenRateItemId(null);
  };

  // Postcode/city/country drive the shipping-rate quote, so editing any of
  // them after rates were fetched invalidates the (now stale) quotes.
  const handleAddressFieldChange = (setter: (value: string) => void, value: string) => {
    setter(value);
    if (ratesFetched) {
      setRatesFetched(false);
      setShippingRatesByItem({});
      setSelectedRateByItem({});
      setMessage('');
    }
  };

  const handlePlaceOrder = async () => {
    if (!deliveryStreet.trim() || !deliveryCity.trim() || !deliveryPostalCode.trim() || !deliveryCountry.trim()) {
      setMessage('Please fill in all delivery address fields');
      return;
    }

    // Phase 1: fetch shipping rates for every cart item, one quote per item/picker.
    if (!ratesFetched) {
      setFetchingRates(true);
      setMessage('');
      try {
        const results = await Promise.all(cartItems.map(async (item) => {
          const { data: rateData, error: rateError } = await supabase.functions.invoke('get-shipping-rates', {
            body: {
              product_id: item.listing_id,
              buyer_postcode: deliveryPostalCode,
              buyer_city: deliveryCity,
              buyer_country: toCountryCode(deliveryCountry),
            },
          });
          if (rateError) {
            let serverMsg: string | undefined;
            if (rateError instanceof FunctionsHttpError) {
              try {
                const body = await rateError.context.json();
                serverMsg = body?.error;
              } catch {
                // response body wasn't valid JSON; fall through to generic message
              }
            }
            throw new Error(`${item.listing.title}: ${serverMsg || rateError.message || 'Unable to get shipping rates.'}`);
          }
          if (rateData?.error) throw new Error(`${item.listing.title}: ${rateData.error}`);
          const rates = Array.isArray(rateData?.rates) ? rateData.rates as ShippingRate[] : [];
          if (rates.length === 0) throw new Error(`${item.listing.title}: Shipping is not available for this destination.`);
          return { itemId: item.id, rates };
        }));

        const ratesMap: Record<string, ShippingRate[]> = {};
        results.forEach((r) => { ratesMap[r.itemId] = r.rates; });
        setShippingRatesByItem(ratesMap);
        setRatesFetched(true);
        setMessage('Choose a shipping option for each item to continue.');
      } catch (error: unknown) {
        setMessage('Error: ' + (error instanceof Error ? error.message : 'Unable to get shipping rates. Please try again.'));
      } finally {
        setFetchingRates(false);
      }
      return;
    }

    // Phase 2: require a chosen rate for every item before placing the orders.
    if (!allRatesSelected) {
      setMessage('Please select a shipping option for every item.');
      return;
    }

    try {
      setCheckoutLoading(true);
      setMessage('');
      const addressParts = [deliveryStreet];
      if (deliveryBuilding) addressParts.push(deliveryBuilding);
      if (deliveryApartment) addressParts.push(deliveryApartment);
      addressParts.push(deliveryCity, deliveryPostalCode, deliveryCountry);
      const fullAddress = addressParts.filter(p => p.trim()).join(', ');

      const createdOrders: PendingPayment[] = [];

      for (const item of cartItems) {
        const rate = selectedRateByItem[item.id];
        if (!rate) throw new Error('Please select a shipping option for every item.');

        const { data: pickerProfile, error: pickerError } = await supabase
          .from('picker_profiles')
          .select('user_id')
          .eq('id', item.listing.picker_id)
          .maybeSingle();

        if (pickerError) throw pickerError;
        if (!pickerProfile) throw new Error('Picker not found');

        const shippingTotal = rate.price;
        const orderTotal = item.listing.price * item.quantity + shippingTotal;

        const { data, error: orderError } = await supabase.from('orders').insert({
          client_id: user?.id,
          picker_id: pickerProfile.user_id,
          listing_id: item.listing_id,
          quantity: item.quantity,
          total_price: orderTotal,
          shipping_cost: shippingTotal,
          shipping_carrier: rate.carrier,
          shipping_service: rate.name,
          estimated_delivery_days: rate.max_days > 0
            ? `${rate.min_days}-${rate.max_days} business days`
            : null,
          delivery_address: fullAddress,
          delivery_street: deliveryStreet,
          delivery_street_line2: `${deliveryBuilding || ''}${deliveryApartment ? ' ' + deliveryApartment : ''}`.trim() || null,
          delivery_city: deliveryCity,
          delivery_postal_code: deliveryPostalCode,
          delivery_country: deliveryCountry,
          delivery_instructions: deliveryInstructions,
          status: 'pending',
          payment_status: 'pending',
          tracking_status: 'pending',
        }).select().maybeSingle();

        if (orderError) throw orderError;
        if (!data) throw new Error('Order creation returned no data');

        await supabase.from('order_status_history').insert({
          order_id: data.id,
          status: 'pending',
          notes: 'Order created',
          changed_by: user?.id,
        });

        createdOrders.push({ orderId: data.id, amount: orderTotal, title: item.listing.title });
      }

      const { error: deleteError } = await supabase
        .from('cart_items')
        .delete()
        .eq('client_id', user?.id);

      if (deleteError) throw deleteError;

      setPendingPayments(createdOrders);
      setInPaymentFlow(true);
    } catch (error: unknown) {
      setMessage('Error creating orders: ' + (error instanceof Error ? error.message : 'Please try again.'));
      setTimeout(() => setMessage(''), 5000);
    } finally {
      setCheckoutLoading(false);
    }
  };

  const handleAllOrdersPaid = () => {
    setInPaymentFlow(false);
    setPendingPayments([]);
    resetCheckoutState();
    setOrderSuccess(true);
    loadCart();
  };

  const handlePaymentFlowCancel = () => {
    setInPaymentFlow(false);
    setPendingPayments([]);
    resetCheckoutState();
    setMessage('Checkout stopped before payment finished. Any orders already created were saved as pending but are not yet paid.');
    loadCart();
  };


  const calculateSubtotal = () => {
    return cartItems.reduce((sum, item) => sum + (item.listing.price * item.quantity), 0);
  };

  const calculateShippingTotal = () => {
    return Object.values(selectedRateByItem).reduce((sum, rate) => sum + rate.price, 0);
  };

  const calculateTotal = () => {
    return calculateSubtotal() + (allRatesSelected ? calculateShippingTotal() : 0);
  };

  if (inPaymentFlow && pendingPayments.length > 0) {
    return (
      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <h2 className="text-xl font-bold text-gray-900 tracking-tight mb-6">Complete Payment</h2>
          <CartMultiOrderPayment
            payments={pendingPayments}
            onAllPaid={handleAllOrdersPaid}
            onCancel={handlePaymentFlowCancel}
          />
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading cart..." />
      </div>
    );
  }

  if (cartItems.length === 0) {
    return (
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-16 text-center">
          <div className="w-16 h-16 rounded-2xl bg-gray-50 flex items-center justify-center mx-auto mb-4">
            <ShoppingCart className="w-8 h-8 text-gray-300" />
          </div>
          <h2 className="text-lg font-bold text-gray-900 mb-1">Your cart is empty</h2>
          <p className="text-sm text-gray-400 mb-6">Add some amazing souvenirs to get started!</p>
          <button
            onClick={() => onViewChange?.('listings')}
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white rounded-xl font-semibold text-sm hover:bg-blue-700 transition-colors shadow-sm"
          >
            Browse Listings
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="flex items-center gap-3 mb-8">
        <div className="w-11 h-11 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
          <ShoppingCart className="w-5 h-5 text-blue-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Shopping Cart</h1>
          <p className="text-sm text-gray-500">
            {cartItems.length} {cartItems.length === 1 ? 'item' : 'items'} in your cart
          </p>
        </div>
      </div>

      {message && (
        <div className={`mb-6 p-4 rounded-xl flex items-start gap-2.5 text-sm ${
          message.includes('Error') ? 'bg-red-50 text-red-700' : 'bg-blue-50 text-blue-800'
        }`}>
          <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
          {message}
        </div>
      )}

      <div className="grid lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-4">
          {cartItems.map((item) => (
            <div key={item.id} className="bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 p-5">
              <div className="flex gap-4">
                {item.listing.image_url ? (
                  <img
                    src={item.listing.image_url}
                    alt={item.listing.title}
                    className="w-24 h-24 object-cover rounded-xl ring-1 ring-gray-100 flex-shrink-0"
                  />
                ) : (
                  <div className="w-24 h-24 rounded-xl bg-gray-50 ring-1 ring-gray-100 flex items-center justify-center flex-shrink-0">
                    <Package className="w-7 h-7 text-gray-300" />
                  </div>
                )}
                <div className="flex-1 min-w-0">
                  <h3 className="text-base font-bold text-gray-900 tracking-tight truncate">
                    {item.listing.title}
                  </h3>
                  <div className="flex items-center gap-1 text-gray-500 mt-0.5 mb-2">
                    <MapPin className="w-3.5 h-3.5 flex-shrink-0" />
                    <span className="text-xs truncate">{item.listing.region}</span>
                  </div>
                  <p className="text-sm text-gray-500">
                    €{item.listing.price.toFixed(2)} <span className="text-gray-400">each</span>
                  </p>
                </div>
                <div className="flex flex-col items-end justify-between flex-shrink-0">
                  <button
                    onClick={() => removeItem(item.id)}
                    className="p-2 -m-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                  <div className="flex flex-col items-end gap-2">
                    <div className="flex items-center gap-1 bg-gray-50 border border-gray-100 rounded-xl p-1">
                      <button
                        onClick={() => updateQuantity(item.id, item.quantity - 1)}
                        disabled={item.quantity <= 1}
                        className="w-7 h-7 flex items-center justify-center rounded-lg text-gray-600 hover:bg-white hover:shadow-sm disabled:opacity-40 disabled:hover:bg-transparent disabled:hover:shadow-none transition-all"
                      >
                        <Minus className="w-3.5 h-3.5" />
                      </button>
                      <span className="w-7 text-center text-sm font-semibold text-gray-900">{item.quantity}</span>
                      <button
                        onClick={() => updateQuantity(item.id, item.quantity + 1)}
                        className="w-7 h-7 flex items-center justify-center rounded-lg text-gray-600 hover:bg-white hover:shadow-sm transition-all"
                      >
                        <Plus className="w-3.5 h-3.5" />
                      </button>
                    </div>
                    <p className="text-lg font-bold text-gray-900">
                      €{(item.listing.price * item.quantity).toFixed(2)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="lg:col-span-1">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6 sticky top-20">
            <h2 className="text-lg font-bold text-gray-900 mb-5 pb-4 border-b border-gray-100">Order Summary</h2>

            <div className="space-y-3 mb-5">
              <div className="flex justify-between items-center text-sm">
                <span className="text-gray-500">Subtotal</span>
                <span className="font-semibold text-gray-900">€{calculateSubtotal().toFixed(2)}</span>
              </div>
              {referralDiscount > 0 && (
                <div className="flex justify-between items-center bg-green-50 -mx-2 px-2 py-2 rounded-lg text-sm">
                  <span className="text-green-700 font-medium">Referral Discount</span>
                  <span className="font-semibold text-green-600">-€{referralDiscount.toFixed(2)}</span>
                </div>
              )}
              <div className="flex justify-between items-center text-sm">
                <span className="text-gray-500">Shipping</span>
                {allRatesSelected ? (
                  <span className="font-semibold text-gray-900">€{calculateShippingTotal().toFixed(2)}</span>
                ) : (
                  <span className="text-gray-400">Calculated at checkout</span>
                )}
              </div>
            </div>

            <div className="bg-gradient-to-br from-blue-50 to-blue-100/60 border border-blue-100 rounded-xl p-4 mb-5">
              <div className="flex justify-between items-center">
                <span className="font-bold text-gray-900">Total</span>
                <span className="text-2xl font-bold text-blue-600">€{calculateTotal().toFixed(2)}</span>
              </div>
            </div>

            {!showCheckout ? (
              <button
                onClick={() => setShowCheckout(true)}
                className="w-full bg-blue-600 text-white py-3.5 rounded-xl font-semibold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2 shadow-sm hover:shadow-md"
              >
                <Lock className="w-4 h-4" />
                Proceed to Checkout
              </button>
            ) : (
              <div className="space-y-5">
                <div>
                  <label className="block text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-blue-600" />
                    Delivery Address
                  </label>
                  <div className="space-y-3">
                    <input
                      type="text"
                      value={deliveryStreet}
                      onChange={(e) => setDeliveryStreet(e.target.value)}
                      className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                      placeholder="Street Address *"
                      required
                    />
                    <div className="grid grid-cols-2 gap-3">
                      <input
                        type="text"
                        value={deliveryBuilding}
                        onChange={(e) => setDeliveryBuilding(e.target.value)}
                        className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                        placeholder="Building Number (Optional)"
                      />
                      <input
                        type="text"
                        value={deliveryApartment}
                        onChange={(e) => setDeliveryApartment(e.target.value)}
                        className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                        placeholder="Apartment/Unit (Optional)"
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <input
                        type="text"
                        value={deliveryCity}
                        onChange={(e) => handleAddressFieldChange(setDeliveryCity, e.target.value)}
                        className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                        placeholder="City *"
                        required
                      />
                      <input
                        type="text"
                        value={deliveryPostalCode}
                        onChange={(e) => handleAddressFieldChange(setDeliveryPostalCode, e.target.value)}
                        className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                        placeholder="Postal Code *"
                        required
                      />
                    </div>
                    <select
                      value={deliveryCountry}
                      onChange={(e) => handleAddressFieldChange(setDeliveryCountry, e.target.value)}
                      className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                      required
                    >
                      <option value="">Select a country *</option>
                      {COUNTRIES.map((country) => (
                        <option key={country} value={country}>{country}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-900 mb-2">
                    Delivery Instructions <span className="text-gray-400 font-normal">(Optional)</span>
                  </label>
                  <textarea
                    value={deliveryInstructions}
                    onChange={(e) => setDeliveryInstructions(e.target.value)}
                    rows={2}
                    className="w-full px-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
                    placeholder="e.g., Leave at front door"
                  />
                </div>

                <div className="pt-5 space-y-4 border-t border-gray-100">
                  {!ratesFetched ? (
                    <div className="bg-blue-50 border border-blue-100 rounded-xl p-4">
                      <p className="text-sm text-blue-800">
                        Fill in your delivery address, then get live shipping rates for every item in your cart.
                      </p>
                    </div>
                  ) : (
                    <div>
                      <div className="flex items-center justify-between mb-3">
                        <h4 className="text-sm font-semibold text-gray-900">Choose shipping for each item</h4>
                        <span className="text-xs font-semibold text-gray-500">
                          {Object.keys(selectedRateByItem).length} of {cartItems.length} selected
                        </span>
                      </div>
                      <div className="space-y-2 max-h-80 overflow-y-auto pr-1 -mr-1">
                        {cartItems.map((item) => {
                          const rates = shippingRatesByItem[item.id] || [];
                          const selected = selectedRateByItem[item.id];
                          const isOpen = openRateItemId === item.id;

                          return (
                            <div
                              key={item.id}
                              className={`rounded-xl border transition-colors ${
                                selected ? 'border-green-200 bg-green-50/50' : 'border-gray-200 bg-white'
                              }`}
                            >
                              <div className="flex items-center gap-3 p-2.5">
                                {item.listing.image_url ? (
                                  <img
                                    src={item.listing.image_url}
                                    alt={item.listing.title}
                                    className="w-10 h-10 rounded-lg object-cover ring-1 ring-gray-100 flex-shrink-0"
                                  />
                                ) : (
                                  <div className="w-10 h-10 rounded-lg bg-gray-50 ring-1 ring-gray-100 flex items-center justify-center flex-shrink-0">
                                    <Package className="w-4 h-4 text-gray-300" />
                                  </div>
                                )}
                                <div className="flex-1 min-w-0">
                                  <p className="text-xs font-semibold text-gray-900 truncate mb-1">{item.listing.title}</p>
                                  {rates.length > 0 ? (
                                    <button
                                      type="button"
                                      onClick={() => setOpenRateItemId((prev) => (prev === item.id ? null : item.id))}
                                      className={`w-full flex items-center justify-between gap-2 px-2.5 py-1.5 border rounded-lg text-xs font-medium transition-colors ${
                                        isOpen ? 'border-blue-400 bg-white' : 'border-gray-200 bg-gray-50 hover:border-blue-300 hover:bg-white'
                                      }`}
                                    >
                                      <span className={`truncate text-left ${selected ? 'text-gray-900' : 'text-gray-400'}`}>
                                        {selected
                                          ? `${selected.carrier} · ${selected.name} — €${selected.price.toFixed(2)}`
                                          : 'Select shipping option...'}
                                      </span>
                                      <ChevronDown className={`w-3.5 h-3.5 text-gray-400 flex-shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
                                    </button>
                                  ) : (
                                    <p className="text-xs text-red-600">No shipping options for this item.</p>
                                  )}
                                </div>
                                {selected ? (
                                  <CheckCircle className="w-4 h-4 text-green-500 flex-shrink-0" />
                                ) : (
                                  <span className="w-4 h-4 flex-shrink-0" />
                                )}
                              </div>

                              {isOpen && rates.length > 0 && (
                                <div className="px-2.5 pb-2.5 space-y-1.5">
                                  {rates.map((rate) => (
                                    <button
                                      type="button"
                                      key={rate.id}
                                      onClick={() => {
                                        setSelectedRateByItem((prev) => ({ ...prev, [item.id]: rate }));
                                        setOpenRateItemId(null);
                                      }}
                                      className={`w-full text-left rounded-lg border p-2 transition-colors ${
                                        selected?.id === rate.id
                                          ? 'border-blue-500 bg-blue-50'
                                          : 'border-gray-100 bg-white hover:border-blue-300 hover:bg-blue-50/40'
                                      }`}
                                    >
                                      <div className="flex items-center justify-between gap-3">
                                        <div className="min-w-0">
                                          <p className="font-semibold text-gray-900 text-xs truncate">{rate.carrier} · {rate.name}</p>
                                          <p className="text-[11px] text-gray-500 mt-0.5">{rate.min_days}-{rate.max_days} business days</p>
                                        </div>
                                        <span className="font-bold text-gray-900 text-xs flex-shrink-0">€{rate.price.toFixed(2)}</span>
                                      </div>
                                    </button>
                                  ))}
                                </div>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}

                  <button
                    onClick={handlePlaceOrder}
                    disabled={
                      checkoutLoading ||
                      fetchingRates ||
                      !deliveryStreet.trim() || !deliveryCity.trim() || !deliveryPostalCode.trim() || !deliveryCountry.trim() ||
                      (ratesFetched && !allRatesSelected)
                    }
                    className="w-full bg-blue-600 text-white py-3.5 rounded-xl font-bold hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-sm hover:shadow-md flex items-center justify-center gap-2"
                  >
                    {fetchingRates ? (
                      <>
                        <Loader className="w-4 h-4 animate-spin" />
                        Calculating Shipping...
                      </>
                    ) : checkoutLoading ? (
                      <>
                        <Loader className="w-4 h-4 animate-spin" />
                        Creating Orders...
                      </>
                    ) : !ratesFetched ? (
                      <>
                        <ArrowRight className="w-4 h-4" />
                        Get Shipping Rates
                      </>
                    ) : !allRatesSelected ? (
                      <>Select Shipping for Every Item</>
                    ) : (
                      <>
                        <CheckCircle className="w-4 h-4" />
                        Place Order & Pay
                      </>
                    )}
                  </button>

                  <button
                    onClick={resetCheckoutState}
                    className="w-full border border-gray-200 text-gray-700 py-2.5 rounded-xl font-semibold hover:bg-gray-50 transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {orderSuccess && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-md w-full p-8 text-center">
            <div className="mb-6">
              <div className="w-16 h-16 rounded-2xl bg-green-50 flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-8 h-8 text-green-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Order Placed & Paid!</h2>
              <p className="text-sm text-gray-500">
                Your payment was successful. Check your Orders page to track progress with each picker.
              </p>
            </div>
            <div className="space-y-3">
              <button
                onClick={() => {
                  setOrderSuccess(false);
                  onViewChange?.('orders');
                }}
                className="w-full bg-blue-600 text-white py-3 rounded-xl font-semibold hover:bg-blue-700 transition-colors shadow-sm flex items-center justify-center gap-2"
              >
                View My Orders
                <ArrowRight className="w-4 h-4" />
              </button>
              <button
                onClick={() => setOrderSuccess(false)}
                className="w-full border border-gray-200 text-gray-700 py-3 rounded-xl font-semibold hover:bg-gray-50 transition-colors"
              >
                Continue Shopping
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
