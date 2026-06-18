import { useState, useEffect } from 'react';
import { ShoppingCart, Trash2, Plus, Minus, Loader, CheckCircle, ArrowRight, Lock, MapPin } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase, CartItem, Listing } from '../lib/supabase';

type CartItemWithListing = CartItem & {
  listing: Listing;
};

export function CartView() {
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


  const handleRequestShippingQuote = async () => {
    if (!deliveryStreet.trim() || !deliveryCity.trim() || !deliveryPostalCode.trim() || !deliveryCountry.trim()) {
      setMessage('Please fill in all delivery address fields');
      return;
    }

    try {
      setCheckoutLoading(true);
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error('Please log in to continue');
      }

      // Create full delivery address with building and apartment
      const addressParts = [deliveryStreet];
      if (deliveryBuilding) addressParts.push(deliveryBuilding);
      if (deliveryApartment) addressParts.push(deliveryApartment);
      addressParts.push(deliveryCity, deliveryPostalCode, deliveryCountry);
      const fullAddress = addressParts.filter(p => p.trim()).join(', ');

      // Create orders with shipping quote requested status
      for (const item of cartItems) {
        const itemSubtotal = item.listing.price * item.quantity;

        // Get the picker's user_id from picker_profiles
        const { data: pickerProfile, error: pickerError } = await supabase
          .from('picker_profiles')
          .select('user_id')
          .eq('id', item.listing.picker_id)
          .maybeSingle();

        if (pickerError) throw pickerError;
        if (!pickerProfile) throw new Error('Picker not found');

        const { error: orderError } = await supabase.from('orders').insert({
          client_id: user?.id,
          picker_id: pickerProfile.user_id,
          listing_id: item.listing_id,
          quantity: item.quantity,
          total_price: itemSubtotal,
          delivery_address: fullAddress,
          delivery_street: deliveryStreet,
          delivery_street_line2: `${deliveryBuilding || ''}${deliveryApartment ? ' ' + deliveryApartment : ''}`.trim() || null,
          delivery_city: deliveryCity,
          delivery_postal_code: deliveryPostalCode,
          delivery_country: deliveryCountry,
          delivery_instructions: deliveryInstructions,
          status: 'awaiting_quote',
          payment_status: 'pending',
          shipping_quote_status: 'quote_requested',
          quote_requested_at: new Date().toISOString(),
        });

        if (orderError) throw orderError;
      }

      // Clear cart
      const { error: deleteError } = await supabase
        .from('cart_items')
        .delete()
        .eq('client_id', user?.id);

      if (deleteError) {
        console.error('Error clearing cart:', deleteError);
      }

      // Show success message
      setMessage('Orders created! Pickers will provide shipping quotes soon.');
      setShowCheckout(false);
      setOrderSuccess(true);
      loadCart();

    } catch (error: any) {
      setMessage('Error creating orders: ' + error.message);
      setTimeout(() => setMessage(''), 5000);
    } finally {
      setCheckoutLoading(false);
    }
  };


  const calculateSubtotal = () => {
    return cartItems.reduce((sum, item) => sum + (item.listing.price * item.quantity), 0);
  };

  const calculateTotal = () => {
    return calculateSubtotal();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Loading cart...</div>
      </div>
    );
  }

  if (cartItems.length === 0) {
    return (
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <ShoppingCart className="w-24 h-24 mx-auto text-gray-300 mb-4" />
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Your cart is empty</h2>
          <p className="text-gray-600 mb-6">Add some amazing souvenirs to get started!</p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <h1 className="text-3xl font-bold text-gray-900 mb-8 flex items-center gap-3">
        <ShoppingCart className="w-8 h-8" />
        Shopping Cart ({cartItems.length} {cartItems.length === 1 ? 'item' : 'items'})
      </h1>

      {message && (
        <div className={`mb-6 p-4 rounded-lg ${
          message.includes('Error') ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'
        }`}>
          {message}
        </div>
      )}

      <div className="grid lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-4">
          {cartItems.map((item) => (
            <div key={item.id} className="bg-white rounded-xl shadow-md p-6">
              <div className="flex gap-4">
                {item.listing.image_url && (
                  <img
                    src={item.listing.image_url}
                    alt={item.listing.title}
                    className="w-24 h-24 object-cover rounded-lg"
                  />
                )}
                <div className="flex-1">
                  <h3 className="text-lg font-bold text-gray-900 mb-1">
                    {item.listing.title}
                  </h3>
                  <p className="text-sm text-gray-600 mb-2">{item.listing.region}</p>
                  <p className="text-lg font-bold text-blue-600">
                    €{item.listing.price.toFixed(2)} each
                  </p>
                </div>
                <div className="flex flex-col items-end gap-3">
                  <button
                    onClick={() => removeItem(item.id)}
                    className="text-red-500 hover:text-red-700 transition-colors"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                  <div className="flex items-center gap-2 bg-gray-100 rounded-lg px-3 py-2">
                    <button
                      onClick={() => updateQuantity(item.id, item.quantity - 1)}
                      disabled={item.quantity <= 1}
                      className="text-gray-600 hover:text-gray-900 disabled:opacity-50"
                    >
                      <Minus className="w-4 h-4" />
                    </button>
                    <span className="w-8 text-center font-medium">{item.quantity}</span>
                    <button
                      onClick={() => updateQuantity(item.id, item.quantity + 1)}
                      className="text-gray-600 hover:text-gray-900"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                  </div>
                  <p className="text-lg font-bold text-gray-900">
                    €{(item.listing.price * item.quantity).toFixed(2)}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="lg:col-span-1">
          <div className="bg-white rounded-xl shadow-lg p-6 sticky top-4">
            <h2 className="text-2xl font-bold text-gray-900 mb-6 pb-4 border-b border-gray-200">Order Summary</h2>

            <div className="space-y-4 mb-6">
              <div className="flex justify-between items-center">
                <span className="text-base text-gray-700">Subtotal</span>
                <span className="text-lg font-semibold text-gray-900">€{calculateSubtotal().toFixed(2)}</span>
              </div>
              {referralDiscount > 0 && (
                <div className="flex justify-between items-center bg-green-50 -mx-2 px-2 py-2 rounded">
                  <span className="text-base text-green-700 font-medium">Referral Discount</span>
                  <span className="text-lg font-semibold text-green-600">-€{referralDiscount.toFixed(2)}</span>
                </div>
              )}
              <div className="flex justify-between items-center">
                <span className="text-base text-gray-700">Shipping</span>
                <span className="text-sm text-gray-500">Calculated at checkout</span>
              </div>
            </div>

            <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg p-4 mb-6">
              <div className="flex justify-between items-center">
                <span className="text-lg font-bold text-gray-900">Total</span>
                <span className="text-2xl font-bold text-blue-600">€{calculateTotal().toFixed(2)}</span>
              </div>
            </div>

            {!showCheckout ? (
              <button
                onClick={() => setShowCheckout(true)}
                className="w-full bg-blue-600 text-white py-4 rounded-lg font-semibold text-lg hover:bg-blue-700 transition-colors flex items-center justify-center gap-2 shadow-md hover:shadow-lg"
              >
                <Lock className="w-5 h-5" />
                Proceed to Checkout
              </button>
            ) : (
              <div className="space-y-5">
                <div>
                  <label className="block text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
                    <MapPin className="w-5 h-5 text-blue-600" />
                    Delivery Address
                  </label>
                  <div className="space-y-3">
                    <input
                      type="text"
                      value={deliveryStreet}
                      onChange={(e) => setDeliveryStreet(e.target.value)}
                      className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                      placeholder="Street Address *"
                      required
                    />
                    <div className="grid grid-cols-2 gap-3">
                      <input
                        type="text"
                        value={deliveryBuilding}
                        onChange={(e) => setDeliveryBuilding(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="Building Number (Optional)"
                      />
                      <input
                        type="text"
                        value={deliveryApartment}
                        onChange={(e) => setDeliveryApartment(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="Apartment/Unit (Optional)"
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <input
                        type="text"
                        value={deliveryCity}
                        onChange={(e) => setDeliveryCity(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="City *"
                        required
                      />
                      <input
                        type="text"
                        value={deliveryPostalCode}
                        onChange={(e) => setDeliveryPostalCode(e.target.value)}
                        className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                        placeholder="Postal Code *"
                        required
                      />
                    </div>
                    <input
                      type="text"
                      value={deliveryCountry}
                      onChange={(e) => setDeliveryCountry(e.target.value)}
                      className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                      placeholder="Country *"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-semibold text-gray-900 mb-2">
                    Delivery Instructions <span className="text-gray-500 font-normal">(Optional)</span>
                  </label>
                  <textarea
                    value={deliveryInstructions}
                    onChange={(e) => setDeliveryInstructions(e.target.value)}
                    rows={2}
                    className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                    placeholder="e.g., Leave at front door"
                  />
                </div>

                <div className="pt-6 space-y-4 border-t border-gray-200">
                  <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
                    <p className="text-sm text-blue-800">
                      <strong>Recommended:</strong> Request a shipping quote first. The picker will calculate exact shipping costs based on your delivery address, then you can complete payment.
                    </p>
                  </div>

                  <button
                    onClick={handleRequestShippingQuote}
                    disabled={checkoutLoading || !deliveryStreet.trim() || !deliveryCity.trim() || !deliveryPostalCode.trim() || !deliveryCountry.trim()}
                    className="w-full bg-blue-600 text-white py-4 rounded-lg font-bold text-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-md hover:shadow-lg flex items-center justify-center gap-2"
                  >
                    {checkoutLoading ? (
                      <>
                        <Loader className="w-5 h-5 animate-spin" />
                        Processing...
                      </>
                    ) : (
                      <>
                        <CheckCircle className="w-5 h-5" />
                        Place Order & Request Shipping Quote
                      </>
                    )}
                  </button>

                  <button
                    onClick={() => setShowCheckout(false)}
                    className="w-full border-2 border-gray-300 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
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
          <div className="bg-white rounded-xl max-w-md w-full p-8 text-center">
            <div className="mb-6">
              <CheckCircle className="w-20 h-20 mx-auto text-green-500 mb-4" />
              <h2 className="text-3xl font-bold text-gray-900 mb-2">Orders Created!</h2>
              <p className="text-gray-600">
                Your orders have been submitted. Pickers will provide shipping quotes soon, then you can complete payment.
              </p>
            </div>
            <div className="space-y-3">
              <button
                onClick={() => {
                  setOrderSuccess(false);
                  window.location.href = '#orders';
                }}
                className="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
              >
                View My Orders
                <ArrowRight className="w-5 h-5" />
              </button>
              <button
                onClick={() => setOrderSuccess(false)}
                className="w-full border-2 border-gray-300 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-50 transition-colors"
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
