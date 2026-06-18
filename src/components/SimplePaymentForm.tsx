import { useState, useEffect, useRef } from 'react';
import { CreditCard, Loader, AlertCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

declare global {
  interface Window {
    Stripe: any;
  }
}

type SimplePaymentFormProps = {
  onSuccess: () => void;
  onCancel: () => void;
};

export function SimplePaymentForm({ onSuccess, onCancel }: SimplePaymentFormProps) {
  const { user } = useAuth();
  const [cardName, setCardName] = useState('');
  const [cardLoading, setCardLoading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [message, setMessage] = useState('');
  const stripeRef = useRef<any>(null);
  const cardElementRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    console.log('🚀 SimplePaymentForm mounted, initializing...');
    let mounted = true;

    const init = async () => {
      // Small delay for modal DOM to be ready
      await new Promise(r => setTimeout(r, 100));
      if (mounted) {
        initializeStripe();
      }
    };

    init();

    return () => {
      console.log('🧹 SimplePaymentForm unmounting...');
      mounted = false;
      if (cardElementRef.current) {
        try {
          cardElementRef.current.destroy();
          console.log('✅ Card element destroyed');
        } catch (e) {
          console.log('⚠️ Card element already destroyed:', e);
        }
        cardElementRef.current = null;
      }
      stripeRef.current = null;
    };
  }, []);

  const initializeStripe = async () => {
    try {
      console.log('🔧 SimplePaymentForm: Starting initialization...');

      // Longer delay for modal rendering
      await new Promise(r => setTimeout(r, 500));

      console.log('🔍 Checking containerRef:', containerRef.current);
      if (!containerRef.current) {
        console.error('❌ Container ref not available after delay');
        setMessage('Payment form not ready. Please try again.');
        return;
      }

      // Check if container already has a Stripe element
      if (containerRef.current.querySelector('.StripeElement')) {
        console.log('⚠️ Container already has a Stripe element, skipping initialization');
        return;
      }

      setCardLoading(true);

      if (!window.Stripe) {
        console.log('⏳ Waiting for Stripe.js to load...');
        setMessage('Payment system loading... Please wait.');
        await new Promise(r => setTimeout(r, 1000));

        if (!window.Stripe) {
          console.error('❌ Stripe.js not available');
          setMessage('Payment system unavailable. Please refresh and try again.');
          setCardLoading(false);
          return;
        }
      }

      const publishableKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY;
      console.log('🔑 Publishable key:', publishableKey ? 'Found' : 'Missing');
      if (!publishableKey) {
        setMessage('Payment configuration error');
        setCardLoading(false);
        return;
      }

      console.log('✅ Creating Stripe instance...');
      const stripe = window.Stripe(publishableKey);
      stripeRef.current = stripe;

      const elements = stripe.elements();

      console.log('💳 Creating card element...');
      const card = elements.create('card', {
        hidePostalCode: false,
        style: {
          base: {
            fontSize: '16px',
            color: '#1f2937',
            fontFamily: 'system-ui, -apple-system, sans-serif',
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

      // Set up event listeners BEFORE mounting
      card.on('ready', () => {
        console.log('✅✅✅ Card element READY event fired!');
        setCardLoading(false);
      });

      card.on('change', (event: any) => {
        console.log('📝 Card change event:', event);
        if (event.error) {
          setMessage(event.error.message || 'Card error');
        } else {
          setMessage('');
        }
      });

      card.on('focus', () => {
        console.log('👁️ Card element focused');
      });

      card.on('blur', () => {
        console.log('👁️ Card element blurred');
      });

      console.log('🎯 Mounting card element to DOM...');
      try {
        const mountResult = card.mount(containerRef.current);
        console.log('✅ Card element mount() result:', mountResult);

        // mountResult is a Promise in case of errors
        if (mountResult && typeof mountResult.then === 'function') {
          mountResult.then(() => {
            console.log('✅ Mount promise resolved successfully');
          }).catch((err: any) => {
            console.error('❌ Mount promise rejected:', err);
            setMessage('Failed to initialize payment form: ' + err.message);
            setCardLoading(false);
          });
        }
      } catch (mountError: any) {
        console.error('❌ Mount threw error:', mountError);
        setMessage('Failed to mount payment form: ' + mountError.message);
        setCardLoading(false);
        return;
      }

      setTimeout(() => {
        console.log('⏰ Fallback timeout: setting card loading to false');
        setCardLoading(false);
      }, 3000);
    } catch (error: any) {
      console.error('❌ Card initialization error:', error);
      setMessage('Failed to load payment form');
      setCardLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!cardName.trim()) {
      setMessage('Cardholder name required');
      return;
    }

    if (!stripeRef.current || !cardElementRef.current) {
      setMessage('Payment form not ready');
      return;
    }

    setProcessing(true);
    setMessage('');

    try {
      console.log('💳 Creating payment method...');

      // Create payment method with card element
      const { error: pmError, paymentMethod } = await stripeRef.current.createPaymentMethod({
        type: 'card',
        card: cardElementRef.current,
        billing_details: {
          name: cardName
        }
      });

      if (pmError) {
        console.error('❌ Payment method error:', pmError);
        throw new Error(pmError.message);
      }

      if (!paymentMethod) {
        throw new Error('Failed to create payment method');
      }

      console.log('✅ Payment method created:', paymentMethod.id);

      // Save to our backend
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      console.log('💾 Saving payment method...');
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/save-payment-method`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            paymentMethodId: paymentMethod.id
          })
        }
      );

      const result = await response.json();
      if (!response.ok || result.error) {
        console.error('❌ Save error:', result.error);
        throw new Error(result.error || 'Failed to save payment method');
      }

      console.log('✅ Payment method saved successfully');
      onSuccess();
    } catch (err: any) {
      console.error('❌ Submit error:', err);
      const errorMessage = err.message || 'Failed to save card';
      setMessage(errorMessage);
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="space-y-4">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Cardholder Name
          </label>
          <input
            type="text"
            value={cardName}
            onChange={(e) => setCardName(e.target.value)}
            placeholder="John Doe"
            autoComplete="cc-name"
            className="w-full px-4 py-3 text-base border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Card Information
          </label>
          <div className="relative">
            <div
              ref={containerRef}
              className="w-full p-4 border-2 border-gray-300 rounded-lg bg-white min-h-[44px]"
            />
            {cardLoading && (
              <div className="absolute inset-0 bg-white bg-opacity-90 flex items-center justify-center rounded-lg">
                <Loader className="w-6 h-6 text-blue-600 animate-spin" />
              </div>
            )}
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Card number, expiration, CVC, and ZIP code
          </p>
        </div>

        {message && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <div className="flex gap-3">
              <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0" />
              <div>
                <p className="text-sm font-medium text-red-900">Error</p>
                <p className="text-sm text-red-700">{message}</p>
              </div>
            </div>
          </div>
        )}

        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p className="text-xs text-blue-800">
            Secured by Stripe. Your card details are encrypted.
          </p>
          {window.location.hostname.includes('webcontainer') && (
            <p className="text-xs text-orange-700 mt-2 font-medium">
              Note: Stripe Elements may not fully load in this development environment. The payment form will work correctly in production.
            </p>
          )}
        </div>

        <div className="flex gap-3 pt-2">
          <button
            type="submit"
            disabled={processing || cardLoading}
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
