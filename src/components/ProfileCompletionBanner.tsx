import { useState, useEffect } from 'react';
import { AlertCircle, X, ArrowRight, CheckCircle, Sparkles, TrendingUp, ShoppingBag, Package, Star } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface ProfileCompletionBannerProps {
  onNavigateToProfile: () => void;
}

export default function ProfileCompletionBanner({ onNavigateToProfile }: ProfileCompletionBannerProps) {
  const { user, profile } = useAuth();
  const [missingFields, setMissingFields] = useState<string[]>([]);
  const [dismissed, setDismissed] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user || !profile) {
      setLoading(false);
      return;
    }

    checkProfileCompletion();
  }, [user, profile]);

  const checkProfileCompletion = async () => {
    if (!user || !profile) return;

    const missing: string[] = [];

    if (profile.user_type === 'picker') {
      const { data: pickerProfile } = await supabase
        .from('picker_profiles')
        .select('current_location, regions, specialties, full_name, avatar_url')
        .eq('user_id', user.id)
        .maybeSingle();

      if (!pickerProfile?.full_name) {
        missing.push('full name');
      }

      if (!pickerProfile?.avatar_url) {
        missing.push('profile picture');
      }

      if (!pickerProfile?.current_location) {
        missing.push('location');
      }

      if (!pickerProfile?.regions || pickerProfile.regions.length === 0) {
        missing.push('service regions');
      }

      if (!pickerProfile?.specialties || pickerProfile.specialties.length === 0) {
        missing.push('specialties');
      }

      const { data: payoutInfo } = await supabase
        .from('picker_payout_info')
        .select('id')
        .eq('picker_id', user.id)
        .maybeSingle();

      if (!payoutInfo) {
        missing.push('payout information');
      }

      // Note: We don't require listings for profile completion
      // Pickers can complete their profile and then add listings
    }

    if (profile.user_type === 'client') {
      if (!profile.full_name) {
        missing.push('full name');
      }

      if (!profile.bio) {
        missing.push('bio');
      }

      if (!profile.avatar_url) {
        missing.push('profile picture');
      }
      // Delivery address is optional for collectors
    }

    setMissingFields(missing);
    setLoading(false);
  };

  if (loading || dismissed || !profile) {
    return null;
  }

  // If profile is complete, show success banner
  if (missingFields.length === 0) {
    return (
      <div className="bg-gradient-to-br from-green-50 via-blue-50 to-green-50 border-2 border-green-300 p-4 mb-6 rounded-lg shadow-sm">
        <div className="flex items-start gap-3">
          <div className="bg-green-500 rounded-full p-2 shadow-md flex-shrink-0">
            <CheckCircle className="h-6 w-6 text-white" />
          </div>
          <div className="flex-1">
            <div className="flex items-start justify-between gap-2">
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900 mb-1">Profile Complete</h3>
                <p className="text-sm text-gray-700 mb-3">
                  {profile.user_type === 'picker'
                    ? 'Your profile is complete and ready. You can now create listings and start receiving orders from collectors around the world!'
                    : 'Your profile is complete. Browse unique souvenirs from around the world and place your first order!'}
                </p>
                <button
                  onClick={onNavigateToProfile}
                  className="inline-flex items-center gap-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium text-sm"
                >
                  Edit Profile
                  <ArrowRight className="h-4 w-4" />
                </button>
              </div>
              <button
                onClick={() => setDismissed(true)}
                className="text-gray-400 hover:text-gray-600 flex-shrink-0"
                aria-label="Dismiss"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // If profile is incomplete, show completion prompt
  const getMessage = () => {
    const formatFields = (fields: string[]) => {
      if (fields.length === 1) return fields[0];
      if (fields.length === 2) return fields.join(' and ');
      return fields.slice(0, -1).join(', ') + ', and ' + fields[fields.length - 1];
    };

    if (profile.user_type === 'picker') {
      return {
        title: 'Complete Your Profile to Start Earning',
        description: `Required fields missing: ${formatFields(missingFields)}. Complete all required fields to start receiving orders and earning money.`,
      };
    } else {
      return {
        title: 'Complete Your Profile',
        description: `Required fields missing: ${formatFields(missingFields)}. Complete all required fields to unlock full functionality.`,
      };
    }
  };

  const { title, description } = getMessage();

  return (
    <div className="bg-gradient-to-r from-orange-50 to-yellow-50 border-l-4 border-orange-500 p-4 mb-6 rounded-lg shadow-sm">
      <div className="flex items-start gap-3">
        <AlertCircle className="h-6 w-6 text-orange-600 flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <div className="flex items-start justify-between gap-2">
            <div>
              <h3 className="font-semibold text-gray-900 mb-1">{title}</h3>
              <p className="text-sm text-gray-700 mb-3">{description}</p>
              <button
                onClick={onNavigateToProfile}
                className="inline-flex items-center gap-2 bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700 transition-colors font-medium text-sm"
              >
                Complete Profile Now
                <ArrowRight className="h-4 w-4" />
              </button>
            </div>
            <button
              onClick={() => setDismissed(true)}
              className="text-gray-400 hover:text-gray-600 flex-shrink-0"
              aria-label="Dismiss"
            >
              <X className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
