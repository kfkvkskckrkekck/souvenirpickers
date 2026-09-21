import { useState, useEffect, useRef } from 'react';
import { Loader, AlertCircle, CheckCircle, CreditCard, Lock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

declare global {
  interface Window {
    Stripe: any;
  }
}

type StripeCheckoutFormProps = {
  orderId: string;
  amount: number;
  productAmount?: number;
  shippingAmount?: number;
  onSuccess: () => void;
  onCancel: () => void;
};

export function StripeCheckoutForm({ orderId, amount, productAmount, shippingAmount, onSuccess, onCancel }: StripeCheckoutFormProps) {
  const { user } = useAuth();
  const [stripe, setStripe] = useState<any>(null);
  const [cardElement, setCardElement] = useState<any>(null);
  const [clientSecret, setClientSecret] = useState('');
  const [loading, setLoading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const initialized = useRef(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    initializeStripe();
    createPaymentIntent();
  }, []);

  const initializeStripe = () => {
    try {
      const stripePublishableKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY;

      if (!stripePublishableKey) {
        setError('Stripe is not configured properly.');
        return;
      }

      if (!window.Stripe) {
        setError('Stripe.js failed to load. Please check your connection.');
        return;
      }

      const stripeInstance = window.Stripe(stripePublishableKey);
      setStripe(stripeInstance);

      const elements = stripeInstance.elements();
      const card = elements.create('card', {
        hidePostalCode: false,
        style: {
          base: {
            fontSize: '16px',
            color: '#1f2937',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            '::placeholder': {
              color: '#9ca3af',
            },
          },
          invalid: {
            color: '#ef4444',
            iconColor: '#ef4444',
          },
        },
      });

      card.mount('#card-element-checkout');
      setCardElement(card);

      card.on('change', (event: any) => {
        if (event.error) {
          setError(event.error.message);
        } else {
          setError('');
        }
      });
    } catch (err) {

      setError('Failed to initialize payment form.');
    }
  };

  const createPaymentIntent = async () => {
    setLoading(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData?.session?.access_token;

      if (!token) {
        throw new Error('Not authenticated');
      }

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const response = await fetch(
        `${supabaseUrl}/functions/v1/create-payment-intent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
          },
          body: JSON.stringify({
            orderId,
            amount,
            productAmount,
            shippingAmount,
            currency: 'eur',
          }),
        }
      );

      const result = await response.json();

      if (result.error) {
        throw new Error(result.error);
      }

      setClientSecret(result.clientSecret);
    } catch (err: any) {

      setError(err.message || 'Failed to initialize payment');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    if (!stripe || !cardElement || !clientSecret) {
      return;
    }

    setProcessing(true);
    setError('');

    try {
      const { error: stripeError, paymentIntent } = await stripe.confirmCardPayment(
        clientSecret,
        {
          payment_method: {
            card: cardElement,
            billing_details: {
              email: user?.email,
            },
          },
        }
      );

      if (stripeError) {
        throw new Error(stripeError.message);
      }

      if (paymentIntent.status === 'succeeded') {
        setSuccess(true);
        setTimeout(() => {
          onSuccess();
        }, 2000);
      }
    } catch (err: any) {

      setError(err.message || 'Payment failed. Please try again.');
    } finally {
      setProcessing(false);
    }
  };

  if (success) {
    return (
      <div className="text-center py-12">
        <CheckCircle className="w-20 h-20 text-green-600 mx-auto mb-6" />
        <h3 className="text-2xl font-bold text-gray-900 mb-3">Payment Successful!</h3>
        <p className="text-gray-600 mb-2">Your order has been confirmed.</p>
        <p className="text-sm text-gray-500">A confirmation email has been sent to you.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-4 mb-6">
        <div className="flex items-start gap-3">
          <Lock className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-semibold text-blue-900 mb-1">Secure Payment</p>
            <p className="text-sm text-blue-700">
              Your payment is processed securely through Stripe. Your card details are encrypted and never stored on our servers.
            </p>
          </div>
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-3">
          <CreditCard className="w-4 h-4 inline mr-2" />
          Card Information
        </label>
        <div
          id="card-element-checkout"
          className="p-4 border-2 border-gray-300 rounded-lg bg-white min-h-[44px]"
        />
        {loading && (
          <p className="mt-2 text-xs text-gray-500 flex items-center gap-1.5">
            <Loader className="w-3 h-3 animate-spin" />
            Setting up secure payment...
          </p>
        )}
      </div>

      {error && (
        <div className="p-4 bg-red-50 border-2 border-red-200 rounded-lg flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <p className="text-sm font-medium text-red-900">Payment Error</p>
            <p className="text-sm text-red-700">{error}</p>
          </div>
        </div>
      )}

      <div className="bg-gradient-to-r from-blue-50 to-green-50 border-2 border-blue-200 rounded-xl p-6">
        <div className="flex items-center justify-between mb-2">
          <span className="text-gray-700 font-medium">Amount to Pay:</span>
          <span className="text-3xl font-bold text-blue-600">€{amount.toFixed(2)}</span>
        </div>
        <p className="text-xs text-gray-600 mt-3">
          Your payment is protected by our escrow system. Funds are held securely until you confirm receipt of your items.
        </p>
      </div>

      <div className="flex gap-3">
        <button
          type="button"
          onClick={onCancel}
          disabled={processing}
          className="flex-1 px-6 py-4 border-2 border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-semibold disabled:opacity-50"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSubmit}
          disabled={processing || !stripe || !clientSecret || !!error}
          className="flex-1 bg-gradient-to-r from-blue-600 to-green-600 text-white py-4 px-6 rounded-lg font-semibold hover:from-blue-700 hover:to-green-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {processing ? (
            <>
              <Loader className="w-5 h-5 animate-spin" />
              Processing...
            </>
          ) : (
            <>
              <Lock className="w-5 h-5" />
              Pay €{amount.toFixed(2)}
            </>
          )}
        </button>
      </div>

      <p className="text-xs text-center text-gray-500">
        By completing this payment, you agree to our Terms of Service and acknowledge our escrow payment protection policy.
      </p>
    </div>
  );
}
