import { useState, useEffect } from 'react';
import { MessageCircle, MapPin, Star, Package, Search, Filter, X } from 'lucide-react';
import { supabase, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { getOrCreateConversation } from '../lib/conversations';
import SouvenirLoader from './SouvenirLoader';

type CollectorsViewProps = {
  onViewChange: (view: string, pickerId?: string) => void;
};

type CollectorWithStats = Profile & {
  totalOrders?: number;
  avgRating?: number;
  totalSpent?: number;
};

export function CollectorsView({ onViewChange }: CollectorsViewProps) {
  const { profile } = useAuth();
  const [collectors, setCollectors] = useState<CollectorWithStats[]>([]);
  const [filteredCollectors, setFilteredCollectors] = useState<CollectorWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [locationFilter, setLocationFilter] = useState('');
  const [minOrders, setMinOrders] = useState('');
  const [minRating, setMinRating] = useState('');
  const [sortBy, setSortBy] = useState('recent');
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    loadCollectors();
  }, []);

  const loadCollectors = async () => {
    try {
      const { data: collectorsData, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_type', 'client')
        .order('created_at', { ascending: false });

      if (error) throw error;

      const collectorsWithStats = await Promise.all(
        (collectorsData || []).map(async (collector) => {
          const { count: orderCount } = await supabase
            .from('orders')
            .select('*', { count: 'exact', head: true })
            .eq('client_id', collector.id);

          const { data: orders } = await supabase
            .from('orders')
            .select('total_amount')
            .eq('client_id', collector.id);

          const totalSpent = orders?.reduce((sum, order) => sum + (order.total_amount || 0), 0) || 0;

          const { data: reviews } = await supabase
            .from('reviews')
            .select('rating')
            .eq('reviewer_id', collector.id);

          const avgRating = reviews && reviews.length > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length
            : 0;

          return {
            ...collector,
            totalOrders: orderCount || 0,
            avgRating,
            totalSpent,
          };
        })
      );

      setCollectors(collectorsWithStats);
      setFilteredCollectors(collectorsWithStats);
    } catch (error) {
      console.error('Error loading collectors:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleContactCollector = async (collectorId: string) => {
    if (!profile) return;

    try {
      const conversationId = await getOrCreateConversation(collectorId, profile.id);
      onViewChange('messages', collectorId);
    } catch (error) {
      console.error('Error creating conversation:', error);
    }
  };

  const handleSearch = () => {
    let filtered = collectors.filter((collector) => {
      const matchesSearch =
        collector.full_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        collector.bio?.toLowerCase().includes(searchQuery.toLowerCase());

      const matchesLocation = !locationFilter ||
        collector.location?.toLowerCase().includes(locationFilter.toLowerCase());

      const matchesMinOrders = !minOrders ||
        (collector.totalOrders || 0) >= parseInt(minOrders);

      const matchesMinRating = !minRating ||
        (collector.avgRating || 0) >= parseFloat(minRating);

      return matchesSearch && matchesLocation && matchesMinOrders && matchesMinRating;
    });

    // Apply sorting
    if (sortBy === 'orders-high') {
      filtered.sort((a, b) => (b.totalOrders || 0) - (a.totalOrders || 0));
    } else if (sortBy === 'rating-high') {
      filtered.sort((a, b) => (b.avgRating || 0) - (a.avgRating || 0));
    } else if (sortBy === 'spent-high') {
      filtered.sort((a, b) => (b.totalSpent || 0) - (a.totalSpent || 0));
    } else {
      // Recent (default)
      filtered.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    }

    setFilteredCollectors(filtered);
  };

  const clearFilters = () => {
    setSearchQuery('');
    setLocationFilter('');
    setMinOrders('');
    setMinRating('');
    setSortBy('recent');
    setFilteredCollectors(collectors);
  };

  const allLocations = Array.from(
    new Set(collectors.map(c => c.location).filter(Boolean))
  ).sort();

  const activeFiltersCount = [
    searchQuery,
    locationFilter,
    minOrders,
    minRating,
    sortBy !== 'recent'
  ].filter(Boolean).length;

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading collectors..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Browse Collectors</h1>
        <p className="text-gray-600">Connect with collectors looking for souvenirs</p>
      </div>

      <div className="bg-white rounded-2xl shadow-lg p-6 mb-8">
        <div className="space-y-4">
          <div className="flex gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search collectors by name or interests..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="px-6 py-3 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors flex items-center gap-2 relative"
            >
              <Filter className="w-5 h-5" />
              <span className="hidden sm:inline">Filters</span>
              {activeFiltersCount > 0 && (
                <span className="absolute -top-2 -right-2 bg-blue-600 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                  {activeFiltersCount}
                </span>
              )}
            </button>
            <button
              onClick={handleSearch}
              className="px-8 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium flex items-center gap-2"
            >
              <Search className="w-5 h-5" />
              <span>Search</span>
            </button>
          </div>

          {showFilters && (
            <div className="pt-4 border-t border-gray-200">
              <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Location
                  </label>
                  <select
                    value={locationFilter}
                    onChange={(e) => setLocationFilter(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="">All Locations</option>
                    {allLocations.map((location) => (
                      <option key={location} value={location}>
                        {location}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Minimum Orders
                  </label>
                  <select
                    value={minOrders}
                    onChange={(e) => setMinOrders(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="">Any</option>
                    <option value="1">1+ Orders</option>
                    <option value="5">5+ Orders</option>
                    <option value="10">10+ Orders</option>
                    <option value="20">20+ Orders</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Minimum Rating
                  </label>
                  <select
                    value={minRating}
                    onChange={(e) => setMinRating(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="">Any Rating</option>
                    <option value="4.5">4.5+ Stars</option>
                    <option value="4.0">4.0+ Stars</option>
                    <option value="3.5">3.5+ Stars</option>
                    <option value="3.0">3.0+ Stars</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Sort By
                  </label>
                  <select
                    value={sortBy}
                    onChange={(e) => setSortBy(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="recent">Most Recent</option>
                    <option value="orders-high">Most Orders</option>
                    <option value="rating-high">Highest Rating</option>
                    <option value="spent-high">Highest Spending</option>
                  </select>
                </div>
              </div>

              {activeFiltersCount > 0 && (
                <div className="flex justify-end">
                  <button
                    onClick={clearFilters}
                    className="text-sm text-gray-600 hover:text-gray-800 flex items-center gap-1"
                  >
                    <X className="w-4 h-4" />
                    Clear all filters
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {filteredCollectors.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center">
          <Package className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-2">No collectors found</h3>
          <p className="text-gray-600">Try adjusting your search or filters</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredCollectors.map((collector) => (
            <div
              key={collector.id}
              className="group bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300 overflow-hidden h-full flex flex-col"
            >
              <div className="p-5 flex flex-col flex-1">
                <div className="flex items-center gap-3 mb-3">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-emerald-500 flex items-center justify-center text-white font-bold text-lg flex-shrink-0 shadow-sm">
                    {collector.full_name?.charAt(0).toUpperCase() || 'C'}
                  </div>
                  <div className="min-w-0">
                    <h3 className="font-bold text-gray-900 tracking-tight truncate">
                      {collector.full_name || 'Anonymous'}
                    </h3>
                    <div className="flex items-center gap-1 text-xs text-gray-500 mt-0.5">
                      <MapPin className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{collector.location || 'Location not set'}</span>
                    </div>
                  </div>
                </div>

                {collector.bio ? (
                  <p className="text-sm text-gray-500 mb-3.5 line-clamp-2 leading-relaxed">
                    {collector.bio}
                  </p>
                ) : (
                  <p className="text-sm text-gray-300 italic mb-3.5">No bio yet</p>
                )}

                <div className="flex flex-wrap items-center gap-2 mb-4">
                  <span className="inline-flex items-center gap-1.5 bg-blue-50 text-blue-700 text-xs font-semibold px-2.5 py-1 rounded-full">
                    <Package className="w-3.5 h-3.5" />
                    {collector.totalOrders || 0} orders
                  </span>
                  {collector.avgRating && collector.avgRating > 0 ? (
                    <span className="inline-flex items-center gap-1.5 bg-amber-50 text-amber-700 text-xs font-semibold px-2.5 py-1 rounded-full">
                      <Star className="w-3.5 h-3.5 fill-amber-500 text-amber-500" />
                      {collector.avgRating.toFixed(1)}
                    </span>
                  ) : (
                    <span className="text-xs font-medium text-gray-400">No reviews yet</span>
                  )}
                  {collector.totalSpent > 0 && (
                    <span className="inline-flex items-center gap-1.5 bg-emerald-50 text-emerald-700 text-xs font-semibold px-2.5 py-1 rounded-full">
                      €{collector.totalSpent.toFixed(2)} spent
                    </span>
                  )}
                </div>

                <button
                  onClick={() => handleContactCollector(collector.id)}
                  className="mt-auto w-full bg-blue-600 hover:bg-blue-700 text-white py-2.5 px-4 rounded-xl font-semibold text-sm shadow-sm hover:shadow-md transition-all flex items-center justify-center gap-2"
                >
                  <MessageCircle className="w-4 h-4" />
                  Contact Collector
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
