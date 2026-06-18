import { useState, useEffect, useRef } from 'react';
import { CreditCard, Plus, Trash2, Lock, Loader } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase, CollectorPaymentMethod } from '../lib/supabase';

declare global {
  interface Window {
    Stripe: any;
  }
}

export function CollectorPaymentSetup() {
  const { user } = useAuth();
  const [paymentMethods, setPaymentMethods] = useState<CollectorPaymentMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddCard, setShowAddCard] = useState(false);
  const [addingCard, setAddingCard] = useState(false);
  const [message, setMessage] = useState('');
  const [cardholderName, setCardholderName] = useState('');
  const [cardLoading, setCardLoading] = useState(false);
  const stripeRef = useRef<any>(null);
  const cardElementRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (user) {
      loadPaymentMethods();
    }
  }, [user]);

  useEffect(() => {
    if (showAddCard) {
      initializeStripe();
    }
    return () => {
      if (cardElementRef.current) {
        try {
          cardElementRef.current.unmount();
        } catch (e) {
          // Element already unmounted
        }
        cardElementRef.current = null;
      }
    };
  }, [showAddCard]);

  const initializeStripe = async () => {
    try {
      await new Promise(r => setTimeout(r, 200));

      if (!containerRef.current) {
        console.error('Container ref not available');
        setMessage('Payment form not ready. Please try again.');
        return;
      }

      setCardLoading(true);

      // Wait for Stripe.js to load
      let attempts = 0;
      while (!window.Stripe && attempts < 30) {
        await new Promise(r => setTimeout(r, 100));
        attempts++;
      }

      if (!window.Stripe) {
        setMessage('Payment system unavailable. Please refresh and try again.');
        setCardLoading(false);
        return;
      }

      const publishableKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY;
      if (!publishableKey) {
        setMessage('Payment configuration error');
        setCardLoading(false);
        return;
      }

      const stripe = window.Stripe(publishableKey);
      stripeRef.current = stripe;

      const elements = stripe.elements();

      const card = elements.create('card', {
        hidePostalCode: true,
        style: {
          base: {
            fontSize: '16px',
            color: '#1f2937',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            fontSmoothing: 'antialiased',
            '::placeholder': {
              color: '#9ca3af',
            },
          },
          invalid: {
            color: '#dc2626',
            iconColor: '#dc2626',
          },
        },
      });

      cardElementRef.current = card;

      card.mount(containerRef.current);

      // Set a timeout to hide loading if ready event doesn't fire
      const readyTimeout = setTimeout(() => {
        console.log('Fallback: setting card loading to false');
        setCardLoading(false);
      }, 2000);

      card.on('ready', () => {
        console.log('Stripe card element ready');
        clearTimeout(readyTimeout);
        setCardLoading(false);
      });

      card.on('change', (event: any) => {
        if (event.error) {
          setMessage(event.error.message || 'Card error');
        } else {
          setMessage('');
        }
      });
    } catch (error: any) {
      console.error('Card initialization error:', error);
      setMessage('Failed to load payment form');
      setCardLoading(false);
    }
  };

  const loadPaymentMethods = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('collector_payment_methods')
        .select('*')
        .eq('user_id', user?.id)
        .order('is_default', { ascending: false });

      if (error) throw error;
      setPaymentMethods(data || []);
    } catch (error) {
      console.error('Error loading payment methods:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddCard = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!stripeRef.current || !cardElementRef.current) {
      setMessage('Card input not ready. Please wait and try again.');
      return;
    }

    if (!cardholderName.trim()) {
      setMessage('Please enter cardholder name');
      return;
    }

    try {
      setAddingCard(true);
      setMessage('');

      const result = await stripeRef.current.createPaymentMethod({
        type: 'card',
        card: cardElementRef.current,
        billing_details: {
          name: cardholderName.trim(),
        },
      });

      console.log('Stripe createPaymentMethod result:', result);

      if (result.error) {
        throw new Error(result.error.message);
      }

      if (!result.paymentMethod || !result.paymentMethod.id) {
        throw new Error('Failed to create payment method. Please try again.');
      }

      const paymentMethod = result.paymentMethod;

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('No active session');

      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/save-payment-method`;
      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          paymentMethodId: paymentMethod.id,
        }),
      });

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Failed to save payment method');
      }

      setMessage('Payment card added successfully!');
      setShowAddCard(false);
      setCardholderName('');
      if (cardElementRef.current) {
        cardElementRef.current.clear();
      }
      loadPaymentMethods();
      setTimeout(() => setMessage(''), 3000);
    } catch (error: any) {
      setMessage(error.message || 'Failed to add payment card');
    } finally {
      setAddingCard(false);
    }
  };

  const handleDeleteCard = async (cardId: string) => {
    if (!confirm('Are you sure you want to delete this payment method?')) return;

    try {
      const { error } = await supabase
        .from('collector_payment_methods')
        .delete()
        .eq('id', cardId);

      if (error) throw error;

      setMessage('Payment method deleted');
      loadPaymentMethods();
      setTimeout(() => setMessage(''), 3000);
    } catch (error: any) {
      setMessage('Error deleting payment method: ' + error.message);
    }
  };

  const handleSetDefault = async (cardId: string) => {
    try {
      await supabase
        .from('collector_payment_methods')
        .update({ is_default: false })
        .eq('user_id', user?.id);

      const { error } = await supabase
        .from('collector_payment_methods')
        .update({ is_default: true })
        .eq('id', cardId);

      if (error) throw error;

      setMessage('Default payment method updated');
      loadPaymentMethods();
      setTimeout(() => setMessage(''), 3000);
    } catch (error: any) {
      setMessage('Error updating default payment method: ' + error.message);
    }
  };

  const handleCloseAddCard = () => {
    if (cardElementRef.current) {
      cardElementRef.current.clear();
    }
    setCardholderName('');
    setShowAddCard(false);
    setMessage('');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {!showAddCard && (
        <div className="flex justify-end">
          <button
            onClick={() => setShowAddCard(true)}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus className="w-4 h-4" />
            Add Card
          </button>
        </div>
      )}

      {message && (
        <div className={`p-4 rounded-lg ${
          message.includes('Error') || message.includes('Failed')
            ? 'bg-red-50 text-red-600'
            : 'bg-green-50 text-green-600'
        }`}>
          {message}
        </div>
      )}

      {showAddCard && (
        <div className="bg-white border-2 border-gray-200 rounded-lg p-6 shadow-sm">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-bold text-gray-900">Add Payment Card</h3>
            <button
              type="button"
              onClick={handleCloseAddCard}
              className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
            >
              ×
            </button>
          </div>

          <form onSubmit={handleAddCard} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-gray-900 mb-2">
                Cardholder Name
              </label>
              <input
                type="text"
                value={cardholderName}
                onChange={(e) => setCardholderName(e.target.value)}
                placeholder="John Doe"
                maxLength={100}
                required
                disabled={addingCard || cardLoading}
                className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-200 transition-all disabled:opacity-50"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-900 mb-2 flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-blue-600" />
                Card Details
              </label>
              <div className="relative">
                <div
                  ref={containerRef}
                  className="p-4 border-2 border-gray-300 rounded-lg bg-white hover:border-blue-400 focus-within:border-blue-500 focus-within:ring-2 focus-within:ring-blue-200 transition-all"
                  style={{ minHeight: '56px' }}
                ></div>
                {cardLoading && (
                  <div className="absolute inset-0 bg-white bg-opacity-90 flex items-center justify-center rounded-lg">
                    <Loader className="w-5 h-5 animate-spin text-blue-600" />
                  </div>
                )}
              </div>
              <p className="text-xs text-gray-500 mt-2">
                Enter your card number, expiry date (MM/YY), and CVC code
              </p>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 flex items-start gap-2">
              <Lock className="w-4 h-4 text-blue-600 flex-shrink-0 mt-0.5" />
              <span className="text-xs text-blue-800">
                Secured by Stripe. Your card details are encrypted and never stored on our servers.
              </span>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={addingCard || cardLoading}
                className="flex-1 bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors font-semibold flex items-center justify-center gap-2"
              >
                {addingCard ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    Adding Card...
                  </>
                ) : (
                  <>
                    <CreditCard className="w-4 h-4" />
                    Add Card
                  </>
                )}
              </button>
              <button
                type="button"
                onClick={handleCloseAddCard}
                disabled={addingCard}
                className="px-6 py-3 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-semibold"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {paymentMethods.length === 0 && !showAddCard ? (
        <div className="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
          <CreditCard className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 font-medium mb-4">No payment methods added yet</p>
          <button
            onClick={() => setShowAddCard(true)}
            className="text-blue-600 hover:text-blue-700 font-semibold"
          >
            Add your first payment method
          </button>
        </div>
      ) : (
        !showAddCard && (
          <div className="space-y-3">
            {paymentMethods.map((method) => (
              <div
                key={method.id}
                className="flex items-center justify-between p-4 bg-white border-2 border-gray-200 rounded-lg hover:border-blue-200 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <CreditCard className="w-8 h-8 text-gray-400" />
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-gray-900">
                        {method.brand} •••• {method.last_four}
                      </span>
                      {method.is_default && (
                        <span className="px-2 py-1 text-xs font-semibold bg-blue-100 text-blue-700 rounded">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600">
                      Expires {method.exp_month}/{method.exp_year}
                    </p>
                  </div>
                </div>
                <div className="flex gap-2">
                  {!method.is_default && (
                    <button
                      onClick={() => handleSetDefault(method.id)}
                      className="px-3 py-1.5 text-sm font-medium text-blue-600 hover:bg-blue-50 rounded transition-colors"
                    >
                      Set as Default
                    </button>
                  )}
                  <button
                    onClick={() => handleDeleteCard(method.id)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )
      )}
    </div>
  );
}
