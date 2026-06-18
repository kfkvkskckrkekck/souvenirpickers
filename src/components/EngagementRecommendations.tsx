import { useState, useEffect } from 'react';
import { TrendingUp, Users, Star, Package, MessageCircle, Camera, Zap, CheckCircle, ArrowRight, Target, Award } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface EngagementAction {
  id: string;
  title: string;
  description: string;
  icon: any;
  priority: 'high' | 'medium' | 'low';
  completed: boolean;
  action: () => void;
  category: 'profile' | 'content' | 'engagement' | 'earning';
}

interface EngagementRecommendationsProps {
  onViewChange?: (view: string) => void;
}

export default function EngagementRecommendations({ onViewChange }: EngagementRecommendationsProps) {
  const { user, profile } = useAuth();
  const [recommendations, setRecommendations] = useState<EngagementAction[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    listingsCount: 0,
    ordersCount: 0,
    reviewsCount: 0,
    responseRate: 0,
    avgRating: 0,
  });

  useEffect(() => {
    if (user && profile) {
      loadEngagementData();
    }
  }, [user, profile]);

  const loadEngagementData = async () => {
    if (!user || !profile) return;

    try {
      const isPicker = profile.user_type === 'picker';

      if (isPicker) {
        const [listingsRes, ordersRes, reviewsRes, pickerProfileRes] = await Promise.all([
          supabase.from('listings').select('id', { count: 'exact', head: true }).eq('picker_id', user.id),
          supabase.from('orders').select('id', { count: 'exact', head: true }).eq('picker_id', user.id),
          supabase.from('reviews').select('rating').eq('picker_id', user.id),
          supabase.from('picker_profiles').select('rating, total_reviews').eq('user_id', user.id).maybeSingle(),
        ]);

        const avgRating = reviewsRes.data?.reduce((sum, r) => sum + r.rating, 0) / (reviewsRes.data?.length || 1) || 0;

        setStats({
          listingsCount: listingsRes.count || 0,
          ordersCount: ordersRes.count || 0,
          reviewsCount: reviewsRes.data?.length || 0,
          responseRate: 0,
          avgRating: pickerProfileRes.data?.rating || avgRating,
        });
      } else {
        const [ordersRes, reviewsRes] = await Promise.all([
          supabase.from('orders').select('id', { count: 'exact', head: true }).eq('client_id', user.id),
          supabase.from('reviews').select('id', { count: 'exact', head: true }).eq('reviewer_id', user.id),
        ]);

        setStats({
          listingsCount: 0,
          ordersCount: ordersRes.count || 0,
          reviewsCount: reviewsRes.count || 0,
          responseRate: 0,
          avgRating: 0,
        });
      }

      generateRecommendations();
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const generateRecommendations = () => {
    if (!profile) return;

    const actions: EngagementAction[] = [];
    const isPicker = profile.user_type === 'picker';

    if (isPicker) {
      if (stats.listingsCount === 0) {
        actions.push({
          id: 'create-listing',
          title: 'Create Your First Listing',
          description: 'Start earning by adding your first souvenir listing',
          icon: Package,
          priority: 'high',
          completed: false,
          action: () => onViewChange?.('listings'),
          category: 'content',
        });
      }

      if (stats.listingsCount > 0 && stats.listingsCount < 5) {
        actions.push({
          id: 'add-more-listings',
          title: 'Add More Listings',
          description: 'Pickers with 5+ listings earn 3x more. Add more to increase visibility',
          icon: TrendingUp,
          priority: 'high',
          completed: false,
          action: () => onViewChange?.('listings'),
          category: 'earning',
        });
      }

      if (!profile.avatar_url) {
        actions.push({
          id: 'add-profile-photo',
          title: 'Add Profile Photo',
          description: 'Profiles with photos get 80% more orders',
          icon: Camera,
          priority: 'high',
          completed: false,
          action: () => onViewChange?.('profile'),
          category: 'profile',
        });
      }

      if (!profile.bio || profile.bio.length < 50) {
        actions.push({
          id: 'complete-bio',
          title: 'Complete Your Bio',
          description: 'Tell collectors about yourself and your local expertise',
          icon: Star,
          priority: 'medium',
          completed: false,
          action: () => onViewChange?.('profile'),
          category: 'profile',
        });
      }

      if (stats.ordersCount > 0 && stats.reviewsCount === 0) {
        actions.push({
          id: 'get-reviews',
          title: 'Ask for Reviews',
          description: 'Follow up with customers to get your first reviews',
          icon: Award,
          priority: 'high',
          completed: false,
          action: () => onViewChange?.('orders'),
          category: 'engagement',
        });
      }

      if (stats.avgRating > 0 && stats.avgRating < 4.5) {
        actions.push({
          id: 'improve-rating',
          title: 'Improve Your Rating',
          description: 'Respond quickly and deliver quality items to boost your rating',
          icon: Star,
          priority: 'medium',
          completed: false,
          action: () => onViewChange?.('orders'),
          category: 'engagement',
        });
      }

      actions.push({
        id: 'go-live',
        title: 'Try Live Streaming',
        description: 'Show off local markets and connect with collectors in real-time',
        icon: Zap,
        priority: 'medium',
        completed: false,
        action: () => onViewChange?.('streaming'),
        category: 'engagement',
      });

      actions.push({
        id: 'share-stories',
        title: 'Post Stories',
        description: 'Share behind-the-scenes content to engage your followers',
        icon: Camera,
        priority: 'low',
        completed: false,
        action: () => onViewChange?.('social'),
        category: 'content',
      });

    } else {
      if (stats.ordersCount === 0) {
        actions.push({
          id: 'first-order',
          title: 'Place Your First Order',
          description: 'Browse unique souvenirs and start your collection',
          icon: Package,
          priority: 'high',
          completed: false,
          action: () => onViewChange?.('listings'),
          category: 'engagement',
        });
      }

      if (stats.ordersCount > 0 && stats.reviewsCount === 0) {
        actions.push({
          id: 'leave-review',
          title: 'Leave a Review',
          description: 'Share your experience and help other collectors',
          icon: Star,
          priority: 'medium',
          completed: false,
          action: () => onViewChange?.('orders'),
          category: 'engagement',
        });
      }

      actions.push({
        id: 'follow-pickers',
        title: 'Follow Pickers',
        description: 'Stay updated when your favorite pickers add new items',
        icon: Users,
        priority: 'medium',
        completed: false,
        action: () => onViewChange?.('pickers'),
        category: 'engagement',
      });

      actions.push({
        id: 'set-desires',
        title: 'Set Your Desires',
        description: 'Let pickers know what souvenirs you are looking for',
        icon: Target,
        priority: 'medium',
        completed: false,
        action: () => onViewChange?.('desires'),
        category: 'engagement',
      });

      actions.push({
        id: 'watch-streams',
        title: 'Watch Live Streams',
        description: 'Experience markets around the world in real-time',
        icon: Zap,
        priority: 'low',
        completed: false,
        action: () => onViewChange?.('streaming'),
        category: 'engagement',
      });
    }

    setRecommendations(actions);
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high':
        return 'bg-red-100 text-red-700 border-red-200';
      case 'medium':
        return 'bg-yellow-100 text-yellow-700 border-yellow-200';
      case 'low':
        return 'bg-green-100 text-green-700 border-green-200';
      default:
        return 'bg-gray-100 text-gray-700 border-gray-200';
    }
  };

  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'profile':
        return Star;
      case 'content':
        return Package;
      case 'engagement':
        return MessageCircle;
      case 'earning':
        return TrendingUp;
      default:
        return Target;
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-2xl shadow-lg p-6">
        <div className="text-gray-500">Loading recommendations...</div>
      </div>
    );
  }

  if (recommendations.length === 0) {
    return (
      <div className="bg-gradient-to-br from-green-50 to-blue-50 rounded-2xl shadow-lg p-8 text-center">
        <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
        <h3 className="text-2xl font-bold text-gray-900 mb-2">You're All Set!</h3>
        <p className="text-gray-600">
          You're making great progress. Keep up the excellent work!
        </p>
      </div>
    );
  }

  const highPriority = recommendations.filter(r => r.priority === 'high');
  const mediumPriority = recommendations.filter(r => r.priority === 'medium');
  const lowPriority = recommendations.filter(r => r.priority === 'low');

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl shadow-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="bg-gradient-to-br from-blue-500 to-purple-600 p-3 rounded-xl">
            <Zap className="w-6 h-6 text-white" />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-gray-900">Boost Your Success</h2>
            <p className="text-gray-600">
              {profile?.user_type === 'picker'
                ? 'Take these actions to maximize your earnings'
                : 'Get the most out of SouvenirPickers'}
            </p>
          </div>
        </div>

        {highPriority.length > 0 && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <span className="bg-red-100 text-red-700 text-xs px-2 py-1 rounded-full font-bold">
                HIGH PRIORITY
              </span>
            </h3>
            <div className="space-y-3">
              {highPriority.map((action) => {
                const Icon = action.icon;
                return (
                  <button
                    key={action.id}
                    onClick={action.action}
                    className="w-full bg-gradient-to-r from-red-50 to-orange-50 border-2 border-red-200 rounded-xl p-4 hover:shadow-lg transition-all text-left group"
                  >
                    <div className="flex items-start gap-4">
                      <div className="bg-red-100 p-3 rounded-lg group-hover:scale-110 transition-transform">
                        <Icon className="w-6 h-6 text-red-600" />
                      </div>
                      <div className="flex-1">
                        <h4 className="font-semibold text-gray-900 mb-1">{action.title}</h4>
                        <p className="text-sm text-gray-600">{action.description}</p>
                      </div>
                      <ArrowRight className="w-5 h-5 text-red-600 group-hover:translate-x-1 transition-transform flex-shrink-0" />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {mediumPriority.length > 0 && (
          <div className="mb-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <span className="bg-yellow-100 text-yellow-700 text-xs px-2 py-1 rounded-full font-bold">
                RECOMMENDED
              </span>
            </h3>
            <div className="space-y-3">
              {mediumPriority.map((action) => {
                const Icon = action.icon;
                return (
                  <button
                    key={action.id}
                    onClick={action.action}
                    className="w-full bg-yellow-50 border border-yellow-200 rounded-xl p-4 hover:shadow-md transition-all text-left group"
                  >
                    <div className="flex items-start gap-4">
                      <div className="bg-yellow-100 p-2.5 rounded-lg group-hover:scale-110 transition-transform">
                        <Icon className="w-5 h-5 text-yellow-600" />
                      </div>
                      <div className="flex-1">
                        <h4 className="font-semibold text-gray-900 mb-1">{action.title}</h4>
                        <p className="text-sm text-gray-600">{action.description}</p>
                      </div>
                      <ArrowRight className="w-5 h-5 text-yellow-600 group-hover:translate-x-1 transition-transform flex-shrink-0" />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {lowPriority.length > 0 && (
          <div>
            <h3 className="text-lg font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <span className="bg-green-100 text-green-700 text-xs px-2 py-1 rounded-full font-bold">
                OPTIONAL
              </span>
            </h3>
            <div className="space-y-3">
              {lowPriority.map((action) => {
                const Icon = action.icon;
                return (
                  <button
                    key={action.id}
                    onClick={action.action}
                    className="w-full bg-gray-50 border border-gray-200 rounded-xl p-4 hover:shadow-md transition-all text-left group"
                  >
                    <div className="flex items-start gap-4">
                      <div className="bg-gray-100 p-2.5 rounded-lg group-hover:scale-110 transition-transform">
                        <Icon className="w-5 h-5 text-gray-600" />
                      </div>
                      <div className="flex-1">
                        <h4 className="font-semibold text-gray-900 mb-1">{action.title}</h4>
                        <p className="text-sm text-gray-600">{action.description}</p>
                      </div>
                      <ArrowRight className="w-5 h-5 text-gray-600 group-hover:translate-x-1 transition-transform flex-shrink-0" />
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
