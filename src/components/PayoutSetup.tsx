import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { CheckCircle, AlertCircle, Loader, ExternalLink, DollarSign } from 'lucide-react';

type AccountStatus = 'loading' | 'not_created' | 'pending' | 'verified';

export function PayoutSetup() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [status, setStatus] = useState<AccountStatus>('loading');
  const [requirements, setRequirements] = useState<string[]>([]);
  const [isRedirecting, setIsRedirecting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    checkStatus();

    const params = new URLSearchParams(window.location.search);
    if (params.get('setup') === 'complete') {
      checkStatus();
      showToast('Bank account setup complete! Checking verification status...', 'success');
      window.history.replaceState({}, '', window.location.pathname);
    }
    if (params.get('setup') === 'refresh') {
      handleSetup();
    }
  }, []);

  const checkStatus = async () => {
    setStatus('loading');
    try {
      const { data, error } = await supabase.functions.invoke(
        'check-express-account-status',
        { body: { picker_id: user?.id } }
      );
      if (error) throw error;
      setStatus(data.status === 'not_created' ? 'not_created' : data.is_verified ? 'verified' : 'pending');
      setRequirements(data.requirements || []);
    } catch (err: any) {
      console.error('Error checking account status:', err);
      setError('Could not check account status. Please try again.');
      setStatus('not_created');
    }
  };

  const handleSetup = async () => {
    setIsRedirecting(true);
    setError('');
    try {
      const { data, error } = await supabase.functions.invoke(
        'create-express-account',
        {
          body: {
            picker_id: user?.id,
            picker_email: user?.email,
            return_url: `${window.location.origin}${window.location.pathname}?setup=complete`,
            refresh_url: `${window.location.origin}${window.location.pathname}?setup=refresh`,
          },
        }
      );
      if (error) throw error;
      window.location.href = data.url;
    } catch (err: any) {
      console.error('Error starting bank setup:', err);
      setError('Failed to start bank setup. Please try again.');
      showToast('Failed to start bank setup. Please try again.', 'error');
      setIsRedirecting(false);
    }
  };

  const handleUpdateBankAccount = async () => {
    setIsRedirecting(true);
    setError('');
    try {
      const { data, error } = await supabase.functions.invoke(
        'create-express-account',
        {
          body: {
            picker_id: user?.id,
            picker_email: user?.email,
            return_url: `${window.location.origin}${window.location.pathname}?setup=complete`,
            refresh_url: `${window.location.origin}${window.location.pathname}?setup=refresh`,
          },
        }
      );
      if (error) throw error;
      window.location.href = data.url;
    } catch (err: any) {
      console.error('Error opening bank settings:', err);
      setError('Failed to open bank settings. Please try again.');
      showToast('Failed to open bank settings. Please try again.', 'error');
      setIsRedirecting(false);
    }
  };

  if (status === 'loading') {
    return (
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8">
        <div className="flex items-center justify-center">
          <Loader className="w-8 h-8 animate-spin text-blue-600" />
          <span className="ml-3 text-gray-600">Checking account status...</span>
        </div>
      </div>
    );
  }

  if (status === 'verified') {
    return (
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex items-start gap-3 mb-4">
          <div className="flex-shrink-0">
            <CheckCircle className="w-6 h-6 text-green-600" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-gray-900 mb-1">Bank account connected</h3>
            <p className="text-sm text-gray-600">
              Your bank account is verified and ready to receive payouts. Payments will be sent automatically after each delivery is confirmed.
            </p>
          </div>
        </div>

        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
          <div className="flex items-start gap-2">
            <DollarSign className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
            <div className="text-sm text-green-800">
              <p className="font-medium mb-1">How payouts work:</p>
              <ul className="list-disc list-inside space-y-1 text-green-700">
                <li>Payouts are sent automatically when collector confirms delivery</li>
                <li>A 10% platform fee is charged on all sales (you receive 90%)</li>
                <li>Funds arrive in your bank account within 2-7 business days</li>
                <li>You'll receive a notification when each payout is processed</li>
              </ul>
            </div>
          </div>
        </div>

        <button
          onClick={handleUpdateBankAccount}
          disabled={isRedirecting}
          className="flex items-center gap-2 text-sm text-blue-600 hover:text-blue-700 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isRedirecting ? (
            <>
              <Loader className="w-4 h-4 animate-spin" />
              Opening Stripe...
            </>
          ) : (
            <>
              <ExternalLink className="w-4 h-4" />
              Update bank account details
            </>
          )}
        </button>
      </div>
    );
  }

  if (status === 'pending') {
    return (
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex items-start gap-3 mb-4">
          <div className="flex-shrink-0">
            <AlertCircle className="w-6 h-6 text-amber-600" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-gray-900 mb-1">Verification in progress</h3>
            <p className="text-sm text-gray-600">
              Stripe is verifying your account information. This usually takes a few minutes.
            </p>
          </div>
        </div>

        {requirements.length > 0 && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
            <p className="text-sm font-medium text-red-800 mb-2">Action required:</p>
            <ul className="list-disc list-inside space-y-1 text-sm text-red-700">
              {requirements.map((req) => (
                <li key={req}>{req.replace(/_/g, ' ')}</li>
              ))}
            </ul>
          </div>
        )}

        <div className="flex gap-3">
          <button
            onClick={checkStatus}
            className="text-sm text-blue-600 hover:text-blue-700 font-medium"
          >
            Refresh status
          </button>
          <button
            onClick={handleUpdateBankAccount}
            disabled={isRedirecting}
            className="flex items-center gap-2 text-sm text-blue-600 hover:text-blue-700 font-medium disabled:opacity-50"
          >
            {isRedirecting ? (
              <>
                <Loader className="w-4 h-4 animate-spin" />
                Opening...
              </>
            ) : (
              <>
                <ExternalLink className="w-4 h-4" />
                Complete setup on Stripe
              </>
            )}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div className="mb-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Connect your bank account</h3>
        <p className="text-sm text-gray-600 mb-3">
          You will be securely redirected to Stripe to add your bank account details. This takes about 2 minutes.
        </p>
        <div className="bg-amber-50 border-l-4 border-amber-500 p-4 rounded">
          <div className="flex items-start gap-2">
            <AlertCircle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
            <p className="text-sm font-semibold text-amber-900">
              Required to receive earnings for goods sold. Without a connected bank account, you cannot receive payments from completed orders.
            </p>
          </div>
        </div>
      </div>

      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
        <ul className="space-y-2 text-sm text-blue-900">
          <li className="flex items-start gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-blue-600" />
            <span>Your bank details are handled securely by Stripe</span>
          </li>
          <li className="flex items-start gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-blue-600" />
            <span>Payouts arrive 2-7 business days after delivery confirmation</span>
          </li>
          <li className="flex items-start gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0 mt-0.5 text-blue-600" />
            <span>Automatic payouts after each completed order</span>
          </li>
        </ul>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
        <p className="text-sm text-amber-900">
          <span className="font-semibold">Platform Fee:</span> A 10% fee is charged on all sales. You receive 90% of each order amount.
        </p>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
          <p className="text-sm text-red-800">{error}</p>
        </div>
      )}

      <button
        onClick={handleSetup}
        disabled={isRedirecting}
        className="w-full bg-blue-600 text-white rounded-lg py-3 px-4 font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
      >
        {isRedirecting ? (
          <>
            <Loader className="w-5 h-5 animate-spin" />
            Redirecting to Stripe...
          </>
        ) : (
          <>
            <ExternalLink className="w-5 h-5" />
            Set up bank account with Stripe
          </>
        )}
      </button>

      <p className="text-xs text-gray-500 text-center mt-3">
        Powered by Stripe Connect
      </p>
    </div>
  );
}
