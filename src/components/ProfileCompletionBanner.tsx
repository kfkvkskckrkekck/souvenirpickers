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
      <div className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 px-4 py-2.5 mb-5 rounded-xl shadow-sm">
        <div className="flex items-center gap-3 flex-wrap sm:flex-nowrap">
          <CheckCircle className="h-4 w-4 text-green-600 flex-shrink-0" />
          <p className="flex-1 min-w-[200px] text-sm text-gray-700">
            <span className="font-semibold text-gray-900">Profile Complete.</span>{' '}
            {profile.user_type === 'picker'
              ? 'Ready to receive orders from collectors worldwide.'
              : 'Ready to browse and order unique souvenirs.'}
          </p>
          <button
            onClick={onNavigateToProfile}
            className="flex-shrink-0 inline-flex items-center gap-1.5 bg-green-600 text-white px-3.5 py-1.5 rounded-lg hover:bg-green-700 transition-colors font-semibold text-xs"
          >
            Edit Profile
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
          <button
            onClick={() => setDismissed(true)}
            className="flex-shrink-0 text-gray-400 hover:text-gray-600"
            aria-label="Dismiss"
          >
            <X className="h-4 w-4" />
          </button>
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
    <div className="bg-gradient-to-r from-orange-50 to-amber-50 border border-orange-200 px-4 py-2.5 mb-5 rounded-xl shadow-sm">
      <div className="flex items-center gap-3 flex-wrap sm:flex-nowrap">
        <AlertCircle className="h-4 w-4 text-orange-600 flex-shrink-0" />
        <p className="flex-1 min-w-[200px] text-sm text-gray-700">
          <span className="font-semibold text-gray-900">{title}.</span> {description}
        </p>
        <button
          onClick={onNavigateToProfile}
          className="flex-shrink-0 inline-flex items-center gap-1.5 bg-orange-600 text-white px-3.5 py-1.5 rounded-lg hover:bg-orange-700 transition-colors font-semibold text-xs"
        >
          Complete Profile
          <ArrowRight className="h-3.5 w-3.5" />
        </button>
        <button
          onClick={() => setDismissed(true)}
          className="flex-shrink-0 text-gray-400 hover:text-gray-600"
          aria-label="Dismiss"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
