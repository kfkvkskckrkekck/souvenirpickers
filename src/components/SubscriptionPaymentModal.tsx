import { useState, useEffect, useRef } from 'react';
import { X, Shield, AlertCircle } from 'lucide-react';
import { loadStripe, Stripe, StripeElements } from '@stripe/stripe-js';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

const stripeKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || '';

const stripePromise = stripeKey ? loadStripe(stripeKey) : null;

type SubscriptionPaymentModalProps = {
  onClose: () => void;
  onPaymentAdded: () => void;
};

export function SubscriptionPaymentModal({ onClose, onPaymentAdded }: SubscriptionPaymentModalProps) {
  const { user } = useAuth();
  const [clientSecret, setClientSecret] = useState<string>('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [stripe, setStripe] = useState<Stripe | null>(null);
  const [elements, setElements] = useState<StripeElements | null>(null);
  const [isInIframe, setIsInIframe] = useState(false);
  const paymentElementRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Detect if we're in an iframe
    setIsInIframe(window.self !== window.top);
  }, []);

  useEffect(() => {
    const initStripe = async () => {
      try {
        if (!stripePromise) {
          setError('Stripe failed to load. Please check your configuration.');
          return;
        }

        const stripeInstance = await stripePromise;
        if (!stripeInstance) {
          setError('Failed to load payment processor.');
          return;
        }

        setStripe(stripeInstance);

        const { data: sessionData } = await supabase.auth.getSession();
        if (!sessionData?.session) {
          setError('Please log in to continue.');
          return;
        }

        const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-setup-intent`;
        const response = await fetch(apiUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${sessionData.session.access_token}`,
            'Content-Type': 'application/json',
          },
        });

        const result = await response.json();
        if (!result.clientSecret) {
          throw new Error('Failed to initialize payment');
        }

        setClientSecret(result.clientSecret);

        const elementsInstance = stripeInstance.elements({
          clientSecret: result.clientSecret,
        });

        const paymentElement = elementsInstance.create('payment', {
          layout: 'tabs',
        });

        if (paymentElementRef.current) {
          paymentElement.mount(paymentElementRef.current);
        }

        setElements(elementsInstance);
      } catch (err: any) {

        setError(err.message || 'Failed to load payment form');
      }
    };

    initStripe();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !stripe || !elements) return;

    setSubmitting(true);
    setError('');

    try {
      const { error: submitError } = await elements.submit();
      if (submitError) {
        throw new Error(submitError.message);
      }

      const { setupIntent, error: confirmError } = await stripe.confirmSetup({
        elements,
        confirmParams: {
          return_url: window.location.href,
        },
        redirect: 'if_required',
      });

      if (confirmError) {
        throw new Error(confirmError.message);
      }

      if (!setupIntent) {
        throw new Error('Setup failed - no setup intent returned');
      }

      if (setupIntent.status !== 'succeeded') {
        throw new Error(`Setup failed with status: ${setupIntent.status}`);
      }

      const paymentMethodId = typeof setupIntent.payment_method === 'string'
        ? setupIntent.payment_method
        : setupIntent.payment_method?.id;

      if (!paymentMethodId) {
        throw new Error('No payment method ID found in setup intent');
      }

      const { data: sessionData } = await supabase.auth.getSession();
      if (!sessionData?.session) throw new Error('No session found');

      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/save-payment-method`;

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${sessionData.session.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          paymentMethodId: paymentMethodId,
        }),
      });

      const result = await response.json();

      if (!result.success) {
        throw new Error(result.error || 'Failed to save payment method');
      }

      onPaymentAdded();
      onClose();
    } catch (err: any) {

      setError(err.message || 'Failed to add payment method. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-[60]">
      <div className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">Add Payment Method</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {isInIframe && (
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-amber-600 mt-0.5 flex-shrink-0" />
              <div className="flex-1">
                <p className="text-sm font-semibold text-amber-900">Payment Form Issue Detected</p>
                <p className="text-xs text-amber-700 mt-1">
                  The payment form may not work correctly in this preview. <button type="button" onClick={() => window.open(window.location.href, '_blank')} className="underline font-medium">Click here to open in a new tab</button> for full functionality.
                </p>
              </div>
            </div>
          )}

          <div className="bg-blue-50 rounded-lg p-4 flex items-start gap-3">
            <Shield className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              <p className="text-sm font-semibold text-blue-900">Secure Payment</p>
              <p className="text-xs text-blue-700 mt-1">
                Your payment information is encrypted and secure. We use Stripe to process payments and never store your full card details.
              </p>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Payment Information
            </label>
            <div
              ref={paymentElementRef}
              className="w-full"
            />
            {!clientSecret && !error && (
              <p className="text-xs text-blue-600 mt-2">Loading payment form...</p>
            )}
          </div>

          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 flex items-start gap-2">
            <AlertCircle className="w-5 h-5 text-yellow-600 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              <p className="text-sm text-yellow-900">
                <span className="font-semibold">Monthly Subscription:</span> €5.00 per month will be charged automatically after your trial period ends.
              </p>
            </div>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700 text-sm">
              {error}
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting || !stripe || !elements}
              className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {submitting ? 'Processing...' : !stripe || !elements ? 'Loading...' : 'Save Payment Method'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
