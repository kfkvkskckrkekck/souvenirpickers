import { useState, useEffect, useRef } from 'react';
import { CreditCard, Loader, AlertCircle, CheckCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

declare global {
  interface Window {
    Stripe: any;
  }
}

type StripePaymentFormProps = {
  onSuccess: () => void;
  onCancel: () => void;
};

export function StripePaymentForm({ onSuccess, onCancel }: StripePaymentFormProps) {
  const { user } = useAuth();
  const [stripe, setStripe] = useState<any>(null);
  const [cardElement, setCardElement] = useState<any>(null);
  const [cardName, setCardName] = useState('');
  const cardElementRef = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    let mounted = true;
    let cardInstance: any = null;

    const initStripe = async () => {
      try {

        if (!window.Stripe) {

          let attempts = 0;
          while (!window.Stripe && attempts < 30) {
            await new Promise(r => setTimeout(r, 100));
            attempts++;
          }
        }

        if (!window.Stripe) throw new Error('Stripe.js failed to load');

        const key = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY;
        if (!key) throw new Error('Missing Stripe key');
        if (!mounted) return;

        const stripeInstance = window.Stripe(key);
        const elements = stripeInstance.elements();

        cardInstance = elements.create('card', {
          hidePostalCode: true,
          style: {
            base: {
              fontSize: '16px',
              color: '#1f2937',
              fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
              fontSmoothing: 'antialiased',
              '::placeholder': { color: '#9ca3af' }
            },
            invalid: {
              color: '#dc2626',
              iconColor: '#dc2626'
            }
          }
        });

        let domAttempts = 0;
        while (!cardElementRef.current && domAttempts < 20 && mounted) {
          await new Promise(r => setTimeout(r, 50));
          domAttempts++;
        }

        if (!cardElementRef.current) throw new Error('Mount point not found');

        cardInstance.mount(cardElementRef.current);

        // Set up the card element immediately after mounting
        if (mounted) {
          setStripe(stripeInstance);
          setCardElement(cardInstance);
        }

        // Set a timeout to hide loading if ready event doesn't fire
        const readyTimeout = setTimeout(() => {

          if (mounted) {
            setLoading(false);
          }
        }, 2000);

        cardInstance.on('ready', () => {

          clearTimeout(readyTimeout);
          if (mounted) {
            setLoading(false);
          }
        });

        cardInstance.on('change', (event: any) => {
          if (mounted) setError(event.error ? event.error.message : '');
        });

      } catch (err: any) {

        if (mounted) {
          setError(err.message);
          setLoading(false);
        }
      }
    };

    initStripe();

    return () => {

      mounted = false;
      if (cardInstance) {
        try {
          cardInstance.destroy();
        } catch (e) {

        }
      }
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!cardName.trim()) {
      setError('Cardholder name required');
      return;
    }

    if (!stripe || !cardElement) {
      setError('Payment form not ready');
      return;
    }

    setProcessing(true);
    setError('');

    try {

      const { paymentMethod, error: stripeError } = await stripe.createPaymentMethod({
        type: 'card',
        card: cardElement,
        billing_details: { name: cardName }
      });

      if (stripeError) {

        throw new Error(stripeError.message);
      }

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/save-payment-method`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ paymentMethodId: paymentMethod.id })
        }
      );

      const result = await response.json();

      if (!result.success) throw new Error(result.error);

      // Create Stripe Subscription after payment method is saved
      const subscriptionResponse = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-stripe-subscription`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            pickerId: user?.id,
            paymentMethodId: paymentMethod.id
          })
        }
      );

      const subscriptionResult = await subscriptionResponse.json();

      if (!subscriptionResult.success) {
        console.error('Subscription creation failed:', subscriptionResult.error);
      }

      setSuccess(true);
      setTimeout(onSuccess, 1500);
    } catch (err: any) {

      setError(err.message || 'Failed to save card');
    } finally {
      setProcessing(false);
    }
  };

  if (success) {
    return (
      <div className="text-center py-8">
        <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
        <h3 className="text-xl font-bold text-gray-900 mb-2">Success!</h3>
        <p className="text-gray-600">Payment method added</p>
      </div>
    );
  }

  return (
    <div className="w-full">
      {loading && (
        <div className="text-center py-12">
          <Loader className="w-12 h-12 text-blue-600 animate-spin mx-auto mb-4" />
          <p className="text-gray-600">Loading payment form...</p>
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: loading ? 'none' : 'block' }}>
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Cardholder Name
          </label>
          <input
            type="text"
            value={cardName}
            onChange={(e) => setCardName(e.target.value)}
            placeholder="John Doe"
            required
            autoComplete="cc-name"
            className="w-full px-4 py-3 text-base border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
          />
        </div>

        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Card Information
          </label>
          <div
            ref={cardElementRef}
            id="card-element"
            className="stripe-card-element w-full px-4 py-3 border-2 border-gray-300 rounded-lg bg-white shadow-sm hover:border-blue-400 focus-within:border-blue-500 focus-within:ring-2 focus-within:ring-blue-200 transition-all"
            style={{
              minHeight: '44px',
              position: 'relative',
              zIndex: 10,
              pointerEvents: 'auto',
              WebkitUserSelect: 'auto',
              userSelect: 'auto',
              cursor: 'text'
            }}
          />
          <p className="text-xs text-gray-500 mt-2">
            Card number, expiration, and CVC
          </p>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <div className="flex gap-3">
              <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0" />
              <div>
                <p className="text-sm font-medium text-red-900">Error</p>
                <p className="text-sm text-red-700">{error}</p>
              </div>
            </div>
          </div>
        )}

        <div className="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <p className="text-xs text-blue-800">
            Secured by Stripe. Your card details are encrypted.
          </p>
        </div>

        <div className="flex gap-3">
          <button
            type="submit"
            disabled={processing || !stripe || !cardElement}
            className="flex-1 bg-blue-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
          >
            {processing ? (
              <>
                <Loader className="w-5 h-5 animate-spin" />
                Saving...
              </>
            ) : (
              <>
                <CreditCard className="w-5 h-5" />
                Save Card
              </>
            )}
          </button>
          <button
            type="button"
            onClick={onCancel}
            disabled={processing}
            className="px-6 py-3 border-2 border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors font-semibold"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
