import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Users, MapPin, Star, TrendingUp, Loader, Eye, Bell, Heart, Plus } from 'lucide-react';

interface Match {
  id: string;
  picker_id: string;
  match_score: number;
  distance_km: number;
  picker_rating: number;
  viewed_at: string | null;
  picker: {
    full_name: string;
    avatar_url: string;
    bio: string;
  };
  picker_profile: {
    current_location: string;
  };
  desire: {
    title: string;
    description: string;
  };
}

type MatchedPickersViewProps = {
  onViewChange?: (view: string) => void;
};

export default function MatchedPickersView({ onViewChange }: MatchedPickersViewProps) {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [matches, setMatches] = useState<Match[]>([]);
  const [selectedDesire, setSelectedDesire] = useState<string>('all');
  const [desires, setDesires] = useState<any[]>([]);

  useEffect(() => {
    if (user) {
      loadData();
    }
  }, [user, selectedDesire]);

  const loadData = async () => {
    try {
      setLoading(true);

      const [desiresRes, matchesRes] = await Promise.all([
        supabase
          .from('client_desires')
          .select('*')
          .eq('client_id', user?.id)
          .eq('active', true),
        supabase
          .from('desire_matches')
          .select(`
            *,
            picker:profiles!desire_matches_picker_id_fkey(full_name, avatar_url, bio),
            picker_profile:picker_profiles!desire_matches_picker_id_fkey(current_location),
            desire:client_desires!desire_matches_desire_id_fkey(title, description, client_id)
          `)
          .order('match_score', { ascending: false })
      ]);

      if (desiresRes.error) throw desiresRes.error;
      if (matchesRes.error) throw matchesRes.error;

      const allDesires = desiresRes.data || [];
      setDesires(allDesires);

      let filteredMatches = matchesRes.data || [];

      if (selectedDesire !== 'all') {
        filteredMatches = filteredMatches.filter(m => m.desire_id === selectedDesire);
      }

      filteredMatches = filteredMatches.filter(m => m.desire?.client_id === user?.id);

      setMatches(filteredMatches);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const markAsViewed = async (matchId: string) => {
    try {
      await supabase
        .from('desire_matches')
        .update({ viewed_at: new Date().toISOString() })
        .eq('id', matchId);

      setMatches(matches.map(m =>
        m.id === matchId ? { ...m, viewed_at: new Date().toISOString() } : m
      ));
    } catch (error) {

    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 80) return 'bg-green-100 text-green-800 border-green-300';
    if (score >= 60) return 'bg-blue-100 text-blue-800 border-blue-300';
    if (score >= 40) return 'bg-yellow-100 text-yellow-800 border-yellow-300';
    return 'bg-gray-100 text-gray-800 border-gray-300';
  };

  const getScoreLabel = (score: number) => {
    if (score >= 80) return 'Excellent Match';
    if (score >= 60) return 'Good Match';
    if (score >= 40) return 'Fair Match';
    return 'Possible Match';
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center py-12">
          <Loader className="w-8 h-8 animate-spin text-green-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Matched Pickers</h1>
        <p className="text-gray-600">Discover pickers who can fulfill your desires based on location, rating, and availability</p>
      </div>

      <div className="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex items-start gap-3">
          <TrendingUp className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
          <div>
            <h3 className="font-semibold text-blue-900 mb-1">How Smart Matching Works</h3>
            <p className="text-sm text-blue-800 mb-3">
              Our algorithm finds pickers near your desired locations and scores them based on:
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm text-blue-800">
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-blue-600 rounded-full"></div>
                <span><strong>Distance (40 pts):</strong> Closer is better</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-blue-600 rounded-full"></div>
                <span><strong>Rating (30 pts):</strong> Higher ratings score more</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-blue-600 rounded-full"></div>
                <span><strong>Experience (20 pts):</strong> More orders = better</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-blue-600 rounded-full"></div>
                <span><strong>Activity (10 pts):</strong> Recent activity boosts score</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {desires.length > 0 && (
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">Filter by Desire</label>
          <select
            value={selectedDesire}
            onChange={(e) => setSelectedDesire(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
          >
            <option value="all">All Desires</option>
            {desires.map(desire => (
              <option key={desire.id} value={desire.id}>{desire.title}</option>
            ))}
          </select>
        </div>
      )}

      {matches.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12">
          <div className="max-w-2xl mx-auto text-center">
            <Users className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-3">
              {desires.length === 0 ? 'Create Your First Desire to Get Started' : 'No Matches Found Yet'}
            </h3>

            {desires.length === 0 ? (
              <div className="text-left bg-gray-50 rounded-lg p-6 mb-6">
                <h4 className="font-semibold text-gray-900 mb-3">How to get matched with pickers:</h4>
                <ol className="space-y-3 text-gray-700">
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-sm font-bold">1</span>
                    <span>Go to <strong>Client Desires</strong> in the sidebar and create a new desire</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-sm font-bold">2</span>
                    <span><strong>IMPORTANT:</strong> Use the map picker to select a <strong>specific GPS location</strong> where you want souvenirs from</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-sm font-bold">3</span>
                    <span>Our system will <strong>instantly find pickers</strong> within 500km of that location and calculate match scores</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-sm font-bold">4</span>
                    <span>Come back here to see your <strong>matched pickers</strong> ranked by distance, rating, and experience</span>
                  </li>
                </ol>
                <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                  <p className="text-sm text-blue-800">
                    <strong>Tip:</strong> Click on the map in the location picker to set exact GPS coordinates. The matching only works with precise location data.
                  </p>
                </div>
              </div>
            ) : (
              <div className="text-left bg-gray-50 rounded-lg p-6 mb-6">
                <h4 className="font-semibold text-gray-900 mb-3">Why you might not have matches yet:</h4>
                <ul className="space-y-3 text-gray-700">
                  <li className="flex gap-3">
                    <MapPin className="w-5 h-5 text-orange-500 flex-shrink-0 mt-0.5" />
                    <div>
                      <p className="font-medium text-gray-900">Missing GPS Location Data</p>
                      <p className="text-sm">Your desires need <strong>precise GPS coordinates</strong> set via the map picker. Go to Client Desires, edit each desire, and click on the map to set an exact location.</p>
                    </div>
                  </li>
                  <li className="flex gap-3">
                    <Users className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <p className="font-medium text-gray-900">No Nearby Pickers</p>
                      <p className="text-sm">There may not be active pickers within 500km of your desired locations yet. Try selecting popular cities or tourist destinations.</p>
                    </div>
                  </li>
                  <li className="flex gap-3">
                    <TrendingUp className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <p className="font-medium text-gray-900">Instant Matching</p>
                      <p className="text-sm">Matches are calculated immediately when you add GPS coordinates to your desires. If you've already added locations, refresh this page.</p>
                    </div>
                  </li>
                </ul>
                <div className="mt-4 p-3 bg-orange-50 border border-orange-200 rounded-lg">
                  <p className="text-sm text-orange-800">
                    <strong>Action Required:</strong> Make sure each of your desires has GPS coordinates by using the map picker in the location field when creating or editing desires.
                  </p>
                </div>
              </div>
            )}

            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              {desires.length === 0 ? (
                <button
                  onClick={() => onViewChange?.('desires')}
                  className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium inline-flex items-center justify-center gap-2"
                >
                  <Heart className="w-5 h-5" />
                  Create Your First Desire
                </button>
              ) : (
                <>
                  <button
                    onClick={() => onViewChange?.('pickers')}
                    className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium inline-flex items-center justify-center gap-2"
                  >
                    <Users className="w-5 h-5" />
                    Browse All Pickers
                  </button>
                  <button
                    onClick={() => onViewChange?.('desires')}
                    className="px-6 py-3 border-2 border-green-600 text-green-600 rounded-lg hover:bg-green-50 transition-colors font-medium inline-flex items-center justify-center gap-2"
                  >
                    <Heart className="w-5 h-5" />
                    Manage My Desires
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {matches.map((match) => (
            <div
              key={match.id}
              className={`bg-white rounded-xl shadow-sm border-2 ${
                match.viewed_at ? 'border-gray-200' : 'border-green-300'
              } p-6 hover:shadow-md transition-shadow`}
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-start gap-4">
                  <img
                    src={match.picker?.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(match.picker?.full_name || 'Picker')}`}
                    alt={match.picker?.full_name}
                    className="w-16 h-16 rounded-full object-cover border-2 border-gray-200"
                  />
                  <div>
                    <h3 className="font-semibold text-lg text-gray-900">{match.picker?.full_name}</h3>
                    {match.picker_profile?.current_location && (
                      <p className="text-sm text-gray-600 flex items-center gap-1 mt-1">
                        <MapPin className="w-4 h-4" />
                        {match.picker_profile.current_location}
                      </p>
                    )}
                    {match.picker_rating > 0 && (
                      <p className="text-sm text-gray-600 flex items-center gap-1 mt-1">
                        <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                        {match.picker_rating.toFixed(1)}
                      </p>
                    )}
                  </div>
                </div>
                {!match.viewed_at && (
                  <div className="flex items-center gap-1 text-green-600 text-xs font-semibold bg-green-50 px-2 py-1 rounded">
                    <Bell className="w-3 h-3" />
                    New
                  </div>
                )}
              </div>

              <div className={`inline-flex items-center gap-2 px-3 py-1 rounded-full border-2 text-sm font-semibold mb-4 ${getScoreColor(match.match_score)}`}>
                <TrendingUp className="w-4 h-4" />
                {getScoreLabel(match.match_score)} ({match.match_score}/100)
              </div>

              <div className="mb-4">
                <p className="text-sm text-gray-600 mb-2">
                  <span className="font-medium text-gray-900">For: </span>
                  {match.desire?.title}
                </p>
                <p className="text-sm text-gray-600">
                  <span className="font-medium text-gray-900">Distance: </span>
                  {match.distance_km?.toFixed(1)} km away
                </p>
              </div>

              {match.picker?.bio && (
                <p className="text-sm text-gray-700 mb-4 line-clamp-2">{match.picker.bio}</p>
              )}

              <div className="flex gap-3">
                <button
                  onClick={() => {
                    markAsViewed(match.id);
                    onViewChange?.('pickers');
                  }}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium"
                >
                  View All Pickers
                </button>
                {!match.viewed_at && (
                  <button
                    onClick={() => markAsViewed(match.id)}
                    className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors flex items-center gap-2"
                  >
                    <Eye className="w-4 h-4" />
                    Mark Viewed
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
