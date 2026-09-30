import { useState, useEffect } from 'react';
import { Gift, Users, TrendingUp, Copy, Check, Euro, Clock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';

type ReferralStats = {
  code: string;
  total_referrals: number;
  completed_referrals: number;
  pending_referrals: number;
  total_rewards: number;
  available_rewards: number;
};

type Referral = {
  id: string;
  referred_id: string;
  status: string;
  created_at: string;
  completed_at?: string;
  referred?: {
    full_name: string;
  };
};

type Reward = {
  id: string;
  reward_type: string;
  reward_value: number;
  currency: string;
  expires_at?: string;
  redeemed: boolean;
  created_at: string;
};

export function ReferralProgram() {
  const { user, profile } = useAuth();
  const { showToast } = useToast();
  const [stats, setStats] = useState<ReferralStats | null>(null);
  const [referrals, setReferrals] = useState<Referral[]>([]);
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(true);
  const [generatingCode, setGeneratingCode] = useState(false);

  const isPicker = profile?.user_type === 'picker';
  const hasReferralDiscount = profile?.has_referral_discount && profile?.referral_discount_amount > 0;

  useEffect(() => {
    if (user) {
      loadReferralData();
    }
  }, [user]);

  const loadReferralData = async () => {
    try {
      await Promise.all([
        loadStats(),
        loadReferrals(),
        loadRewards(),
      ]);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const generateUniqueCode = (): string => {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 8; i++) {
      code += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    return code;
  };

  const generateReferralCode = async () => {
    if (!user || generatingCode) return;

    setGeneratingCode(true);
    try {
      console.log('Generating new referral code...');

      let code = generateUniqueCode();
      let attempts = 0;
      let inserted = false;

      while (!inserted && attempts < 10) {
        console.log(`Attempt ${attempts + 1}: Trying code ${code}`);

        const { error: insertError } = await supabase
          .from('referral_codes')
          .insert({
            user_id: user.id,
            code: code,
          });

        if (!insertError) {
          console.log('Code inserted successfully:', code);
          inserted = true;
        } else if (insertError.code === '23505') {
          console.log('Code already exists, generating new one...');
          code = generateUniqueCode();
          attempts++;
        } else {
          console.error('Insert error:', insertError);
          throw insertError;
        }
      }

      if (!inserted) {
        throw new Error('Failed to generate unique code after 10 attempts');
      }

      console.log('Code inserted successfully, reloading stats...');

      await new Promise(resolve => setTimeout(resolve, 500));

      const { data: statsData } = await supabase.rpc('get_referral_stats', {
        p_user_id: user.id,
      });

      if (statsData) {
        console.log('Updated stats:', statsData);
        setStats(statsData);
      }
    } catch (error: any) {
      console.error('Error generating referral code:', error);
      console.error('Error details:', {
        message: error?.message,
        code: error?.code,
        details: error?.details,
        hint: error?.hint,
        full: error
      });
      const errorMessage = error?.message || error?.error_description || error?.code || 'Unknown error';
      alert(`Failed to generate referral code.\n\nError: ${errorMessage}\n\nCheck console (F12) for full details.`);
    } finally {
      setGeneratingCode(false);
    }
  };

  const loadStats = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase.rpc('get_referral_stats', {
        p_user_id: user.id,
      });

      if (error) {
        console.error('Error loading stats:', error);
        throw error;
      }

      console.log('Loaded stats:', data);

      setStats(data);
    } catch (error) {
      console.error('loadStats error:', error);
      setStats(null);
    }
  };

  const loadReferrals = async () => {
    try {
      const { data, error } = await supabase
        .from('referrals')
        .select(`
          *,
          referred:profiles!referrals_referred_id_fkey(full_name)
        `)
        .eq('referrer_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setReferrals(data || []);
    } catch (error) {

    }
  };

  const loadRewards = async () => {
    try {
      const { data, error } = await supabase
        .from('referral_rewards')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setRewards(data || []);
    } catch (error) {

    }
  };

  const copyReferralCode = async () => {
    if (!stats?.code) return;

    // Use production domain
    const referralLink = `https://souvenirpickers.com?ref=${stats.code}`;

    try {
      await navigator.clipboard.writeText(referralLink);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (error) {
      console.error('Failed to copy link:', error);
    }
  };

  const shareOnSocial = async (platform: string) => {
    if (!stats?.code) return;

    // Use production domain
    const referralLink = `https://souvenirpickers.com?ref=${stats.code}`;

    // Create engaging message with the code
    const text = isPicker
      ? `Join SouvenirPickers as a picker and start earning money! 💰\n\nUse my referral code: ${stats.code}\n\n${referralLink}`
      : `Get authentic souvenirs from around the world! 🎁\n\nUse code ${stats.code} for €5 off your first order!\n\n${referralLink}`;

    // For Facebook, copy message to clipboard first (Facebook doesn't allow pre-filled text)
    if (platform === 'facebook') {
      try {
        await navigator.clipboard.writeText(text);
        showToast('success', 'Message copied! Paste it on Facebook to share with your friends');
        // Wait a moment so user sees the notification
        setTimeout(() => {
          window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(referralLink)}`, '_blank', 'width=600,height=400');
        }, 500);
      } catch (error) {
        console.error('Failed to copy to clipboard:', error);
        showToast('error', 'Please copy your referral message manually');
        window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(referralLink)}`, '_blank', 'width=600,height=400');
      }
      return;
    }

    // For WhatsApp and Twitter, they support pre-filled text
    let url = '';
    switch (platform) {
      case 'twitter':
        url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}`;
        break;
      case 'whatsapp':
        url = `https://wa.me/?text=${encodeURIComponent(text)}`;
        break;
    }

    if (url) {
      window.open(url, '_blank', 'width=600,height=400');
    }
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-gray-500">Loading...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Referral Program</h1>
        <p className="text-gray-600">Earn rewards by inviting friends to SouvenirPickers</p>
      </div>

      {hasReferralDiscount && (
        <div className="mb-8 bg-gradient-to-r from-green-500 to-green-600 rounded-2xl p-6 text-white shadow-lg">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-white/20 rounded-full flex items-center justify-center">
              <Gift className="w-8 h-8" />
            </div>
            <div className="flex-1">
              <h3 className="text-2xl font-bold mb-1">You Have a Discount!</h3>
              <p className="text-green-50 text-lg">
                You have <strong>€{profile.referral_discount_amount.toFixed(2)}</strong> available to use on your next order.
              </p>
              <p className="text-green-100 text-sm mt-2">
                This discount will be automatically applied at checkout!
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="grid md:grid-cols-3 gap-6 mb-8">
        <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl p-6 text-white">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center">
              <Users className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm opacity-90">Total Referrals</p>
              <p className="text-3xl font-bold">{stats?.total_referrals || 0}</p>
            </div>
          </div>
          <div className="flex gap-4 text-sm">
            <span className="opacity-90">✓ {stats?.completed_referrals || 0} completed</span>
            <span className="opacity-90">⏳ {stats?.pending_referrals || 0} pending</span>
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-6 text-white">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center">
              <Euro className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm opacity-90">Total Earned</p>
              <p className="text-3xl font-bold">€{(stats?.total_rewards || 0).toFixed(2)}</p>
            </div>
          </div>
          <p className="text-sm opacity-90">Lifetime earnings from referrals</p>
        </div>

        <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-2xl p-6 text-white">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 bg-white/20 rounded-xl flex items-center justify-center">
              <Gift className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm opacity-90">Available</p>
              <p className="text-3xl font-bold">€{(stats?.available_rewards || 0).toFixed(2)}</p>
            </div>
          </div>
          <p className="text-sm opacity-90">
            {isPicker ? 'Ready to use as platform credits' : 'Ready to use on your next order'}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-lg p-8 mb-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Your Referral Code</h2>
        <p className="text-gray-600 mb-6">
          {isPicker ? (
            <>
              Share your code with friends to help grow the SouvenirPickers community!
              Earn <strong>€10</strong> when your referred picker completes their first sale, or when a referred collector places their first order.
            </>
          ) : (
            <>
              Share your unique code with friends. They get <strong>€5 off</strong> their first order, and you earn <strong>€10</strong> when they complete it!
            </>
          )}
        </p>

        <div className="flex flex-col md:flex-row gap-4 mb-6">
          <div className="flex-1 flex items-center gap-3 bg-gray-50 border-2 border-gray-300 rounded-lg p-4">
            {generatingCode ? (
              <div className="flex-1 flex items-center justify-center gap-2 text-gray-500">
                <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
                <span>Generating your code...</span>
              </div>
            ) : stats?.code ? (
              <>
                <code className="flex-1 text-2xl font-bold text-blue-600">{stats.code}</code>
                <button
                  onClick={copyReferralCode}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  {copied ? (
                    <>
                      <Check className="w-5 h-5" />
                      Copied!
                    </>
                  ) : (
                    <>
                      <Copy className="w-5 h-5" />
                      Copy Link
                    </>
                  )}
                </button>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-between">
                <span className="text-gray-500">No referral code found</span>
                <button
                  onClick={generateReferralCode}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                >
                  <Gift className="w-5 h-5" />
                  Generate Code
                </button>
              </div>
            )}
          </div>
        </div>

        <div className="space-y-3">
          <p className="text-sm text-gray-500">
            <strong>Facebook tip:</strong> Click the button below to copy your message, then paste it when Facebook opens!
          </p>
          <div className="flex flex-wrap gap-3">
            <button
              onClick={async () => {
                if (!stats?.code) return;
                const referralLink = `https://souvenirpickers.com?ref=${stats.code}`;
                const text = isPicker
                  ? `Join SouvenirPickers as a picker and start earning money! 💰\n\nUse my referral code: ${stats.code}\n\n${referralLink}`
                  : `Get authentic souvenirs from around the world! 🎁\n\nUse code ${stats.code} for €5 off your first order!\n\n${referralLink}`;
                try {
                  await navigator.clipboard.writeText(text);
                  showToast('success', 'Message copied! Now paste it on your favorite social network');
                } catch (error) {
                  showToast('error', 'Failed to copy message');
                }
              }}
              className="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors flex items-center gap-2"
            >
              <Copy className="w-5 h-5" />
              Copy Message
            </button>
            <button
              onClick={() => shareOnSocial('facebook')}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Share on Facebook
            </button>
            <button
              onClick={() => shareOnSocial('whatsapp')}
              className="px-6 py-3 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
            >
              Share on WhatsApp
            </button>
            <button
              onClick={() => shareOnSocial('twitter')}
              className="px-6 py-3 bg-sky-500 text-white rounded-lg hover:bg-sky-600 transition-colors"
            >
              Share on Twitter
            </button>
          </div>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-8">
        <div className="bg-white rounded-2xl shadow-lg p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Users className="w-6 h-6 text-blue-600" />
            Your Referrals
          </h3>

          {referrals.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <p>No referrals yet. Start sharing your code!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {referrals.map((referral) => (
                <div
                  key={referral.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div>
                    <p className="font-medium text-gray-900">
                      {referral.referred?.full_name || 'New User'}
                    </p>
                    <p className="text-sm text-gray-500">
                      {new Date(referral.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  <span
                    className={`px-3 py-1 rounded-full text-sm font-medium ${
                      referral.status === 'completed'
                        ? 'bg-green-100 text-green-700'
                        : 'bg-yellow-100 text-yellow-700'
                    }`}
                  >
                    {referral.status === 'completed' ? '✓ Completed' : '⏳ Pending'}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-white rounded-2xl shadow-lg p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Gift className="w-6 h-6 text-green-600" />
            Your Rewards
          </h3>

          {rewards.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <p>No rewards yet. Keep referring friends!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {rewards.map((reward) => (
                <div
                  key={reward.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex-1">
                    <p className="font-medium text-gray-900">
                      {reward.reward_type === 'referral_bonus' ? 'Referral Bonus' : 'Signup Bonus'}
                    </p>
                    <p className="text-sm text-gray-500">
                      {new Date(reward.created_at).toLocaleDateString()}
                    </p>
                    {reward.expires_at && !reward.redeemed && (
                      <p className="text-xs text-orange-600 flex items-center gap-1 mt-1">
                        <Clock className="w-3 h-3" />
                        Expires {new Date(reward.expires_at).toLocaleDateString()}
                      </p>
                    )}
                  </div>
                  <div className="text-right">
                    <p className="text-xl font-bold text-green-600">
                      €{reward.reward_value.toFixed(2)}
                    </p>
                    {reward.redeemed && (
                      <span className="text-xs text-gray-500">Redeemed</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="mt-8 bg-blue-50 border-2 border-blue-200 rounded-2xl p-6">
        <h3 className="text-xl font-bold text-gray-900 mb-4">How It Works</h3>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold flex-shrink-0">
              1
            </div>
            <div>
              <h4 className="font-semibold text-gray-900 mb-1">Share Your Code</h4>
              <p className="text-sm text-gray-600">
                Send your unique referral code to friends via social media or direct link
              </p>
            </div>
          </div>
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold flex-shrink-0">
              2
            </div>
            <div>
              <h4 className="font-semibold text-gray-900 mb-1">They Join</h4>
              <p className="text-sm text-gray-600">
                {isPicker ? (
                  <>Your friend joins SouvenirPickers as a picker or collector</>
                ) : (
                  <>Your friend joins SouvenirPickers and gets €5 off their first order</>
                )}
              </p>
            </div>
          </div>
          <div className="flex gap-3">
            <div className="w-10 h-10 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold flex-shrink-0">
              3
            </div>
            <div>
              <h4 className="font-semibold text-gray-900 mb-1">You Earn Rewards</h4>
              <p className="text-sm text-gray-600">
                {isPicker ? (
                  <>Earn €10 when your referral completes their first sale or order</>
                ) : (
                  <>When they complete their first order, you earn €10 in credits</>
                )}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
