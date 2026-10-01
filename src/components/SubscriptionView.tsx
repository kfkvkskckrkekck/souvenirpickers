import { useState, useEffect } from 'react';
import { CreditCard, CheckCircle, AlertCircle, Calendar, Euro, Trash2, Plus } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { getSubscriptionStatus, formatDate } from '../lib/subscription';
import { StripePaymentForm } from './StripePaymentForm';
import { supabase } from '../lib/supabase';
import { X } from 'lucide-react';
import { useNotification } from '../contexts/NotificationContext';

type PaymentCard = {
  id: string;
  card_brand: string;
  card_last4: string;
  card_exp_month: number;
  card_exp_year: number;
  is_default: boolean;
};

export function SubscriptionView() {
  const { profile } = useAuth();
  const { showNotification, showConfirmation } = useNotification();
  const [subscriptionInfo, setSubscriptionInfo] = useState<any>(null);
  const [paymentCards, setPaymentCards] = useState<PaymentCard[]>([]);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [loadingCards, setLoadingCards] = useState(false);
  const [processingPayment, setProcessingPayment] = useState(false);
  const [paymentError, setPaymentError] = useState('');
  const [paymentSuccess, setPaymentSuccess] = useState(false);

  useEffect(() => {
    if (profile) {
      const info = getSubscriptionStatus(profile);
      setSubscriptionInfo(info);
      if (profile.user_type === 'picker') {
        loadPaymentCards();
      }
    }
  }, [profile]);

  const loadPaymentCards = async () => {
    if (!profile || profile.user_type !== 'picker') return;

    setLoadingCards(true);
    try {
      const { data, error } = await supabase
        .from('picker_payment_cards')
        .select('*')
        .eq('picker_id', profile.id)
        .order('is_default', { ascending: false })
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPaymentCards(data || []);
    } catch (error) {

    } finally {
      setLoadingCards(false);
    }
  };

  const deletePaymentCard = async (cardId: string) => {
    const confirmed = await showConfirmation({
      title: 'Delete Payment Method',
      message: 'Are you sure you want to delete this payment method?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      type: 'danger'
    });

    if (!confirmed) return;

    try {
      const { error } = await supabase
        .from('picker_payment_cards')
        .delete()
        .eq('id', cardId);

      if (error) throw error;
      showNotification('success', 'Payment method deleted successfully');
      await loadPaymentCards();
    } catch (error) {

      showNotification('error', 'Failed to delete payment method');
    }
  };

  const setDefaultCard = async (cardId: string) => {
    try {
      await supabase
        .from('picker_payment_cards')
        .update({ is_default: false })
        .eq('picker_id', profile?.id);

      const { error } = await supabase
        .from('picker_payment_cards')
        .update({ is_default: true })
        .eq('id', cardId);

      if (error) throw error;

      await supabase
        .from('profiles')
        .update({ default_payment_card_id: cardId })
        .eq('id', profile?.id);

      showNotification('success', 'Default payment method updated');
      await loadPaymentCards();
    } catch (error) {

      showNotification('error', 'Failed to update default payment method');
    }
  };

  const processImmediatePayment = async () => {
    if (!profile) return;

    const confirmed = await showConfirmation({
      title: 'Process Payment',
      message: 'Process REAL payment of €10.00 now? This will charge your card immediately.',
      confirmText: 'Charge €10.00',
      cancelText: 'Cancel',
      type: 'warning'
    });

    if (!confirmed) return;

    setProcessingPayment(true);
    setPaymentError('');
    setPaymentSuccess(false);

    try {
      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/process-subscription-payment`;
      const { data: { session } } = await supabase.auth.getSession();

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session?.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ pickerId: profile.id }),
      });

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Payment failed');
      }

      setPaymentSuccess(true);
      showNotification('success', '€10.00 subscription payment processed successfully! Check your email for the invoice.', 8000);
      setTimeout(() => setPaymentSuccess(false), 5000);
    } catch (err: any) {

      const errorMessage = err.message || 'Failed to process payment';
      setPaymentError(errorMessage);
      showNotification('error', errorMessage);
    } finally {
      setProcessingPayment(false);
    }
  };

  if (!profile || !subscriptionInfo) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center h-64">
          <div className="text-gray-500">Loading subscription details...</div>
        </div>
      </div>
    );
  }

  const isTrialActive = subscriptionInfo.status === 'trial';
  const isPastDue = subscriptionInfo.status === 'past_due';
  const isCancelled = subscriptionInfo.status === 'cancelled';
  const isExpired = subscriptionInfo.status === 'expired';
  const isClient = profile.user_type === 'client';

  if (isClient) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">Account</h1>

        <div className="bg-gradient-to-br from-green-50 to-blue-50 rounded-2xl shadow-lg p-8 mb-6">
          <div className="flex items-start gap-4">
            <div className="bg-green-500 rounded-full p-3">
              <CheckCircle className="w-6 h-6 text-white" />
            </div>
            <div className="flex-1">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                Free Forever for Collectors
              </h2>
              <p className="text-gray-700 text-lg">
                As a collector, you have unlimited access to all features at no cost. Browse souvenirs, place orders, and connect with pickers worldwide - completely free!
              </p>
              <div className="mt-4 grid md:grid-cols-3 gap-4">
                <div className="flex items-center gap-2 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-medium">No subscription fees</span>
                </div>
                <div className="flex items-center gap-2 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-medium">Unlimited orders</span>
                </div>
                <div className="flex items-center gap-2 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-medium">Full marketplace access</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-2xl shadow-lg p-8">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <Calendar className="w-5 h-5" />
            Account Information
          </h3>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600">Account type:</span>
              <span className="font-medium text-gray-900 capitalize">Collector</span>
            </div>
            <div className="flex justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600">Member since:</span>
              <span className="font-medium text-gray-900">
                {formatDate(new Date(profile.created_at))}
              </span>
            </div>
            <div className="flex justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600">Email:</span>
              <span className="font-medium text-gray-900">{profile.email}</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Check if user is an early adopter
  const isEarlyAdopter = profile.is_early_adopter === true;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Subscription</h1>
        {subscriptionInfo.isActive && !isEarlyAdopter && (
          <button
            onClick={async () => {
              const confirmed = await showConfirmation({
                title: 'Cancel Subscription',
                message: 'Are you sure you want to cancel your subscription? You will lose access to all picker features.',
                confirmText: 'Cancel Subscription',
                cancelText: 'Keep Subscription',
                type: 'danger'
              });

              if (!confirmed) return;

              try {
                const { error } = await supabase
                  .from('profiles')
                  .update({
                    subscription_status: 'cancelled',
                    subscription_cancelled_at: new Date().toISOString()
                  })
                  .eq('id', profile?.id);

                if (error) throw error;

                showNotification('success', 'Subscription cancelled successfully');
                window.location.reload();
              } catch (error) {

                showNotification('error', 'Failed to cancel subscription');
              }
            }}
            className="px-6 py-2 text-red-600 hover:bg-red-50 border border-red-300 rounded-lg transition-colors font-medium"
          >
            Cancel Subscription
          </button>
        )}
      </div>

      {isEarlyAdopter && (
        <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl shadow-lg p-8 mb-6 border-2 border-blue-200">
          <div className="flex items-start gap-4">
            <div className="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-full p-3">
              <CheckCircle className="w-8 h-8 text-white" />
            </div>
            <div className="flex-1">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                Early Adopter #{profile.early_adopter_number}
              </h2>
              <p className="text-gray-700 text-lg mb-4">
                Congratulations! You're one of the first 500 pickers on SouvenirPickers.
              </p>
              <div className="bg-white/60 rounded-lg p-4 space-y-3">
                <div className="flex items-center gap-3 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-semibold">No subscription fees - Ever!</span>
                </div>
                <div className="flex items-center gap-3 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-semibold">Only 10% commission on sales</span>
                </div>
                <div className="flex items-center gap-3 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-semibold">Lifetime early adopter benefits</span>
                </div>
                <div className="flex items-center gap-3 text-green-700">
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-semibold">Priority support access</span>
                </div>
              </div>
              <div className="mt-4 text-sm text-gray-600">
                Member since: {formatDate(new Date(profile.created_at))}
              </div>
            </div>
          </div>
        </div>
      )}

      {!isEarlyAdopter && (
        <div className="bg-white rounded-2xl shadow-lg p-8 mb-6">
          <div className="flex items-start justify-between mb-6">
            <div>
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                {isTrialActive && 'Free Trial Active'}
                {subscriptionInfo.status === 'active' && 'Premium Subscription'}
                {isPastDue && 'Payment Past Due'}
                {isCancelled && 'Subscription Cancelled'}
                {isExpired && 'Trial Expired'}
              </h2>
              <p className="text-gray-600">{subscriptionInfo.message}</p>
            </div>
            <div className={`px-4 py-2 rounded-full text-sm font-medium ${
              subscriptionInfo.isActive
                ? 'bg-green-100 text-green-700'
                : 'bg-red-100 text-red-700'
            }`}>
              {subscriptionInfo.isActive ? 'Active' : 'Inactive'}
            </div>
          </div>

          {isTrialActive && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
            <div className="flex items-start gap-4">
              <CheckCircle className="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" />
              <div className="flex-1">
                <h3 className="font-semibold text-blue-900 mb-2">
                  You're on a 1-month free trial
                </h3>
                <p className="text-blue-800 mb-4">
                  Enjoy full access to all features at no cost. After your trial ends,
                  the subscription is just €10.00 per month.
                </p>
                <div className="grid md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-blue-700 font-medium">Trial started:</p>
                    <p className="text-blue-900">
                      {formatDate(new Date(profile.trial_started_at))}
                    </p>
                  </div>
                  <div>
                    <p className="text-blue-700 font-medium">Trial ends:</p>
                    <p className="text-blue-900">
                      {formatDate(new Date(profile.trial_ends_at))}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {subscriptionInfo.status === 'active' && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-6 mb-6">
            <div className="flex items-start gap-4">
              <CheckCircle className="w-6 h-6 text-green-600 flex-shrink-0 mt-1" />
              <div className="flex-1">
                <h3 className="font-semibold text-green-900 mb-2">
                  Premium Subscription Active
                </h3>
                <p className="text-green-800 mb-4">
                  You have full access to all marketplace features.
                </p>
                <div className="grid md:grid-cols-2 gap-4 text-sm">
                  {profile.subscription_started_at && (
                    <div>
                      <p className="text-green-700 font-medium">Subscription started:</p>
                      <p className="text-green-900">
                        {formatDate(new Date(profile.subscription_started_at))}
                      </p>
                    </div>
                  )}
                  {profile.next_payment_due && (
                    <div>
                      <p className="text-green-700 font-medium">Next payment:</p>
                      <p className="text-green-900">
                        {formatDate(new Date(profile.next_payment_due))}
                      </p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {(isPastDue || isExpired) && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-6 mb-6">
            <div className="flex items-start gap-4">
              <AlertCircle className="w-6 h-6 text-red-600 flex-shrink-0 mt-1" />
              <div className="flex-1">
                <h3 className="font-semibold text-red-900 mb-2">
                  {isPastDue ? 'Payment Required' : 'Trial Expired'}
                </h3>
                <p className="text-red-800 mb-4">
                  {isPastDue
                    ? 'Your last payment failed. Please update your payment method to continue using the service.'
                    : 'Your free trial has ended. Subscribe now to continue accessing all features.'}
                </p>
              </div>
            </div>
          </div>
        )}

        {isCancelled && (
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
            <div className="flex items-start gap-4">
              <AlertCircle className="w-6 h-6 text-gray-600 flex-shrink-0 mt-1" />
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900 mb-2">
                  Subscription Cancelled
                </h3>
                <p className="text-gray-800">
                  Your subscription has been cancelled. Reactivate to continue using the service.
                </p>
              </div>
            </div>
          </div>
        )}

        <div className="border-t pt-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Pricing</h3>
          <div className="bg-gray-50 rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <Euro className="w-8 h-8 text-blue-600" />
                <div>
                  <p className="text-2xl font-bold text-gray-900">€10.00</p>
                  <p className="text-sm text-gray-600">per month</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm font-medium text-gray-700">Billed monthly</p>
                <p className="text-xs text-gray-500">Cancel anytime</p>
              </div>
            </div>
            <div className="space-y-2 text-sm text-gray-700 mb-4">
              <p className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-600" />
                Full access to marketplace
              </p>
              <p className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-600" />
                Create unlimited listings and desires
              </p>
              <p className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-600" />
                Contact pickers and clients
              </p>
              <p className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-600" />
                Browse all souvenirs worldwide
              </p>
            </div>
            <div className="bg-orange-50 border border-orange-200 rounded-lg p-4 mt-4">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-sm font-semibold text-orange-900 mb-1">
                    Platform Commission
                  </p>
                  <p className="text-sm text-orange-800">
                    A 10% commission is applied to all sales. This covers payment processing, buyer protection, and platform maintenance.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="border-t pt-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <CreditCard className="w-5 h-5" />
            Payment Methods
          </h3>

          {loadingCards ? (
            <div className="text-center py-8 text-gray-500">Loading payment methods...</div>
          ) : paymentCards.length === 0 ? (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6 mb-4">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-yellow-600 mt-0.5" />
                <div className="flex-1">
                  <p className="text-sm font-semibold text-yellow-900 mb-1">
                    No payment method added
                  </p>
                  <p className="text-sm text-yellow-800">
                    Add a payment method now to ensure uninterrupted service when your trial ends.
                  </p>
                </div>
              </div>
            </div>
          ) : (
            <div className="space-y-3 mb-4">
              {paymentCards.map((card) => (
                <div
                  key={card.id}
                  className="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:border-blue-300 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <CreditCard className="w-6 h-6 text-gray-600" />
                    <div>
                      <p className="font-medium text-gray-900 capitalize">
                        {card.card_brand} •••• {card.card_last4}
                      </p>
                      <p className="text-sm text-gray-600">
                        Expires {card.card_exp_month}/{card.card_exp_year % 100}
                      </p>
                    </div>
                    {card.is_default && (
                      <span className="px-2 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded">
                        Default
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {!card.is_default && (
                      <button
                        onClick={() => setDefaultCard(card.id)}
                        className="px-3 py-1 text-sm text-blue-600 hover:text-blue-700 font-medium"
                      >
                        Set Default
                      </button>
                    )}
                    <button
                      onClick={() => deletePaymentCard(card.id)}
                      className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}

          <button
            onClick={() => {

              setShowPaymentModal(true);

            }}
            className="w-full bg-blue-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
          >
            <Plus className="w-5 h-5" />
            Add Payment Method
          </button>
        </div>

        {paymentCards.length > 0 && (
          <div className="border-t pt-6 mt-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Process Real Payment</h3>

            {paymentSuccess && (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                <div className="flex items-start gap-3">
                  <CheckCircle className="w-5 h-5 text-green-600 mt-0.5" />
                  <div>
                    <p className="text-sm font-semibold text-green-900">Payment Successful!</p>
                    <p className="text-sm text-green-800 mt-1">
                      Your €10.00 subscription payment has been processed. Check your email for the invoice.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {paymentError && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-5 h-5 text-red-600 mt-0.5" />
                  <div>
                    <p className="text-sm font-semibold text-red-900">Payment Failed</p>
                    <p className="text-sm text-red-800 mt-1">{paymentError}</p>
                  </div>
                </div>
              </div>
            )}

            <div className="bg-gray-50 rounded-lg p-6">
              <p className="text-sm text-gray-700 mb-4">
                Process a REAL payment of <span className="font-bold">€10.00</span> for your subscription.
                <span className="font-semibold text-red-600"> This will charge your card immediately</span> and you'll receive an invoice via email.
              </p>
              <button
                onClick={processImmediatePayment}
                disabled={processingPayment}
                className="w-full bg-green-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                <Euro className="w-5 h-5" />
                {processingPayment ? 'Processing Payment...' : 'Charge €10.00 Now'}
              </button>
            </div>
          </div>
        )}
      </div>
      )}

      <div className="bg-white rounded-2xl shadow-lg p-8">
        <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Calendar className="w-5 h-5" />
          Account Information
        </h3>
        <div className="space-y-3 text-sm">
          <div className="flex justify-between py-2 border-b border-gray-100">
            <span className="text-gray-600">Account type:</span>
            <span className="font-medium text-gray-900 capitalize">{profile.user_type}</span>
          </div>
          <div className="flex justify-between py-2 border-b border-gray-100">
            <span className="text-gray-600">Member since:</span>
            <span className="font-medium text-gray-900">
              {formatDate(new Date(profile.created_at))}
            </span>
          </div>
          <div className="flex justify-between py-2 border-b border-gray-100">
            <span className="text-gray-600">Email:</span>
            <span className="font-medium text-gray-900">{profile.email}</span>
          </div>
          {profile.last_payment_date && (
            <div className="flex justify-between py-2 border-b border-gray-100">
              <span className="text-gray-600">Last payment:</span>
              <span className="font-medium text-gray-900">
                {formatDate(new Date(profile.last_payment_date))}
              </span>
            </div>
          )}
        </div>
      </div>

      {showPaymentModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-[9999]"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setShowPaymentModal(false);
            }
          }}
        >
          <div
            className="bg-white rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto relative"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between z-10">
              <h2 className="text-2xl font-bold text-gray-900">Add Payment Method</h2>
              <button
                onClick={() => setShowPaymentModal(false)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 relative z-[1]">
              <StripePaymentForm
                onSuccess={async () => {
                  await loadPaymentCards();
                  setShowPaymentModal(false);
                }}
                onCancel={() => setShowPaymentModal(false)}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
