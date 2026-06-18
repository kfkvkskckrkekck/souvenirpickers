import { useState, useEffect, useRef } from 'react';
import { Loader, AlertCircle, CreditCard, Lock } from 'lucide-react';
import { supabase } from '../lib/supabase';

declare global {
  interface Window {
    Stripe: any;
  }
}

type CartPaymentModalProps = {
  orderId: string;
  clientSecret: string;
  amount: number;
  totalOrders: number;
  currentOrderNumber: number;
  onSuccess: () => void;
  onCancel: () => void;
};

export function CartPaymentModal({
  orderId,
  clientSecret,
  amount,
  totalOrders,
  currentOrderNumber,
  onSuccess,
  onCancel
}: CartPaymentModalProps) {
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState('');
  const [cardholderName, setCardholderName] = useState('');
  const [loading, setLoading] = useState(true);
  const stripeRef = useRef<any>(null);
  const elementsRef = useRef<any>(null);
  const cardElementRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let isMounted = true;
    let mountInterval: NodeJS.Timeout | null = null;

    const initializePaymentForm = async () => {
      try {
        console.log('[CartPaymentModal] Initializing payment form...');
        await new Promise(r => setTimeout(r, 500));

        if (!isMounted) return;

        if (!window.Stripe) {
          console.error('[CartPaymentModal] Stripe.js not loaded');
          if (isMounted) {
            setError('Payment system is loading. Please wait a moment and try again.');
            setLoading(false);
          }
          return;
        }

        const publishableKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY;
        console.log('[CartPaymentModal] Stripe key available:', !!publishableKey);
        console.log('[CartPaymentModal] Client secret available:', !!clientSecret);

        if (!publishableKey) {
          console.error('[CartPaymentModal] No Stripe publishable key');
          if (isMounted) {
            setError('Payment system not configured. Please contact support.');
            setLoading(false);
          }
          return;
        }

        if (!clientSecret) {
          console.error('[CartPaymentModal] No client secret provided');
          if (isMounted) {
            setError('Payment session not initialized. Please close this window and try again.');
            setLoading(false);
          }
          return;
        }

        console.log('[CartPaymentModal] Creating Stripe instance...');
        const stripe = window.Stripe(publishableKey);
        stripeRef.current = stripe;

        console.log('[CartPaymentModal] Creating elements with clientSecret...');
        const elements = stripe.elements({ clientSecret });
        elementsRef.current = elements;

        console.log('[CartPaymentModal] Creating payment element...');
        const paymentElement = elements.create('payment', {
          layout: {
            type: 'accordion',
            defaultCollapsed: false,
            radios: false,
            spacedAccordionItems: false
          }
        });

        cardElementRef.current = paymentElement;

        // Wait for container to be ready
        let attempts = 0;
        const maxAttempts = 20;
        mountInterval = setInterval(() => {
          if (!isMounted) {
            if (mountInterval) clearInterval(mountInterval);
            return;
          }

          attempts++;
          console.log(`[CartPaymentModal] Mount attempt ${attempts}/${maxAttempts}, container ready:`, !!containerRef.current);

          if (containerRef.current && isMounted) {
            if (mountInterval) clearInterval(mountInterval);
            console.log('[CartPaymentModal] Mounting payment element...');

            try {
              paymentElement.mount(containerRef.current);

              paymentElement.on('ready', () => {
                console.log('[CartPaymentModal] Payment element ready');
                if (isMounted) setLoading(false);
              });

              paymentElement.on('change', (event: any) => {
                if (isMounted) {
                  if (event.error) {
                    setError(event.error.message || 'Invalid payment details');
                  } else if (event.complete) {
                    setError('');
                  }
                }
              });

              // Fallback timeout
              setTimeout(() => {
                console.log('[CartPaymentModal] Fallback timeout - setting loading false');
                if (isMounted) setLoading(false);
              }, 3000);
            } catch (mountError: any) {
              console.error('[CartPaymentModal] Error mounting payment element:', mountError);
              if (isMounted) {
                setError('Failed to initialize payment input. Please refresh and try again.');
                setLoading(false);
              }
            }
          } else if (attempts >= maxAttempts) {
            if (mountInterval) clearInterval(mountInterval);
            console.error('[CartPaymentModal] Container not found after max attempts');
            if (isMounted) {
              setError('Payment form failed to load. Please close and try again.');
              setLoading(false);
            }
          }
        }, 100);
      } catch (err: any) {
        console.error('[CartPaymentModal] Payment form initialization error:', err);
        if (isMounted) {
          setError(`Failed to load payment form: ${err.message || 'Unknown error'}`);
          setLoading(false);
        }
      }
    };

    initializePaymentForm();

    return () => {
      isMounted = false;
      if (mountInterval) clearInterval(mountInterval);
      if (cardElementRef.current) {
        try {
          cardElementRef.current.unmount();
        } catch (e) {
          console.error('[CartPaymentModal] Error unmounting card element:', e);
        }
      }
    };
  }, [clientSecret]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!stripeRef.current || !elementsRef.current) {
      setError('Payment system not ready. Please wait a moment and try again.');
      return;
    }

    if (!cardholderName.trim()) {
      setError('Please enter the cardholder name');
      return;
    }

    console.log('[CartPaymentModal] Starting payment submission...');
    setProcessing(true);
    setError('');

    try {
      console.log('[CartPaymentModal] Confirming payment with Stripe...');
      const { error: stripeError, paymentIntent } = await stripeRef.current.confirmPayment({
        elements: elementsRef.current,
        confirmParams: {
          payment_method_data: {
            billing_details: {
              name: cardholderName.trim(),
            },
          },
        },
        redirect: 'if_required'
      });

      if (stripeError) {
        console.error('[CartPaymentModal] Stripe payment error:', stripeError);
        let errorMessage = 'Payment failed. ';

        // Provide more specific error messages
        if (stripeError.code === 'card_declined') {
          errorMessage += 'Your card was declined. Please try a different card.';
        } else if (stripeError.code === 'insufficient_funds') {
          errorMessage += 'Insufficient funds. Please use a different card.';
        } else if (stripeError.code === 'expired_card') {
          errorMessage += 'Your card has expired. Please use a different card.';
        } else if (stripeError.code === 'incorrect_cvc') {
          errorMessage += 'Incorrect CVC code. Please check and try again.';
        } else if (stripeError.code === 'processing_error') {
          errorMessage += 'A processing error occurred. Please try again.';
        } else {
          errorMessage += stripeError.message || 'Please check your card details and try again.';
        }

        setError(errorMessage);
        setProcessing(false);
        return;
      }

      console.log('[CartPaymentModal] Payment intent status:', paymentIntent.status);

      if (paymentIntent.status === 'succeeded' || paymentIntent.status === 'processing') {
        console.log('[CartPaymentModal] Payment successful, updating order...');

        const { error: updateError } = await supabase
          .from('orders')
          .update({
            payment_status: 'paid',
            status: 'confirmed',
          })
          .eq('id', orderId);

        if (updateError) {
          console.error('[CartPaymentModal] Order update error:', updateError);
          // Don't fail the payment if update fails - payment went through
        }

        console.log('[CartPaymentModal] Payment completed successfully');
        onSuccess();
      } else {
        console.error('[CartPaymentModal] Unexpected payment status:', paymentIntent.status);
        setError(`Payment status: ${paymentIntent.status}. Please contact support if you were charged.`);
        setProcessing(false);
      }
    } catch (err: any) {
      console.error('[CartPaymentModal] Payment processing error:', err);
      setError(err.message || 'An unexpected error occurred. Please try again.');
      setProcessing(false);
    }
  };

  return (
    <div className="space-y-6">
      {totalOrders > 1 && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p className="text-sm text-blue-800 font-medium">
            Processing Order {currentOrderNumber} of {totalOrders}
          </p>
        </div>
      )}

      <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-lg p-6 border border-gray-200">
        <div className="flex items-center justify-between">
          <span className="text-gray-700 font-medium">Order Amount:</span>
          <span className="text-3xl font-bold text-blue-600">€{amount.toFixed(2)}</span>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
          <p className="text-red-800 text-sm font-medium">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
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
            className="w-full px-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all bg-white text-gray-900"
            disabled={processing || loading}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <CreditCard className="w-5 h-5 text-blue-600" />
            Card Details
          </label>
          <div className="relative">
            <div
              ref={containerRef}
              className="p-4 border-2 border-gray-300 rounded-lg bg-white transition-all"
              style={{ minHeight: '56px' }}
            ></div>
            {loading && (
              <div className="absolute inset-0 flex items-center justify-center bg-white bg-opacity-90 rounded-lg">
                <Loader className="w-6 h-6 animate-spin text-blue-600" />
              </div>
            )}
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Enter your card number, expiry date (MM/YY), and CVC code
          </p>
        </div>

        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex items-start gap-3">
          <Lock className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
          <p className="text-sm text-amber-800">
            Your card details are encrypted and secure. Funds will be held in escrow until delivery confirmation.
          </p>
        </div>

        <div className="flex gap-3 pt-4">
          <button
            type="submit"
            disabled={processing || loading}
            className="flex-1 bg-green-600 text-white py-4 rounded-lg font-bold text-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors shadow-md hover:shadow-lg flex items-center justify-center gap-2"
          >
            {processing ? (
              <>
                <Loader className="w-5 h-5 animate-spin" />
                Processing Payment...
              </>
            ) : (
              <>
                <Lock className="w-5 h-5" />
                Pay €{amount.toFixed(2)}
              </>
            )}
          </button>
          <button
            type="button"
            onClick={onCancel}
            disabled={processing}
            className="px-6 border-2 border-gray-300 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
}
