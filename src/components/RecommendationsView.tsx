import { useState, useEffect } from 'react';
import { TrendingUp, Sparkles, Star, MapPin, ShoppingCart, Zap } from 'lucide-react';
import { supabase, Listing, PickerProfile, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { MediaGallery } from './MediaGallery';
import EngagementRecommendations from './EngagementRecommendations';

type ListingWithPicker = Listing & {
  picker?: PickerProfile & { profile?: Profile };
  relevance_score?: number;
  trend_score?: number;
};

type RecommendationsViewProps = {
  onViewChange?: (view: string) => void;
};

export function RecommendationsView({ onViewChange }: RecommendationsViewProps) {
  const { user, profile } = useAuth();
  const [personalizedListings, setPersonalizedListings] = useState<ListingWithPicker[]>([]);
  const [trendingListings, setTrendingListings] = useState<ListingWithPicker[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'engagement' | 'personalized' | 'trending'>('engagement');

  useEffect(() => {
    if (user) {
      loadRecommendations();
    }
  }, [user]);

  const loadRecommendations = async () => {
    try {
      await Promise.all([
        loadPersonalizedRecommendations(),
        loadTrendingListings(),
      ]);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const loadPersonalizedRecommendations = async () => {
    if (!user) return;

    try {
      const { data: recommendations, error } = await supabase.rpc(
        'get_personalized_recommendations',
        {
          p_user_id: user.id,
          p_limit: 12,
        }
      );

      if (error) throw error;

      if (recommendations && recommendations.length > 0) {
        const listingIds = recommendations.map((r: any) => r.listing_id);

        const { data: listings, error: listingsError } = await supabase
          .from('listings')
          .select(`
            *,
            picker:picker_profiles!listings_picker_id_fkey(
              *,
              profile:profiles!picker_profiles_user_id_fkey(*)
            )
          `)
          .in('id', listingIds);

        if (listingsError) throw listingsError;

        const listingsWithScores = listings?.map((listing) => {
          const rec = recommendations.find((r: any) => r.listing_id === listing.id);
          return {
            ...listing,
            relevance_score: rec?.relevance_score || 0,
          };
        });

        setPersonalizedListings(listingsWithScores || []);
      }
    } catch (error) {

    }
  };

  const loadTrendingListings = async () => {
    try {
      const { data: trending, error } = await supabase.rpc(
        'get_trending_listings',
        {
          p_limit: 12,
        }
      );

      if (error) throw error;

      if (trending && trending.length > 0) {
        const listingIds = trending.map((t: any) => t.listing_id);

        const { data: listings, error: listingsError } = await supabase
          .from('listings')
          .select(`
            *,
            picker:picker_profiles!listings_picker_id_fkey(
              *,
              profile:profiles!picker_profiles_user_id_fkey(*)
            )
          `)
          .in('id', listingIds);

        if (listingsError) throw listingsError;

        const listingsWithScores = listings?.map((listing) => {
          const trend = trending.find((t: any) => t.listing_id === listing.id);
          return {
            ...listing,
            trend_score: trend?.trend_score || 0,
          };
        });

        setTrendingListings(listingsWithScores || []);
      }
    } catch (error) {

    }
  };

  const recordView = async (listingId: string) => {
    try {
      await supabase.rpc('record_listing_view', {
        p_listing_id: listingId,
        p_user_id: user?.id || null,
      });
    } catch (error) {

    }
  };

  const renderListingCard = (listing: ListingWithPicker, showScore: boolean = false) => (
    <div
      key={listing.id}
      onClick={() => recordView(listing.id)}
      className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-all cursor-pointer"
    >
      <MediaGallery
        images={listing.images}
        videos={listing.videos || []}
        title={listing.title}
      />

      <div className="p-6">
        <div className="flex items-start justify-between mb-2">
          <h3 className="text-xl font-bold text-gray-900 flex-1">{listing.title}</h3>
          {showScore && listing.relevance_score && (
            <div className="ml-2 flex items-center gap-1 bg-blue-100 text-blue-700 px-2 py-1 rounded-full text-xs font-medium">
              <Sparkles className="w-3 h-3" />
              {Math.round(listing.relevance_score)}%
            </div>
          )}
          {showScore && listing.trend_score && (
            <div className="ml-2 flex items-center gap-1 bg-orange-100 text-orange-700 px-2 py-1 rounded-full text-xs font-medium">
              <TrendingUp className="w-3 h-3" />
              Hot
            </div>
          )}
        </div>

        <p className="text-gray-600 mb-4 line-clamp-2">{listing.description}</p>

        <div className="flex items-center gap-3 mb-4 text-sm text-gray-600">
          <div className="flex items-center gap-1">
            <MapPin className="w-4 h-4" />
            <span>{listing.region}</span>
          </div>
        </div>

        {listing.picker?.profile && (
          <div className="mb-4 pb-4 border-b border-gray-200">
            <p className="text-sm text-gray-600">
              by <span className="font-medium">{listing.picker.profile.full_name}</span>
              {listing.picker.verified && (
                <span className="text-green-600 ml-1">✓</span>
              )}
            </p>
            {listing.picker.rating > 0 && (
              <div className="flex items-center gap-1 mt-1">
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <span className="text-sm text-gray-600">
                  {listing.picker.rating.toFixed(1)} ({listing.picker.total_reviews})
                </span>
              </div>
            )}
          </div>
        )}

        <div className="flex items-center justify-between">
          <div className="text-2xl font-bold text-gray-900">
            ${listing.price.toFixed(2)}
          </div>
          {profile?.user_type === 'client' && (
            <button className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center gap-2">
              <ShoppingCart className="w-4 h-4" />
              Order
            </button>
          )}
        </div>
      </div>
    </div>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-gray-500">Loading recommendations...</div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Recommendations</h1>
        <p className="text-gray-600">Personalized suggestions to boost your success</p>
      </div>

      <div className="flex gap-4 mb-8 border-b overflow-x-auto">
        <button
          onClick={() => setActiveTab('engagement')}
          className={`flex items-center gap-2 px-6 py-3 font-medium transition-colors border-b-2 whitespace-nowrap ${
            activeTab === 'engagement'
              ? 'border-purple-600 text-purple-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          <Zap className="w-5 h-5" />
          For You
        </button>

        <button
          onClick={() => setActiveTab('personalized')}
          className={`flex items-center gap-2 px-6 py-3 font-medium transition-colors border-b-2 whitespace-nowrap ${
            activeTab === 'personalized'
              ? 'border-blue-600 text-blue-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          <Sparkles className="w-5 h-5" />
          Listings
          {personalizedListings.length > 0 && (
            <span className="bg-blue-100 text-blue-600 text-xs px-2 py-1 rounded-full">
              {personalizedListings.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('trending')}
          className={`flex items-center gap-2 px-6 py-3 font-medium transition-colors border-b-2 whitespace-nowrap ${
            activeTab === 'trending'
              ? 'border-orange-600 text-orange-600'
              : 'border-transparent text-gray-600 hover:text-gray-900'
          }`}
        >
          <TrendingUp className="w-5 h-5" />
          Trending
          {trendingListings.length > 0 && (
            <span className="bg-orange-100 text-orange-600 text-xs px-2 py-1 rounded-full">
              {trendingListings.length}
            </span>
          )}
        </button>
      </div>

      {activeTab === 'engagement' && (
        <EngagementRecommendations onViewChange={onViewChange} />
      )}

      {activeTab === 'personalized' && (
        <div>
          {personalizedListings.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-2xl shadow-lg">
              <Sparkles className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-gray-900 mb-2">
                No recommendations yet
              </h3>
              <p className="text-gray-600">
                Browse some listings to get personalized recommendations
              </p>
            </div>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {personalizedListings.map((listing) =>
                renderListingCard(listing, true)
              )}
            </div>
          )}
        </div>
      )}

      {activeTab === 'trending' && (
        <div>
          {trendingListings.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-2xl shadow-lg">
              <TrendingUp className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-gray-900 mb-2">
                No trending listings yet
              </h3>
              <p className="text-gray-600">
                Check back soon to see what's popular
              </p>
            </div>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {trendingListings.map((listing) =>
                renderListingCard(listing, true)
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
