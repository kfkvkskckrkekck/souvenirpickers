import { useState, useEffect, useRef } from 'react';
import { Loader, AlertCircle, CheckCircle, CreditCard, Lock } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { createPaymentIntentForOrder } from '../lib/payments';

declare global {
  interface Window {
    Stripe: any;
  }
}

export type PendingPayment = {
  orderId: string;
  amount: number;
  title: string;
};

type CartMultiOrderPaymentProps = {
  payments: PendingPayment[];
  onAllPaid: () => void;
  onCancel: () => void;
};

export function CartMultiOrderPayment({ payments, onAllPaid, onCancel }: CartMultiOrderPaymentProps) {
  const { user } = useAuth();
  const [stripe, setStripe] = useState<any>(null);
  const [cardElement, setCardElement] = useState<any>(null);
  const [cardReady, setCardReady] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [currentIndex, setCurrentIndex] = useState<number | null>(null);
  const [completedCount, setCompletedCount] = useState(0);
  const [success, setSuccess] = useState(false);
  const initialized = useRef(false);

  const totalAmount = payments.reduce((sum, p) => sum + p.amount, 0);

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

      card.mount('#card-element-cart-multi');
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

  const handlePayAll = async () => {
    if (!stripe || !cardElement || submitting) return;

    setSubmitting(true);
    setError('');

    try {
      const { paymentMethod, error: pmError } = await stripe.createPaymentMethod({
        type: 'card',
        card: cardElement,
        billing_details: { email: user?.email },
      });

      if (pmError) throw new Error(pmError.message);

      for (let i = 0; i < payments.length; i++) {
        setCurrentIndex(i);
        const payment = payments[i];

        const { clientSecret } = await createPaymentIntentForOrder({
          orderId: payment.orderId,
          amount: payment.amount,
        });

        const { error: confirmError, paymentIntent } = await stripe.confirmCardPayment(clientSecret, {
          payment_method: paymentMethod.id,
        });

        if (confirmError) throw new Error(`${payment.title}: ${confirmError.message}`);
        if (!paymentIntent || paymentIntent.status !== 'succeeded') {
          throw new Error(`${payment.title}: Payment was not completed.`);
        }

        setCompletedCount(i + 1);
      }

      setSuccess(true);
      setTimeout(onAllPaid, 1800);
    } catch (err: any) {
      setError(err.message || 'Payment failed. Please try again.');
    } finally {
      setSubmitting(false);
      setCurrentIndex(null);
    }
  };

  if (success) {
    return (
      <div className="text-center py-12">
        <CheckCircle className="w-20 h-20 text-green-600 mx-auto mb-6" />
        <h3 className="text-2xl font-bold text-gray-900 mb-3">All Payments Successful!</h3>
        <p className="text-gray-600 mb-2">
          {payments.length} order{payments.length > 1 ? 's' : ''} confirmed.
        </p>
        <p className="text-sm text-gray-500">A confirmation email has been sent to you.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-4">
        <div className="flex items-start gap-3">
          <Lock className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-semibold text-blue-900 mb-1">Secure Payment</p>
            <p className="text-sm text-blue-700">
              Enter your card once — we'll charge it for all {payments.length} order{payments.length > 1 ? 's' : ''} in your cart, one at a time.
            </p>
          </div>
        </div>
      </div>

      <div className="bg-gray-50 rounded-xl p-4 space-y-2.5">
        {payments.map((payment, i) => (
          <div key={payment.orderId} className="flex items-center justify-between text-sm">
            <span className={`flex items-center gap-2 ${
              i < completedCount ? 'text-green-700 font-medium' : currentIndex === i ? 'text-blue-700 font-medium' : 'text-gray-600'
            }`}>
              {i < completedCount ? (
                <CheckCircle className="w-4 h-4 flex-shrink-0" />
              ) : currentIndex === i ? (
                <Loader className="w-4 h-4 flex-shrink-0 animate-spin" />
              ) : (
                <span className="w-4 h-4 flex-shrink-0" />
              )}
              <span className="truncate">{payment.title}</span>
            </span>
            <span className="font-semibold text-gray-900 flex-shrink-0">€{payment.amount.toFixed(2)}</span>
          </div>
        ))}
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-3">
          <CreditCard className="w-4 h-4 inline mr-2" />
          Card Information
        </label>
        <div
          id="card-element-cart-multi"
          className="p-4 border-2 border-gray-300 rounded-lg bg-white min-h-[44px]"
        />
      </div>

      {error && (
        <div className="p-4 bg-red-50 border-2 border-red-200 rounded-lg flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <p className="text-sm font-medium text-red-900">Payment Error</p>
            <p className="text-sm text-red-700">{error}</p>
            {completedCount > 0 && (
              <p className="text-xs text-red-600 mt-1">
                {completedCount} of {payments.length} orders were already charged successfully before this error.
              </p>
            )}
          </div>
        </div>
      )}

      <div className="bg-gradient-to-r from-blue-50 to-green-50 border-2 border-blue-200 rounded-xl p-6">
        <div className="flex items-center justify-between mb-2">
          <span className="text-gray-700 font-medium">Total to Pay:</span>
          <span className="text-3xl font-bold text-blue-600">€{totalAmount.toFixed(2)}</span>
        </div>
        <p className="text-xs text-gray-600 mt-3">
          Your payment is protected by our escrow system. Funds are held securely until you confirm receipt of each item.
        </p>
      </div>

      <div className="flex gap-3">
        <button
          type="button"
          onClick={onCancel}
          disabled={submitting}
          className="flex-1 px-6 py-4 border-2 border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-semibold disabled:opacity-50"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handlePayAll}
          disabled={submitting || !stripe || !cardReady}
          className="flex-1 bg-gradient-to-r from-blue-600 to-green-600 text-white py-4 px-6 rounded-lg font-semibold hover:from-blue-700 hover:to-green-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {submitting ? (
            <>
              <Loader className="w-5 h-5 animate-spin" />
              {currentIndex !== null ? `Paying order ${currentIndex + 1} of ${payments.length}...` : 'Processing...'}
            </>
          ) : (
            <>
              <Lock className="w-5 h-5" />
              Pay €{totalAmount.toFixed(2)} for {payments.length} order{payments.length > 1 ? 's' : ''}
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
