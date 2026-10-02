import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { DollarSign, TrendingUp, Clock, Calendar, Download, Info, Shield, Zap } from 'lucide-react';
import { PayoutSetup } from './PayoutSetup';
import SouvenirLoader from './SouvenirLoader';

export default function EarningsView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [earnings, setEarnings] = useState<any>(null);
  const [payouts, setPayouts] = useState<any[]>([]);
  const [stripeAccount, setStripeAccount] = useState<any>(null);
  const [payoutInfo, setPayoutInfo] = useState<any>(null);
  const [timeframe, setTimeframe] = useState<'week' | 'month' | 'all'>('month');
  const [accountVerified, setAccountVerified] = useState(false);
  const [checkingVerification, setCheckingVerification] = useState(true);

  useEffect(() => {
    if (user) {
      loadData();
    }
  }, [user, timeframe]);

  const loadData = async () => {
    try {
      setLoading(true);
      setCheckingVerification(true);

      const [earningsRes, payoutInfoRes] = await Promise.all([
        // picker_earnings has one row PER ORDER, not one aggregate row per
        // picker - fetch them all and roll up the totals here.
        supabase
          .from('picker_earnings')
          .select('*')
          .eq('picker_id', user?.id)
          .order('created_at', { ascending: false }),
        supabase
          .from('picker_payout_info')
          .select('*')
          .eq('picker_id', user?.id)
          .maybeSingle(),
      ]);

      if (earningsRes.error) throw earningsRes.error;
      if (payoutInfoRes.error && payoutInfoRes.error.code !== 'PGRST116') throw payoutInfoRes.error;

      const cutoff = timeframe === 'all' ? null : new Date();
      if (cutoff) cutoff.setDate(cutoff.getDate() - (timeframe === 'week' ? 7 : 30));
      const allRows = earningsRes.data || [];
      const rows = cutoff ? allRows.filter((r) => new Date(r.created_at) >= cutoff) : allRows;

      const rowTotal = (row: any) => Number(row.net_amount || 0) + Number(row.shipping_amount || 0);
      const paidRows = rows.filter((r) => r.status === 'paid');
      const pendingRows = rows.filter((r) => r.status !== 'paid');
      const lastPayoutAt = paidRows.reduce<string | null>(
        (latest, r) => (r.paid_at && (!latest || r.paid_at > latest) ? r.paid_at : latest),
        null
      );

      setEarnings({
        total_earned: rows.reduce((sum, r) => sum + rowTotal(r), 0),
        pending_payout: pendingRows.reduce((sum, r) => sum + rowTotal(r), 0),
        total_paid_out: paidRows.reduce((sum, r) => sum + rowTotal(r), 0),
        last_payout_at: lastPayoutAt,
      });
      setPayouts(
        paidRows.map((r) => ({
          id: r.id,
          created_at: r.created_at,
          order_id: r.order_id,
          amount: rowTotal(r),
          status: 'paid',
          arrival_date: r.paid_at,
        }))
      );
      setPayoutInfo(payoutInfoRes.data);

      // If there's a stripe_account_id, check if it's verified
      if (payoutInfoRes.data?.stripe_account_id) {
        setStripeAccount(payoutInfoRes.data);

        // Check verification status with Stripe
        try {
          const { data: statusData, error: statusError } = await supabase.functions.invoke(
            'check-express-account-status',
            { body: { picker_id: user?.id } }
          );

          if (!statusError && statusData) {
            setAccountVerified(statusData.is_verified || false);
          }
        } catch (err) {
          console.error('Error checking verification status:', err);
        }
      } else {
        setStripeAccount(null);
        setAccountVerified(false);
      }
    } catch (error) {

    } finally {
      setLoading(false);
      setCheckingVerification(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'EUR',
    }).format(amount || 0);
  };

  const formatDate = (date: string) => {
    return new Date(date).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getStatusColor = (status: string) => {
    const colors = {
      pending: 'bg-yellow-100 text-yellow-800',
      in_transit: 'bg-blue-100 text-blue-800',
      paid: 'bg-green-100 text-green-800',
      failed: 'bg-red-100 text-red-800',
      cancelled: 'bg-gray-100 text-gray-800',
    };
    return colors[status as keyof typeof colors] || 'bg-gray-100 text-gray-800';
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading earnings..." />
      </div>
    );
  }

  // Show setup if no account exists OR if account is not verified
  if (!stripeAccount || !accountVerified) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Earnings & Payouts</h1>
          <p className="text-gray-600">
            {!stripeAccount
              ? 'Set up your payout account to start receiving payments'
              : 'Complete your bank account setup to receive payments'}
          </p>
        </div>
        <PayoutSetup />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Earnings & Payouts</h1>
        <p className="text-gray-600">Track your earnings and payout history</p>
      </div>

      <div className="mb-8 bg-gradient-to-r from-green-50 to-blue-50 rounded-2xl p-6 border-2 border-green-200">
        <div className="flex items-start gap-4">
          <div className="bg-green-600 p-3 rounded-lg flex-shrink-0">
            <Info className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-gray-900 mb-3">
              Your Earnings Dashboard
            </h3>
            <div className="space-y-3 text-gray-700">
              <p className="flex items-start gap-2">
                <DollarSign className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
                <span>
                  <strong>Earn from every completed order:</strong> When collectors purchase your items, payment goes into escrow. Shipping costs are released immediately when you ship. Item earnings are released when the collector confirms delivery or automatically after 14 days.
                </span>
              </p>
              <p className="flex items-start gap-2">
                <Shield className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
                <span>
                  <strong>Protected by escrow:</strong> All transactions are secured through our escrow system. This protects both you and collectors - you're guaranteed payment after delivery, and collectors are protected until they receive their items.
                </span>
              </p>
              <p className="flex items-start gap-2">
                <Zap className="w-5 h-5 text-orange-600 mt-0.5 flex-shrink-0" />
                <span>
                  <strong>Automatic payouts:</strong> Once funds are in your available balance, payouts are processed automatically to your connected bank account. Funds typically arrive within 2-3 business days. A 10% platform fee is deducted from each transaction.
                </span>
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-6 mb-6">
        <div className="flex items-start gap-4">
          <Zap className="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" />
          <div>
            <h3 className="font-bold text-gray-900 mb-2">Split Payment System</h3>
            <p className="text-sm text-gray-700 leading-relaxed">
              When collectors pay, <strong>shipping costs are transferred to you immediately</strong> so you can cover courier expenses.
              Product earnings are held in escrow and released automatically when the collector confirms delivery.
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 text-white shadow-lg">
          <div className="flex items-center gap-3 mb-2">
            <DollarSign className="w-5 h-5" />
            <p className="text-green-100 text-sm font-medium">Total Earned</p>
          </div>
          <p className="text-3xl font-bold">{formatCurrency(earnings?.total_earned || 0)}</p>
          <p className="text-green-100 text-xs mt-1">Lifetime earnings</p>
        </div>

        <div className="bg-white rounded-xl p-6 border border-gray-200 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <Clock className="w-5 h-5 text-yellow-600" />
            <p className="text-gray-600 text-sm font-medium">Pending Payout</p>
          </div>
          <p className="text-3xl font-bold text-gray-900">{formatCurrency(earnings?.pending_payout || 0)}</p>
          <p className="text-gray-500 text-xs mt-1">In escrow or processing</p>
        </div>

        <div className="bg-white rounded-xl p-6 border border-gray-200 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <TrendingUp className="w-5 h-5 text-blue-600" />
            <p className="text-gray-600 text-sm font-medium">Paid Out</p>
          </div>
          <p className="text-3xl font-bold text-gray-900">{formatCurrency(earnings?.total_paid_out || 0)}</p>
          <p className="text-gray-500 text-xs mt-1">
            {earnings?.last_payout_at ? `Last: ${formatDate(earnings.last_payout_at)}` : 'No payouts yet'}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold text-gray-900">Payout History</h2>
            <div className="flex items-center gap-2">
              <select
                value={timeframe}
                onChange={(e) => setTimeframe(e.target.value as any)}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
              >
                <option value="week">Last Week</option>
                <option value="month">Last Month</option>
                <option value="all">All Time</option>
              </select>
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          {payouts.length === 0 ? (
            <div className="p-12 text-center">
              <DollarSign className="w-12 h-12 text-gray-300 mx-auto mb-3" />
              <p className="text-gray-500 font-medium text-lg mb-2">No payouts yet</p>
              <p className="text-sm text-gray-500 mt-2 max-w-md mx-auto">
                Payouts will appear here once you ship orders (shipping costs) or when collectors confirm delivery (item earnings). Item earnings auto-release after 14 days if not confirmed.
              </p>
              <div className="mt-6 pt-6 border-t border-gray-200">
                <p className="text-sm text-gray-600 font-medium mb-3">Start earning by:</p>
                <div className="flex flex-col sm:flex-row gap-3 justify-center items-center">
                  <div className="bg-blue-50 px-4 py-2 rounded-lg text-sm text-blue-700">
                    Creating listings for collectors
                  </div>
                  <div className="bg-green-50 px-4 py-2 rounded-lg text-sm text-green-700">
                    Sending custom orders via messages
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Order ID
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Arrival Date
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {payouts.map((payout) => (
                  <tr key={payout.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div className="flex items-center gap-2">
                        <Calendar className="w-4 h-4 text-gray-400" />
                        {formatDate(payout.created_at)}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      {payout.order_id?.slice(0, 8)}...
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900">
                      {formatCurrency(payout.amount)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(payout.status)}`}>
                        {payout.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-600">
                      {payout.arrival_date ? formatDate(payout.arrival_date) : payout.paid_at ? formatDate(payout.paid_at) : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 className="font-semibold text-blue-900 mb-2 flex items-center gap-2">
          <Download className="w-5 h-5" />
          How Payouts Work
        </h3>
        <ul className="text-sm text-blue-800 space-y-1">
          <li>• When a collector pays for an order, funds are held in escrow</li>
          <li>• When you ship the order, shipping costs are released immediately</li>
          <li>• Item earnings release when collector confirms OR automatically after 14 days</li>
          <li>• Payouts are processed automatically and arrive in 2-3 business days</li>
          <li>• A 10% platform fee is deducted from each transaction</li>
        </ul>
      </div>
    </div>
  );
}
