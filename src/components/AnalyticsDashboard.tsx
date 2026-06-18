import { useState, useEffect } from 'react';
import { TrendingUp, DollarSign, ShoppingBag, MessageSquare, Eye, Calendar, User, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { RevenueBoosters } from './RevenueBoosters';

type AnalyticsDashboardProps = {
  onViewChange?: (view: string) => void;
};

type DailyAnalytics = {
  date: string;
  views: number;
  messages: number;
  orders: number;
  revenue: number;
};

type ProfileViewer = {
  id: string;
  full_name: string;
  avatar_url?: string;
  viewed_at: string;
};

export function AnalyticsDashboard({ onViewChange }: AnalyticsDashboardProps) {
  const { profile } = useAuth();
  const [analytics, setAnalytics] = useState<DailyAnalytics[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'7' | '30' | '90'>('30');
  const [pickerId, setPickerId] = useState<string | null>(null);
  const [showViewersModal, setShowViewersModal] = useState(false);
  const [profileViewers, setProfileViewers] = useState<ProfileViewer[]>([]);
  const [loadingViewers, setLoadingViewers] = useState(false);

  useEffect(() => {
    loadPickerId();
  }, [profile]);

  useEffect(() => {
    if (pickerId) {
      loadAnalytics();
    }
  }, [pickerId, timeRange]);

  const loadPickerId = async () => {
    if (!profile || profile.user_type !== 'picker') return;

    try {
      const { data, error } = await supabase
        .from('picker_profiles')
        .select('id')
        .eq('user_id', profile.id)
        .maybeSingle();

      if (error) throw error;
      setPickerId(data?.id || null);
    } catch (error) {

    }
  };

  const loadAnalytics = async () => {
    if (!pickerId || !profile) return;

    try {
      const daysAgo = new Date();
      daysAgo.setDate(daysAgo.getDate() - parseInt(timeRange));

      // Get orders data grouped by date
      // Orders reference profiles.id directly for picker_id
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select('total_price, created_at, status')
        .eq('picker_id', profile.id)
        .gte('created_at', daysAgo.toISOString());

      if (ordersError) throw ordersError;

      // Get conversations where this user is the picker
      // Conversations reference profiles.id for picker_id
      const { data: conversationsData } = await supabase
        .from('conversations')
        .select('id')
        .eq('picker_id', profile.id);

      const conversationIds = conversationsData?.map(c => c.id) || [];

      // Get messages data for picker's conversations only
      const { data: messagesData, error: messagesError } = await supabase
        .from('conversation_messages')
        .select('created_at, conversation_id')
        .in('conversation_id', conversationIds.length > 0 ? conversationIds : [''])
        .gte('created_at', daysAgo.toISOString());

      if (messagesError) throw messagesError;

      const pickerMessages = messagesData || [];

      // Get profile views data
      // picker_profile_views uses picker_profiles.id for picker_id
      const { data: viewsData, error: viewsError } = await supabase
        .from('picker_profile_views')
        .select('created_at')
        .eq('picker_id', pickerId)
        .gte('created_at', daysAgo.toISOString());

      if (viewsError) {
        console.error('Error loading views:', viewsError);
      }

      console.log('Analytics Debug:', {
        userId: profile.id,
        pickerProfileId: pickerId,
        conversationIds,
        ordersCount: ordersData?.length || 0,
        messagesCount: pickerMessages?.length || 0,
        viewsCount: viewsData?.length || 0
      });

      // Group data by date
      const dateMap = new Map<string, DailyAnalytics>();

      // Initialize all dates in range
      for (let i = 0; i < parseInt(timeRange); i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        dateMap.set(dateStr, {
          date: dateStr,
          views: 0,
          messages: 0,
          orders: 0,
          revenue: 0
        });
      }

      // Aggregate orders
      ordersData?.forEach(order => {
        const dateStr = new Date(order.created_at).toISOString().split('T')[0];
        const dayData = dateMap.get(dateStr);
        if (dayData) {
          dayData.orders += 1;
          dayData.revenue += parseFloat(order.total_price.toString());
        }
      });

      // Aggregate messages
      pickerMessages.forEach(message => {
        const dateStr = new Date(message.created_at).toISOString().split('T')[0];
        const dayData = dateMap.get(dateStr);
        if (dayData) {
          dayData.messages += 1;
        }
      });

      // Aggregate views
      viewsData?.forEach(view => {
        const dateStr = new Date(view.created_at).toISOString().split('T')[0];
        const dayData = dateMap.get(dateStr);
        if (dayData) {
          dayData.views += 1;
        }
      });

      // Convert map to array and sort by date
      const analyticsArray = Array.from(dateMap.values()).sort((a, b) =>
        new Date(b.date).getTime() - new Date(a.date).getTime()
      );

      setAnalytics(analyticsArray);
    } catch (error) {
      console.error('Error loading analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  const totalViews = analytics.reduce((sum, day) => sum + day.views, 0);
  const totalMessages = analytics.reduce((sum, day) => sum + day.messages, 0);
  const totalOrders = analytics.reduce((sum, day) => sum + day.orders, 0);
  const totalRevenue = analytics.reduce((sum, day) => sum + day.revenue, 0);

  const avgViews = analytics.length > 0 ? Math.round(totalViews / analytics.length) : 0;
  const avgMessages = analytics.length > 0 ? Math.round(totalMessages / analytics.length) : 0;
  const avgOrders = analytics.length > 0 ? (totalOrders / analytics.length).toFixed(1) : '0';
  const avgRevenue = analytics.length > 0 ? (totalRevenue / analytics.length).toFixed(2) : '0';

  const loadProfileViewers = async () => {
    if (!pickerId) return;

    setLoadingViewers(true);
    try {
      const daysAgo = new Date();
      daysAgo.setDate(daysAgo.getDate() - parseInt(timeRange));

      const { data, error } = await supabase
        .from('picker_profile_views')
        .select(`
          viewer_id,
          created_at,
          viewer:profiles!picker_profile_views_viewer_id_fkey(
            id,
            full_name,
            avatar_url
          )
        `)
        .eq('picker_id', pickerId)
        .gte('created_at', daysAgo.toISOString())
        .order('created_at', { ascending: false });

      if (error) throw error;

      const viewers = data?.map((view: any) => ({
        id: view.viewer?.id || '',
        full_name: view.viewer?.full_name || 'Anonymous',
        avatar_url: view.viewer?.avatar_url,
        viewed_at: view.created_at
      })) || [];

      setProfileViewers(viewers);
      setShowViewersModal(true);
    } catch (error) {
      console.error('Error loading profile viewers:', error);
    } finally {
      setLoadingViewers(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto">
      <div className="mb-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-3">
            <TrendingUp className="w-6 h-6 text-blue-600" />
            <h2 className="text-2xl font-bold text-gray-900">Analytics Dashboard</h2>
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
      </div>

      <div className="mb-8">
        <RevenueBoosters onViewChange={onViewChange} compact={true} />
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <button
          onClick={loadProfileViewers}
          disabled={loadingViewers}
          className="bg-white rounded-2xl shadow-lg p-6 text-left hover:shadow-xl transition-shadow cursor-pointer disabled:opacity-50"
        >
          <div className="flex items-center justify-between mb-4">
            <div className="bg-blue-100 p-3 rounded-lg">
              <Eye className="w-6 h-6 text-blue-600" />
            </div>
          </div>
          <h3 className="text-gray-600 text-sm font-medium mb-1">Total Views</h3>
          <p className="text-3xl font-bold text-gray-900 mb-1">{totalViews}</p>
          <p className="text-sm text-gray-500">Avg {avgViews}/day</p>
          <p className="text-xs text-blue-600 mt-2 font-medium">
            {loadingViewers ? 'Loading...' : 'Click to see who viewed your profile'}
          </p>
        </button>

        <button
          onClick={() => onViewChange?.('messages')}
          className="bg-white rounded-2xl shadow-lg p-6 text-left hover:shadow-xl transition-shadow cursor-pointer"
        >
          <div className="flex items-center justify-between mb-4">
            <div className="bg-green-100 p-3 rounded-lg">
              <MessageSquare className="w-6 h-6 text-green-600" />
            </div>
          </div>
          <h3 className="text-gray-600 text-sm font-medium mb-1">Messages</h3>
          <p className="text-3xl font-bold text-gray-900 mb-1">{totalMessages}</p>
          <p className="text-sm text-gray-500">Avg {avgMessages}/day</p>
          <p className="text-xs text-green-600 mt-2 font-medium">Click to view messages</p>
        </button>

        <button
          onClick={() => onViewChange?.('orders')}
          className="bg-white rounded-2xl shadow-lg p-6 text-left hover:shadow-xl transition-shadow cursor-pointer"
        >
          <div className="flex items-center justify-between mb-4">
            <div className="bg-purple-100 p-3 rounded-lg">
              <ShoppingBag className="w-6 h-6 text-purple-600" />
            </div>
          </div>
          <h3 className="text-gray-600 text-sm font-medium mb-1">Orders</h3>
          <p className="text-3xl font-bold text-gray-900 mb-1">{totalOrders}</p>
          <p className="text-sm text-gray-500">Avg {avgOrders}/day</p>
          <p className="text-xs text-purple-600 mt-2 font-medium">Click to view orders</p>
        </button>

        <button
          onClick={() => onViewChange?.('earnings')}
          className="bg-white rounded-2xl shadow-lg p-6 text-left hover:shadow-xl transition-shadow cursor-pointer"
        >
          <div className="flex items-center justify-between mb-4">
            <div className="bg-yellow-100 p-3 rounded-lg">
              <DollarSign className="w-6 h-6 text-yellow-600" />
            </div>
          </div>
          <h3 className="text-gray-600 text-sm font-medium mb-1">Revenue</h3>
          <p className="text-3xl font-bold text-gray-900 mb-1">${totalRevenue.toFixed(2)}</p>
          <p className="text-sm text-gray-500">Avg ${avgRevenue}/day</p>
          <p className="text-xs text-yellow-600 mt-2 font-medium">Click to view earnings</p>
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-lg p-6">
        <h3 className="text-xl font-bold text-gray-900 mb-6 flex items-center gap-2">
          <Calendar className="w-5 h-5 text-blue-600" />
          Daily Breakdown
        </h3>
        {analytics.length === 0 ? (
          <div className="text-center py-12">
            <TrendingUp className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 text-lg">No analytics data yet</p>
            <p className="text-gray-400 text-sm">Data will appear as you receive views and orders</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b-2 border-gray-200">
                  <th className="text-left py-3 px-4 font-semibold text-gray-700">Date</th>
                  <th className="text-right py-3 px-4 font-semibold text-gray-700">Views</th>
                  <th className="text-right py-3 px-4 font-semibold text-gray-700">Messages</th>
                  <th className="text-right py-3 px-4 font-semibold text-gray-700">Orders</th>
                  <th className="text-right py-3 px-4 font-semibold text-gray-700">Revenue</th>
                </tr>
              </thead>
              <tbody>
                {analytics.map((day, index) => (
                  <tr key={`${day.date}-${index}`} className="border-b border-gray-100 hover:bg-gray-50">
                    <td className="py-3 px-4 text-gray-900">
                      {new Date(day.date).toLocaleDateString()}
                    </td>
                    <td className="py-3 px-4 text-right text-gray-700">{day.views}</td>
                    <td className="py-3 px-4 text-right text-gray-700">{day.messages}</td>
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

      {showViewersModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <div className="flex items-center gap-3">
                <div className="bg-blue-100 p-2 rounded-lg">
                  <Eye className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-gray-900">Profile Viewers</h3>
                  <p className="text-sm text-gray-600">
                    {profileViewers.length} {profileViewers.length === 1 ? 'person' : 'people'} viewed your profile
                  </p>
                </div>
              </div>
              <button
                onClick={() => setShowViewersModal(false)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="overflow-y-auto max-h-[calc(80vh-120px)] p-6">
              {profileViewers.length === 0 ? (
                <div className="text-center py-12">
                  <User className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                  <p className="text-gray-500 text-lg">No profile views yet</p>
                  <p className="text-gray-400 text-sm">Views will appear here when collectors visit your profile</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {profileViewers.map((viewer, index) => (
                    <div
                      key={`${viewer.id}-${index}`}
                      className="flex items-center gap-4 p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex-shrink-0">
                        {viewer.avatar_url ? (
                          <img
                            src={viewer.avatar_url}
                            alt={viewer.full_name}
                            className="w-12 h-12 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-12 h-12 rounded-full bg-blue-100 flex items-center justify-center">
                            <User className="w-6 h-6 text-blue-600" />
                          </div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold text-gray-900">{viewer.full_name}</p>
                        <p className="text-sm text-gray-600">
                          Viewed {new Date(viewer.viewed_at).toLocaleDateString()} at{' '}
                          {new Date(viewer.viewed_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
