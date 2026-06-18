import { useState, useEffect } from 'react';
import {
  Users,
  UserCheck,
  DollarSign,
  TrendingUp,
  Eye,
  ShoppingBag,
  Calendar,
  Activity,
  CreditCard,
  Globe
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type PlatformStats = {
  totalUsers: number;
  totalProfiles: number;
  completedProfiles: number;
  totalPickers: number;
  totalCollectors: number;
  activeSubscriptions: number;
  totalSubscriptionRevenue: number;
  totalOrders: number;
  totalOrderRevenue: number;
  totalListings: number;
  totalMessages: number;
};

type TimeSeriesData = {
  date: string;
  newUsers: number;
  newProfiles: number;
  revenue: number;
  orders: number;
};

export function AdminAnalyticsDashboard() {
  const { profile } = useAuth();
  const [stats, setStats] = useState<PlatformStats | null>(null);
  const [timeSeries, setTimeSeries] = useState<TimeSeriesData[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'7' | '30' | '90'>('30');
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    checkAdminAccess();
  }, [profile]);

  useEffect(() => {
    if (isAdmin) {
      loadAnalytics();
    }
  }, [isAdmin, timeRange]);

  const checkAdminAccess = async () => {
    if (!profile) return;

    const adminEmails = ['admin@souvenirpickers.com', profile.email];
    setIsAdmin(adminEmails.includes(profile.email || ''));
  };

  const loadAnalytics = async () => {
    setLoading(true);
    try {
      await Promise.all([
        loadPlatformStats(),
        loadTimeSeriesData()
      ]);
    } catch (error) {
      console.error('Error loading analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadPlatformStats = async () => {
    try {
      const [
        usersResult,
        profilesResult,
        pickersResult,
        collectorsResult,
        subscriptionsResult,
        ordersResult,
        listingsResult,
        messagesResult
      ] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('profiles').select('id, profile_completed', { count: 'exact' }),
        supabase.from('picker_profiles').select('id', { count: 'exact', head: true }),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('user_type', 'collector'),
        supabase.from('picker_subscriptions').select('id, status, amount_paid').eq('status', 'active'),
        supabase.from('orders').select('id, total_amount, status'),
        supabase.from('listings').select('id', { count: 'exact', head: true }),
        supabase.from('conversation_messages').select('id', { count: 'exact', head: true })
      ]);

      const completedProfiles = profilesResult.data?.filter(p => p.profile_completed).length || 0;
      const totalSubscriptionRevenue = subscriptionsResult.data?.reduce((sum, sub) => sum + (sub.amount_paid || 0), 0) || 0;
      const completedOrders = ordersResult.data?.filter(o => ['delivered', 'shipped'].includes(o.status)) || [];
      const totalOrderRevenue = completedOrders.reduce((sum, order) => sum + order.total_amount, 0);

      setStats({
        totalUsers: usersResult.count || 0,
        totalProfiles: profilesResult.data?.length || 0,
        completedProfiles,
        totalPickers: pickersResult.count || 0,
        totalCollectors: collectorsResult.count || 0,
        activeSubscriptions: subscriptionsResult.data?.length || 0,
        totalSubscriptionRevenue,
        totalOrders: ordersResult.data?.length || 0,
        totalOrderRevenue,
        totalListings: listingsResult.count || 0,
        totalMessages: messagesResult.count || 0
      });
    } catch (error) {
      console.error('Error loading platform stats:', error);
    }
  };

  const loadTimeSeriesData = async () => {
    try {
      const daysAgo = new Date();
      daysAgo.setDate(daysAgo.getDate() - parseInt(timeRange));

      const { data: profiles } = await supabase
        .from('profiles')
        .select('created_at')
        .gte('created_at', daysAgo.toISOString());

      const { data: orders } = await supabase
        .from('orders')
        .select('created_at, total_amount')
        .gte('created_at', daysAgo.toISOString());

      const dateMap = new Map<string, TimeSeriesData>();

      for (let i = parseInt(timeRange) - 1; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        dateMap.set(dateStr, {
          date: dateStr,
          newUsers: 0,
          newProfiles: 0,
          revenue: 0,
          orders: 0
        });
      }

      profiles?.forEach(profile => {
        const dateStr = profile.created_at.split('T')[0];
        const data = dateMap.get(dateStr);
        if (data) {
          data.newUsers++;
          data.newProfiles++;
        }
      });

      orders?.forEach(order => {
        const dateStr = order.created_at.split('T')[0];
        const data = dateMap.get(dateStr);
        if (data) {
          data.orders++;
          data.revenue += order.total_amount;
        }
      });

      setTimeSeries(Array.from(dateMap.values()));
    } catch (error) {
      console.error('Error loading time series:', error);
    }
  };

  if (!isAdmin) {
    return (
      <div className="max-w-7xl mx-auto p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-8 text-center">
          <Activity className="w-16 h-16 text-red-400 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-red-900 mb-2">Access Denied</h2>
          <p className="text-red-700">You do not have permission to view admin analytics.</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const profileCompletionRate = stats && stats.totalProfiles > 0
    ? ((stats.completedProfiles / stats.totalProfiles) * 100).toFixed(1)
    : '0';

  const totalRevenue = (stats?.totalSubscriptionRevenue || 0) + (stats?.totalOrderRevenue || 0);

  return (
    <div className="max-w-7xl mx-auto">
      <div className="mb-8">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <Activity className="w-8 h-8 text-blue-600" />
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Admin Analytics</h1>
              <p className="text-gray-600">Platform-wide performance metrics</p>
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setTimeRange('7')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                timeRange === '7'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              7 Days
            </button>
            <button
              onClick={() => setTimeRange('30')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                timeRange === '30'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              30 Days
            </button>
            <button
              onClick={() => setTimeRange('90')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                timeRange === '90'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              90 Days
            </button>
          </div>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl shadow-lg p-6 text-white">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-white/20 p-3 rounded-lg">
                <Users className="w-6 h-6" />
              </div>
            </div>
            <h3 className="text-white/90 text-sm font-medium mb-1">Total Users</h3>
            <p className="text-4xl font-bold mb-1">{stats?.totalUsers || 0}</p>
            <p className="text-white/80 text-sm">{stats?.totalPickers || 0} pickers, {stats?.totalCollectors || 0} collectors</p>
          </div>

          <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl shadow-lg p-6 text-white">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-white/20 p-3 rounded-lg">
                <UserCheck className="w-6 h-6" />
              </div>
            </div>
            <h3 className="text-white/90 text-sm font-medium mb-1">Profiles Completed</h3>
            <p className="text-4xl font-bold mb-1">{stats?.completedProfiles || 0}</p>
            <p className="text-white/80 text-sm">{profileCompletionRate}% completion rate</p>
          </div>

          <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-2xl shadow-lg p-6 text-white">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-white/20 p-3 rounded-lg">
                <CreditCard className="w-6 h-6" />
              </div>
            </div>
            <h3 className="text-white/90 text-sm font-medium mb-1">Active Subscriptions</h3>
            <p className="text-4xl font-bold mb-1">{stats?.activeSubscriptions || 0}</p>
            <p className="text-white/80 text-sm">${(stats?.totalSubscriptionRevenue || 0).toFixed(2)} total</p>
          </div>

          <div className="bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-2xl shadow-lg p-6 text-white">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-white/20 p-3 rounded-lg">
                <DollarSign className="w-6 h-6" />
              </div>
            </div>
            <h3 className="text-white/90 text-sm font-medium mb-1">Total Revenue</h3>
            <p className="text-4xl font-bold mb-1">${totalRevenue.toFixed(2)}</p>
            <p className="text-white/80 text-sm">Subscriptions + Orders</p>
          </div>
        </div>

        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white rounded-2xl shadow-lg p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="bg-blue-100 p-3 rounded-lg">
                <ShoppingBag className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <h3 className="text-gray-600 text-sm font-medium">Total Orders</h3>
                <p className="text-3xl font-bold text-gray-900">{stats?.totalOrders || 0}</p>
              </div>
            </div>
            <p className="text-gray-600 text-sm">${(stats?.totalOrderRevenue || 0).toFixed(2)} revenue</p>
          </div>

          <div className="bg-white rounded-2xl shadow-lg p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="bg-green-100 p-3 rounded-lg">
                <Globe className="w-6 h-6 text-green-600" />
              </div>
              <div>
                <h3 className="text-gray-600 text-sm font-medium">Active Listings</h3>
                <p className="text-3xl font-bold text-gray-900">{stats?.totalListings || 0}</p>
              </div>
            </div>
            <p className="text-gray-600 text-sm">Available souvenirs</p>
          </div>

          <div className="bg-white rounded-2xl shadow-lg p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="bg-orange-100 p-3 rounded-lg">
                <Eye className="w-6 h-6 text-orange-600" />
              </div>
              <div>
                <h3 className="text-gray-600 text-sm font-medium">Messages Sent</h3>
                <p className="text-3xl font-bold text-gray-900">{stats?.totalMessages || 0}</p>
              </div>
            </div>
            <p className="text-gray-600 text-sm">User engagement</p>
          </div>
        </div>

        <div className="bg-white rounded-2xl shadow-lg p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-blue-600" />
            Growth Trends ({timeRange} Days)
          </h3>
          {timeSeries.length === 0 ? (
            <div className="text-center py-12">
              <Calendar className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500 text-lg">No data available</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b-2 border-gray-200">
                    <th className="text-left py-3 px-4 font-semibold text-gray-700">Date</th>
                    <th className="text-right py-3 px-4 font-semibold text-gray-700">New Users</th>
                    <th className="text-right py-3 px-4 font-semibold text-gray-700">New Profiles</th>
                    <th className="text-right py-3 px-4 font-semibold text-gray-700">Orders</th>
                    <th className="text-right py-3 px-4 font-semibold text-gray-700">Revenue</th>
                  </tr>
                </thead>
                <tbody>
                  {timeSeries.map((day) => (
                    <tr key={day.date} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="py-3 px-4 text-gray-900">
                        {new Date(day.date).toLocaleDateString()}
                      </td>
                      <td className="py-3 px-4 text-right text-gray-700">{day.newUsers}</td>
                      <td className="py-3 px-4 text-right text-gray-700">{day.newProfiles}</td>
                      <td className="py-3 px-4 text-right text-gray-700">{day.orders}</td>
                      <td className="py-3 px-4 text-right font-semibold text-gray-900">
                        ${day.revenue.toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="bg-blue-50 border border-blue-200 rounded-2xl p-6 mt-8">
          <h3 className="text-lg font-bold text-blue-900 mb-3 flex items-center gap-2">
            <Globe className="w-5 h-5" />
            SEO & Marketing Insights
          </h3>
          <div className="grid md:grid-cols-2 gap-4 text-sm">
            <div>
              <p className="text-blue-800 font-medium mb-1">User Acquisition</p>
              <p className="text-blue-700">Track signup sources in Google Analytics</p>
            </div>
            <div>
              <p className="text-blue-800 font-medium mb-1">Conversion Rate</p>
              <p className="text-blue-700">
                {stats && stats.totalUsers > 0
                  ? ((stats.totalOrders / stats.totalUsers) * 100).toFixed(2)
                  : '0'}% of users place orders
              </p>
            </div>
            <div>
              <p className="text-blue-800 font-medium mb-1">Average Order Value</p>
              <p className="text-blue-700">
                ${stats && stats.totalOrders > 0
                  ? ((stats.totalOrderRevenue || 0) / stats.totalOrders).toFixed(2)
                  : '0.00'}
              </p>
            </div>
            <div>
              <p className="text-blue-800 font-medium mb-1">Active Picker Rate</p>
              <p className="text-blue-700">
                {stats && stats.totalPickers > 0
                  ? ((stats.activeSubscriptions / stats.totalPickers) * 100).toFixed(1)
                  : '0'}% subscribed
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
