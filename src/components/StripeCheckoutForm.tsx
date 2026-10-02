import { useState, useEffect, useRef } from 'react';
import { Loader, AlertCircle, CheckCircle, CreditCard, Lock } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { createPaymentIntentForOrder } from '../lib/payments';
import type { UnpaidOrderGuard } from '../lib/orderDrafts';

declare global {
  interface Window {
    Stripe: any;
  }
}

type StripeCheckoutFormProps = {
  amount: number;
  productAmount?: number;
  shippingAmount?: number;
  guard: UnpaidOrderGuard;
  createOrder: () => Promise<string>;
  onSuccess: (orderId: string) => void;
  onCancel: () => void | Promise<void>;
};

export function StripeCheckoutForm({ amount, productAmount, shippingAmount, guard, createOrder, onSuccess, onCancel }: StripeCheckoutFormProps) {
  const { user } = useAuth();
  const [stripe, setStripe] = useState<any>(null);
  const [cardElement, setCardElement] = useState<any>(null);
  const [cardReady, setCardReady] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const initialized = useRef(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    initializeStripe();
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
        setCardReady(event.complete === true);
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

  const handleSubmit = async () => {
    if (!stripe || !cardElement || processing || cancelling) {
      return;
    }

    setProcessing(true);
    guard.setProcessing(true);
    setError('');

    try {
      // The order row only comes into existence here, at the moment of
      // payment, and every attempt gets its own (see the catch below).
      const orderId = await createOrder();
      guard.trackCreated(orderId);

      const { clientSecret } = await createPaymentIntentForOrder({
        orderId,
        amount,
        productAmount,
        shippingAmount,
      });

      let result;
      try {
        result = await stripe.confirmCardPayment(clientSecret, {
          payment_method: {
            card: cardElement,
            billing_details: {
              email: user?.email,
            },
          },
        });
      } catch (confirmThrown) {
        guard.markOutcomeUnknown(orderId);
        throw confirmThrown;
      }

      const { error: stripeError, paymentIntent } = result;

      if (stripeError) {
        if (stripeError.type === 'api_connection_error') guard.markOutcomeUnknown(orderId);
        throw new Error(stripeError.message);
      }

      if (paymentIntent?.status === 'succeeded') {
        guard.markPaid(orderId);
        setSuccess(true);
        setTimeout(() => {
          onSuccess(orderId);
        }, 2000);
      } else {
        if (paymentIntent && (paymentIntent.status === 'processing' || paymentIntent.status === 'requires_capture')) {
          guard.markOutcomeUnknown(orderId);
        }
        throw new Error('Payment was not completed. Please try again.');
      }
    } catch (err: any) {
      // This attempt failed, so its unpaid order must not linger as a placed
      // order. A retry creates a fresh one. (An order that is paid, or whose
      // outcome is unknown, is protected and never removed.)
      guard.setProcessing(false);
      await guard.discard();
      setError(err.message || 'Payment failed. Please try again.');
    } finally {
      setProcessing(false);
      guard.setProcessing(false);
    }
  };

  const handleCancel = async () => {
    if (processing || cancelling) return;
    setCancelling(true);
    try {
      await onCancel();
    } finally {
      setCancelling(false);
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
              Your payment is processed securely through Stripe. Your card details are encrypted and never stored on our servers. Your order is only placed once payment succeeds.
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
          onClick={handleCancel}
          disabled={processing || cancelling}
          className="flex-1 px-6 py-4 border-2 border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-semibold disabled:opacity-50"
        >
          {cancelling ? 'Cancelling...' : 'Cancel'}
        </button>
        <button
          type="button"
          onClick={handleSubmit}
          disabled={processing || cancelling || !stripe || !cardReady}
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
