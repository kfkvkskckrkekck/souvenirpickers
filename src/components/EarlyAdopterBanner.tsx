import { useState, useEffect } from 'react';
import { Users, Zap, TrendingUp } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface EarlyAdopterBannerProps {
  forceShow?: boolean;
}

export function EarlyAdopterBanner({ forceShow = false }: EarlyAdopterBannerProps = {}) {
  const [spotsLeft, setSpotsLeft] = useState<number | null>(null);
  const [totalCount, setTotalCount] = useState<number>(0);
  const [maxCount, setMaxCount] = useState<number>(200);

  useEffect(() => {
    fetchStats();

    const channel = supabase
      .channel('early-adopter-stats')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'early_adopter_stats'
        },
        (payload) => {
          const data = payload.new as { total_count: number; max_count: number };
          setTotalCount(data.total_count);
          setMaxCount(data.max_count);
          setSpotsLeft(data.max_count - data.total_count);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchStats = async () => {
    const { data, error } = await supabase
      .from('early_adopter_stats')
      .select('total_count, max_count')
      .eq('id', 1)
      .maybeSingle();

    if (data && !error) {
      setTotalCount(data.total_count);
      setMaxCount(data.max_count);
      setSpotsLeft(data.max_count - data.total_count);
    }
  };

  if (!forceShow && (spotsLeft === null || spotsLeft <= 0)) {
    return null;
  }

  // Always show if forceShow is true, otherwise check spots
  if (spotsLeft === null && !forceShow) {
    return null;
  }

  const percentageFilled = (totalCount / maxCount) * 100;
  const isUrgent = (spotsLeft || 0) <= 50;
  const displaySpotsLeft = spotsLeft || 200;

  return (
    <div className={`w-full ${isUrgent ? 'bg-gradient-to-r from-orange-500 to-red-500' : 'bg-gradient-to-r from-blue-600 to-blue-700'} text-white shadow-lg`}>
      <div className="max-w-7xl mx-auto px-3 sm:px-4 lg:px-6 py-4 sm:py-5 lg:py-6">
        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-3 lg:gap-4">
          <div className="flex items-start gap-2 sm:gap-3 w-full lg:w-auto">
            <div className={`${isUrgent ? 'bg-white/20' : 'bg-white/20'} p-2 sm:p-2.5 rounded-lg flex-shrink-0`}>
              <Zap className="w-5 h-5 sm:w-6 sm:h-6" />
            </div>
            <div className="flex-1 min-w-0">
              <h3 className="text-base sm:text-lg lg:text-xl font-bold mb-0.5 sm:mb-1 leading-tight">
                Limited Launch Offer - First {maxCount} Pickers!
              </h3>
              <p className="text-white/90 text-xs sm:text-sm leading-snug">
                No subscription fee ever. Pay only 10% commission on sales.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 sm:gap-4 lg:gap-5 w-full lg:w-auto justify-center lg:justify-end flex-shrink-0">
            <div className="text-center bg-white/10 px-3 sm:px-4 lg:px-5 py-2.5 sm:py-3 rounded-lg flex-1 sm:flex-initial">
              <div className="flex items-center justify-center gap-1.5 mb-0.5">
                <Users className="w-4 h-4 sm:w-5 sm:h-5" />
                <span className="text-2xl sm:text-3xl lg:text-4xl font-bold leading-none">{displaySpotsLeft}</span>
              </div>
              <p className="text-xs sm:text-sm text-white/90 font-medium whitespace-nowrap">Spots Left</p>
            </div>

            <div className="hidden sm:block w-px h-12 lg:h-14 bg-white/30"></div>

            <div className="text-center bg-white/10 px-3 sm:px-4 lg:px-5 py-2.5 sm:py-3 rounded-lg flex-1 sm:flex-initial">
              <div className="flex items-center justify-center gap-1.5 mb-0.5">
                <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5" />
                <span className="text-xl sm:text-2xl lg:text-3xl font-bold leading-none">{totalCount}/{maxCount}</span>
              </div>
              <p className="text-xs sm:text-sm text-white/90 font-medium whitespace-nowrap">Early Adopters</p>
            </div>
          </div>
        </div>

        <div className="mt-3 sm:mt-4 lg:mt-5">
          <div className="w-full bg-white/20 rounded-full h-2 sm:h-2.5 overflow-hidden shadow-inner">
            <div
              className="bg-white h-full transition-all duration-500 ease-out rounded-full shadow-lg"
              style={{ width: `${percentageFilled}%` }}
            ></div>
          </div>
          <p className="text-center text-xs sm:text-sm text-white font-medium mt-1.5 sm:mt-2 leading-tight">
            {isUrgent ? '🔥 Hurry! Less than 50 spots remaining!' : '✨ Join now and lock in lifetime savings!'}
          </p>
        </div>
      </div>
    </div>
  );
}
