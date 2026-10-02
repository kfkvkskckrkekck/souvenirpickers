import { useState, useEffect } from 'react';
import { Search, Filter, Heart, MapPin, Star, TrendingUp, X, MessageCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { addToWishlist, removeFromWishlist, isInWishlist } from '../lib/wishlist';
import { recordListingView } from '../lib/search';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

type DiscoverViewProps = {
  onViewChange: (view: string, listingId?: string) => void;
};

interface SearchFilters {
  category?: string;
  region?: string;
  minPrice?: number;
  maxPrice?: number;
}

export function DiscoverView({ onViewChange }: DiscoverViewProps) {
  const { user } = useAuth();
  const [searchQuery, setSearchQuery] = useState('');
  const [filters, setFilters] = useState<SearchFilters>({});
  const [listings, setListings] = useState<any[]>([]);
  const [trendingListings, setTrendingListings] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [categories, setCategories] = useState<string[]>([]);
  const [regions, setRegions] = useState<string[]>([]);
  const [wishlistStatus, setWishlistStatus] = useState<Record<string, boolean>>({});

  useEffect(() => {
    loadInitialData();
  }, []);

  async function loadInitialData() {
    setLoading(true);
    try {
      // Load all available listings
      const { data: allListings, error } = await supabase
        .from('listings')
        .select(`
          *,
          picker:profiles!listings_picker_id_fkey(
            id,
            full_name,
            avatar_url,
            trust_score
          )
        `)
        .eq('available', true)
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;

      const listings = allListings || [];
      setTrendingListings(listings);
      setListings(listings);

      // Extract unique categories and regions
      const cats = [...new Set(listings.map((l: any) => l.category).filter(Boolean))].sort();
      const regs = [...new Set(listings.map((l: any) => l.region).filter(Boolean))].sort();
      setCategories(cats);
      setRegions(regs);

      if (user) {
        const statuses: Record<string, boolean> = {};
        for (const listing of listings) {
          statuses[listing.id] = await isInWishlist(listing.id);
        }
        setWishlistStatus(statuses);
      }
    } catch (error) {
      console.error('Error loading listings:', error);
    } finally {
      setLoading(false);
    }
  }

  async function handleSearch() {
    if (!searchQuery && !filters.category && !filters.region && !filters.minPrice && !filters.maxPrice) {
      await loadInitialData();
      return;
    }

    setLoading(true);
    try {
      // Build query
      let query = supabase
        .from('listings')
        .select(`
          *,
          picker:profiles!listings_picker_id_fkey(
            id,
            full_name,
            avatar_url,
            trust_score
          )
        `)
        .eq('available', true);

      // Apply text search
      if (searchQuery && searchQuery.trim()) {
        const term = `%${searchQuery.trim()}%`;
        query = query.or(`title.ilike.${term},description.ilike.${term},category.ilike.${term},region.ilike.${term}`);
      }

      // Apply category filter
      if (filters.category) {
        query = query.eq('category', filters.category);
      }

      // Apply region filter
      if (filters.region) {
        query = query.eq('region', filters.region);
      }

      // Apply price filters
      if (filters.minPrice !== undefined) {
        query = query.gte('price', filters.minPrice);
      }

      if (filters.maxPrice !== undefined) {
        query = query.lte('price', filters.maxPrice);
      }

      query = query.order('created_at', { ascending: false });

      const { data: results, error } = await query;

      if (error) throw error;

      setListings(results || []);

      if (user) {
        const statuses: Record<string, boolean> = {};
        for (const listing of (results || [])) {
          statuses[listing.id] = await isInWishlist(listing.id);
        }
        setWishlistStatus(statuses);
      }
    } catch (error) {
      console.error('Search error:', error);
    } finally {
      setLoading(false);
    }
  }

  async function toggleWishlist(listingId: string, event: React.MouseEvent) {
    event.stopPropagation();

    if (!user) {
      alert('Please log in to save items to your wishlist');
      return;
    }

    try {
      const isCurrentlyInWishlist = wishlistStatus[listingId];

      if (isCurrentlyInWishlist) {
        await removeFromWishlist(listingId);
      } else {
        await addToWishlist(listingId);
      }

      setWishlistStatus(prev => ({
        ...prev,
        [listingId]: !isCurrentlyInWishlist
      }));
    } catch (error) {

      alert('Failed to update wishlist');
    }
  }

  function handleListingClick(listingId: string) {
    if (user) {
      recordListingView(listingId, user.id, Date.now().toString());
    }
    onViewChange('listing-detail', listingId);
  }

  function clearFilters() {
    setFilters({});
    setSearchQuery('');
    loadInitialData();
  }

  const hasActiveFilters = searchQuery || filters.category || filters.region || filters.minPrice || filters.maxPrice;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white py-8 sm:py-12">
        <div className="max-w-7xl mx-auto px-4">
          <h1 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-4 sm:mb-6">Discover Unique Souvenirs</h1>

          <div className="flex flex-col sm:flex-row gap-2 sm:gap-3 mb-4 sm:mb-6">
            <div className="flex-1 relative">
              <Search className="absolute left-3 sm:left-4 top-1/2 transform -translate-y-1/2 w-4 h-4 sm:w-5 sm:h-5 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                placeholder="Search for souvenirs, locations, categories..."
                className="w-full pl-10 sm:pl-12 pr-4 py-3 sm:py-4 rounded-lg text-sm sm:text-base text-gray-900 focus:ring-2 focus:ring-blue-400 outline-none"
              />
            </div>
            <div className="flex gap-2 sm:gap-3">
              <button
                onClick={() => setShowFilters(!showFilters)}
                className="flex-1 sm:flex-initial bg-blue-500 hover:bg-blue-600 px-4 sm:px-6 py-3 sm:py-4 rounded-lg font-semibold flex items-center justify-center gap-2 transition text-sm sm:text-base"
              >
                <Filter className="w-4 h-4 sm:w-5 sm:h-5" />
                <span>Filters</span>
              </button>
              <button
                onClick={handleSearch}
                className="flex-1 sm:flex-initial bg-white text-blue-600 hover:bg-blue-50 px-6 sm:px-8 py-3 sm:py-4 rounded-lg font-semibold transition text-sm sm:text-base"
              >
                Search
              </button>
            </div>
          </div>

          {showFilters && (
            <div className="bg-white text-gray-900 rounded-lg p-4 sm:p-6 mb-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                <div>
                  <label className="block text-xs sm:text-sm font-semibold mb-2">Category</label>
                  <select
                    value={filters.category || ''}
                    onChange={(e) => setFilters({ ...filters, category: e.target.value || undefined })}
                    className="w-full px-3 py-2 text-sm sm:text-base border rounded-lg focus:ring-2 focus:ring-blue-400 outline-none"
                  >
                    <option value="">All Categories</option>
                    {categories.map(cat => (
                      <option key={cat} value={cat}>{cat}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs sm:text-sm font-semibold mb-2">Region</label>
                  <select
                    value={filters.region || ''}
                    onChange={(e) => setFilters({ ...filters, region: e.target.value || undefined })}
                    className="w-full px-3 py-2 text-sm sm:text-base border rounded-lg focus:ring-2 focus:ring-blue-400 outline-none"
                  >
                    <option value="">All Regions</option>
                    {regions.map(reg => (
                      <option key={reg} value={reg}>{reg}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs sm:text-sm font-semibold mb-2">Min Price ($)</label>
                  <input
                    type="number"
                    value={filters.minPrice || ''}
                    onChange={(e) => setFilters({ ...filters, minPrice: e.target.value ? Number(e.target.value) : undefined })}
                    className="w-full px-3 py-2 text-sm sm:text-base border rounded-lg focus:ring-2 focus:ring-blue-400 outline-none"
                    placeholder="0"
                  />
                </div>

                <div>
                  <label className="block text-xs sm:text-sm font-semibold mb-2">Max Price ($)</label>
                  <input
                    type="number"
                    value={filters.maxPrice || ''}
                    onChange={(e) => setFilters({ ...filters, maxPrice: e.target.value ? Number(e.target.value) : undefined })}
                    className="w-full px-3 py-2 text-sm sm:text-base border rounded-lg focus:ring-2 focus:ring-blue-400 outline-none"
                    placeholder="1000"
                  />
                </div>
              </div>

              <div className="mt-3 sm:mt-4 flex flex-col sm:flex-row gap-2 sm:gap-3">
                <button
                  onClick={handleSearch}
                  className="w-full sm:w-auto bg-blue-600 text-white px-6 py-2 rounded-lg text-sm sm:text-base font-semibold hover:bg-blue-700 transition"
                >
                  Apply Filters
                </button>
                {hasActiveFilters && (
                  <button
                    onClick={clearFilters}
                    className="w-full sm:w-auto bg-gray-200 text-gray-700 px-6 py-2 rounded-lg text-sm sm:text-base font-semibold hover:bg-gray-300 transition flex items-center justify-center gap-2"
                  >
                    <X className="w-4 h-4" />
                    Clear All
                  </button>
                )}
              </div>
            </div>
          )}

          {categories.length > 0 && (
            <div className="flex items-center gap-2 flex-wrap">
              <Filter className="w-3 h-3 sm:w-4 sm:h-4" />
              <span className="text-xs sm:text-sm font-semibold">Quick Filters:</span>
              {categories.slice(0, 6).map((cat) => (
                <button
                  key={cat}
                  onClick={() => {
                    setFilters({ ...filters, category: cat });
                    setSearchQuery('');
                  }}
                  className="bg-blue-500 bg-opacity-30 hover:bg-opacity-50 px-2 sm:px-3 py-1 rounded-full text-xs sm:text-sm transition"
                >
                  {cat}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            {hasActiveFilters ? (
              <>
                <Search className="w-6 h-6" />
                Search Results ({listings.length})
              </>
            ) : (
              <>
                <TrendingUp className="w-6 h-6" />
                Trending Souvenirs
              </>
            )}
          </h2>
        </div>

        {loading ? (
          <SouvenirLoader message="Loading discoveries..." />
        ) : listings.length === 0 ? (
          <div className="text-center py-20 px-4">
            <Search className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-700 mb-2">
              {hasActiveFilters ? 'No souvenirs found' : 'No listings available yet'}
            </h3>
            <p className="text-gray-500 mb-6">
              {hasActiveFilters
                ? 'Try adjusting your search or filters'
                : 'Be the first to explore when pickers add new listings'}
            </p>
            {hasActiveFilters && (
              <button
                onClick={clearFilters}
                className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition"
              >
                Clear All Filters
              </button>
            )}
            {!hasActiveFilters && (
              <button
                onClick={() => onViewChange('listings')}
                className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition"
              >
                Browse All Listings
              </button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
            {listings.map((listing) => (
              <div
                key={listing.id}
                onClick={() => handleListingClick(listing.id)}
                className="bg-white rounded-lg shadow-md hover:shadow-xl transition-all duration-300 cursor-pointer group overflow-hidden"
              >
                <div className="relative">
                  <img
                    src={listing.image_url || listing.images?.[0] || 'https://via.placeholder.com/400x300'}
                    alt={listing.title}
                    className="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                  <button
                    onClick={(e) => toggleWishlist(listing.id, e)}
                    className={`absolute top-3 right-3 p-2 rounded-full backdrop-blur-sm transition-all ${
                      wishlistStatus[listing.id]
                        ? 'bg-red-500 text-white'
                        : 'bg-white bg-opacity-70 text-gray-600 hover:bg-opacity-100'
                    }`}
                  >
                    <Heart className={`w-5 h-5 ${wishlistStatus[listing.id] ? 'fill-current' : ''}`} />
                  </button>
                  {!listing.available && (
                    <div className="absolute top-3 left-3 bg-red-500 text-white px-3 py-1 rounded-full text-xs font-semibold">
                      Unavailable
                    </div>
                  )}
                </div>

                <div className="p-4">
                  <h3 className="font-bold text-lg mb-2 line-clamp-1 group-hover:text-blue-600 transition">
                    {listing.title}
                  </h3>
                  <p className="text-gray-600 text-sm mb-3 line-clamp-2">
                    {listing.description}
                  </p>

                  <div className="flex items-center gap-2 text-sm text-gray-500 mb-2">
                    <MapPin className="w-4 h-4" />
                    <span className="line-clamp-1">{listing.region}</span>
                  </div>

                  {listing.picker && (
                    <div className="flex items-center gap-2 mb-3">
                      <img
                        src={listing.picker.avatar_url || `https://ui-avatars.com/api/?name=${listing.picker.full_name}`}
                        alt={listing.picker.full_name}
                        className="w-6 h-6 rounded-full"
                      />
                      <span className="text-sm text-gray-600">{listing.picker.full_name}</span>
                      {listing.picker.trust_score && (
                        <div className="flex items-center gap-1 text-xs text-yellow-600">
                          <Star className="w-3 h-3 fill-current" />
                          <span>{listing.picker.trust_score.toFixed(1)}</span>
                        </div>
                      )}
                    </div>
                  )}

                  <div className="flex items-center justify-between pt-3 border-t">
                    <span className="text-2xl font-bold text-blue-600">
                      ${listing.price}
                    </span>
                    <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                      {listing.category}
                    </span>
                  </div>

                  {listing.picker_id && user && listing.picker_id !== user.id && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onViewChange('messages', listing.picker_id);
                      }}
                      className="w-full mt-3 bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded-lg transition-colors flex items-center justify-center gap-2 font-medium"
                    >
                      <MessageCircle className="w-4 h-4" />
                      Contact Picker
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
