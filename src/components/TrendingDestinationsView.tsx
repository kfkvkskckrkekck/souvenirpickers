import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { TrendingUp, MapPin, Package, Heart, Users, Loader, RefreshCw, Sparkles } from 'lucide-react';

interface TrendingDestination {
  id: string;
  location_name: string;
  country: string;
  listing_count: number;
  desire_count: number;
  picker_count: number;
  order_count: number;
  trend_score: number;
  updated_at: string;
}

type TrendingDestinationsViewProps = {
  onViewChange?: (view: string) => void;
};

export default function TrendingDestinationsView({ onViewChange }: TrendingDestinationsViewProps) {
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [destinations, setDestinations] = useState<TrendingDestination[]>([]);

  useEffect(() => {
    loadTrendingDestinations();
    refreshTrending();
  }, []);

  const loadTrendingDestinations = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('trending_destinations')
        .select('*')
        .order('trend_score', { ascending: false })
        .limit(20);

      if (error) throw error;
      setDestinations(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const refreshTrending = async () => {
    try {
      setRefreshing(true);
      await supabase.rpc('update_trending_destinations');
      await loadTrendingDestinations();
    } catch (error) {

    } finally {
      setRefreshing(false);
    }
  };

  const getTrendBadge = (score: number) => {
    if (score >= 500) return { text: 'On Fire', color: 'bg-red-100 text-red-800 border-red-300' };
    if (score >= 300) return { text: 'Very Hot', color: 'bg-orange-100 text-orange-800 border-orange-300' };
    if (score >= 150) return { text: 'Hot', color: 'bg-yellow-100 text-yellow-800 border-yellow-300' };
    return { text: 'Trending', color: 'bg-blue-100 text-blue-800 border-blue-300' };
  };

  const exploreLocation = (location: string) => {
    onViewChange?.('listings');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader className="w-8 h-8 animate-spin text-green-600" />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
            <TrendingUp className="w-8 h-8 text-green-600" />
            Trending Destinations
          </h1>
          <p className="text-gray-600">Discover the hottest souvenir destinations based on real-time activity</p>
        </div>
        <button
          onClick={refreshTrending}
          disabled={refreshing}
          className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium flex items-center gap-2 disabled:opacity-50"
        >
          <RefreshCw className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      <div className="mb-8 bg-gradient-to-r from-green-50 to-blue-50 rounded-xl p-6 border-2 border-green-200">
        <div className="flex items-start gap-4">
          <div className="bg-green-600 p-3 rounded-lg flex-shrink-0">
            <Sparkles className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">How Trending Works</h3>
            <p className="text-gray-700 mb-3">
              Destinations are ranked based on recent activity from the last 90 days. Each factor contributes to the overall trend score:
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="bg-white rounded-lg p-3 border border-green-200">
                <div className="flex items-center gap-2 mb-1">
                  <Package className="w-5 h-5 text-green-600" />
                  <span className="font-semibold text-gray-900">Active Listings</span>
                </div>
                <p className="text-sm text-gray-600">10 points each - Shows picker activity</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-red-200">
                <div className="flex items-center gap-2 mb-1">
                  <Heart className="w-5 h-5 text-red-600" />
                  <span className="font-semibold text-gray-900">Collector Desires</span>
                </div>
                <p className="text-sm text-gray-600">15 points each - Demand indicator</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <div className="flex items-center gap-2 mb-1">
                  <Users className="w-5 h-5 text-blue-600" />
                  <span className="font-semibold text-gray-900">Active Pickers</span>
                </div>
                <p className="text-sm text-gray-600">5 points each - Supply indicator</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-orange-200">
                <div className="flex items-center gap-2 mb-1">
                  <TrendingUp className="w-5 h-5 text-orange-600" />
                  <span className="font-semibold text-gray-900">Completed Orders</span>
                </div>
                <p className="text-sm text-gray-600">20 points each - Proven demand</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {destinations.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12">
          <div className="max-w-2xl mx-auto text-center">
            <MapPin className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-3">No Trending Destinations Yet</h3>

            <div className="text-left bg-gray-50 rounded-lg p-6 mb-6">
              <h4 className="font-semibold text-gray-900 mb-3">Why you might not see any destinations:</h4>
              <ul className="space-y-3 text-gray-700">
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-gray-400 text-white rounded-full flex items-center justify-center text-sm">1</div>
                  <span>The platform is new and building up initial activity</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-gray-400 text-white rounded-full flex items-center justify-center text-sm">2</div>
                  <span>Not enough pickers have created listings yet</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-gray-400 text-white rounded-full flex items-center justify-center text-sm">3</div>
                  <span>Not enough collectors have created desires</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-gray-400 text-white rounded-full flex items-center justify-center text-sm">4</div>
                  <span>No orders have been completed in the last 90 days</span>
                </li>
              </ul>

              <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <p className="text-sm text-blue-800">
                  <strong>Help build the trending list!</strong> Browse existing listings, create desires for places you want souvenirs from,
                  or if you're a picker, add listings for your current location. As activity grows, you'll see trending destinations appear here.
                </p>
              </div>
            </div>

            <div className="flex gap-3 justify-center relative z-10">
              <button
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  if (onViewChange) {
                    onViewChange('listings');
                  }
                }}
                type="button"
                className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium inline-flex items-center gap-2 cursor-pointer"
              >
                <Package className="w-5 h-5" />
                Browse Listings
              </button>
              <button
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  if (onViewChange) {
                    onViewChange('desires');
                  }
                }}
                type="button"
                className="px-6 py-3 border-2 border-green-600 text-green-600 rounded-lg hover:bg-green-50 transition-colors font-medium inline-flex items-center gap-2 cursor-pointer"
              >
                <Heart className="w-5 h-5" />
                Create Desire
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {destinations.map((destination, index) => {
            const badge = getTrendBadge(destination.trend_score);
            return (
              <div
                key={destination.id}
                className="bg-white rounded-xl shadow-sm border-2 border-gray-200 hover:border-green-300 hover:shadow-md transition-all p-6 relative overflow-hidden"
              >
                {index < 3 && (
                  <div className="absolute top-0 right-0 bg-gradient-to-br from-yellow-400 to-orange-500 text-white text-xs font-bold px-3 py-1 rounded-bl-lg">
                    #{index + 1}
                  </div>
                )}

                <div className="mb-4">
                  <div className="flex items-start justify-between mb-2">
                    <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                      <MapPin className="w-5 h-5 text-green-600" />
                      {destination.location_name}
                    </h3>
                  </div>
                  <div className={`inline-flex items-center gap-1 px-2 py-1 rounded-full border text-xs font-semibold ${badge.color}`}>
                    <TrendingUp className="w-3 h-3" />
                    {badge.text}
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4 mb-6">
                  <div className="bg-green-50 rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <Package className="w-4 h-4 text-green-600" />
                      <span className="text-xs text-gray-600">Listings</span>
                    </div>
                    <p className="text-2xl font-bold text-gray-900">{destination.listing_count}</p>
                  </div>

                  <div className="bg-red-50 rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <Heart className="w-4 h-4 text-red-600" />
                      <span className="text-xs text-gray-600">Desires</span>
                    </div>
                    <p className="text-2xl font-bold text-gray-900">{destination.desire_count}</p>
                  </div>

                  <div className="bg-blue-50 rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <Users className="w-4 h-4 text-blue-600" />
                      <span className="text-xs text-gray-600">Pickers</span>
                    </div>
                    <p className="text-2xl font-bold text-gray-900">{destination.picker_count}</p>
                  </div>

                  <div className="bg-orange-50 rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <TrendingUp className="w-4 h-4 text-orange-600" />
                      <span className="text-xs text-gray-600">Orders</span>
                    </div>
                    <p className="text-2xl font-bold text-gray-900">{destination.order_count}</p>
                  </div>
                </div>

                <div className="mb-4">
                  <div className="flex items-center justify-between text-sm mb-1">
                    <span className="text-gray-600">Trend Score</span>
                    <span className="font-bold text-gray-900">{destination.trend_score}</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div
                      className="bg-gradient-to-r from-green-500 to-blue-500 h-2 rounded-full transition-all"
                      style={{ width: `${Math.min((destination.trend_score / 1000) * 100, 100)}%` }}
                    />
                  </div>
                </div>

                <button
                  onClick={() => exploreLocation(destination.location_name)}
                  className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium"
                >
                  Explore {destination.location_name}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
