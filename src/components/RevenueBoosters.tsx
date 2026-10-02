import { useState, useEffect } from 'react';
import { TrendingUp, DollarSign, Zap, AlertCircle, CheckCircle, XCircle, ArrowRight, Sparkles } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

type RevenueInsight = {
  id: string;
  insight_type: string;
  title: string;
  description: string;
  potential_revenue: number;
  priority: 'high' | 'medium' | 'low';
  action_url: string | null;
  action_label: string;
  status: string;
  created_at: string;
};

type RevenueBootersProps = {
  onViewChange?: (view: string) => void;
  compact?: boolean;
};

export function RevenueBoosters({ onViewChange, compact = false }: RevenueBootersProps) {
  const { user } = useAuth();
  const [insights, setInsights] = useState<RevenueInsight[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalPotential, setTotalPotential] = useState(0);
  const [dismissing, setDismissing] = useState<string | null>(null);

  useEffect(() => {
    if (user) {
      generateAndLoadInsights();
    }
  }, [user]);

  const generateAndLoadInsights = async () => {
    if (!user) return;

    try {
      const { error: generateError } = await supabase.rpc('generate_revenue_insights', {
        p_picker_id: user.id,
      });

      if (generateError) {

      }

      const { data: insightsData, error: insightsError } = await supabase
        .from('revenue_insights')
        .select('*')
        .eq('picker_id', user.id)
        .eq('status', 'active')
        .order('priority', { ascending: true })
        .order('potential_revenue', { ascending: false });

      if (insightsError) throw insightsError;

      setInsights(insightsData || []);

      const total = (insightsData || []).reduce((sum, insight) => sum + Number(insight.potential_revenue), 0);
      setTotalPotential(total);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const handleDismiss = async (insightId: string) => {
    setDismissing(insightId);
    try {
      const { error } = await supabase
        .from('revenue_insights')
        .update({ status: 'dismissed' })
        .eq('id', insightId);

      if (error) throw error;

      await supabase.from('revenue_booster_actions').insert({
        picker_id: user!.id,
        insight_id: insightId,
        action_type: 'dismissed',
      });

      setInsights(insights.filter(i => i.id !== insightId));
      setTotalPotential(prev => prev - (insights.find(i => i.id === insightId)?.potential_revenue || 0));
    } catch (error) {

    } finally {
      setDismissing(null);
    }
  };

  const handleTakeAction = async (insight: RevenueInsight) => {
    try {
      await supabase.from('revenue_booster_actions').insert({
        picker_id: user!.id,
        insight_id: insight.id,
        action_type: 'clicked',
      });

      if (insight.action_url && onViewChange) {
        onViewChange(insight.action_url);
      }
    } catch (error) {

    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high':
        return 'bg-red-100 text-red-800 border-red-200';
      case 'medium':
        return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      case 'low':
        return 'bg-blue-100 text-blue-800 border-blue-200';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  const getPriorityIcon = (priority: string) => {
    switch (priority) {
      case 'high':
        return <AlertCircle className="w-5 h-5" />;
      case 'medium':
        return <Zap className="w-5 h-5" />;
      default:
        return <TrendingUp className="w-5 h-5" />;
    }
  };

  if (loading) {
    if (compact) {
      return <SouvenirLoader message="Loading revenue insights..." />;
    }
    return (
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading revenue insights..." />
      </div>
    );
  }

  if (compact && insights.length === 0) {
    return null;
  }

  if (compact) {
    return (
      <div className="bg-gradient-to-br from-green-50 to-blue-50 rounded-2xl p-6 border-2 border-green-200">
        <div className="flex items-start justify-between mb-4">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <Sparkles className="w-6 h-6 text-green-600" />
              <h3 className="text-xl font-bold text-gray-900">Revenue Boosters</h3>
            </div>
            <p className="text-sm text-gray-600">Unlock your earning potential</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-600">Potential Increase</p>
            <p className="text-2xl font-bold text-green-600">+€{totalPotential.toFixed(0)}</p>
          </div>
        </div>

        <div className="space-y-3">
          {insights.slice(0, 3).map((insight) => (
            <div
              key={insight.id}
              className="bg-white rounded-lg p-4 border border-gray-200 hover:border-green-300 transition-colors"
            >
              <div className="flex items-start justify-between mb-2">
                <h4 className="font-semibold text-gray-900 flex-1">{insight.title}</h4>
                <span className={`text-xs font-medium px-2 py-1 rounded-full ${getPriorityColor(insight.priority)}`}>
                  {insight.priority}
                </span>
              </div>
              <p className="text-sm text-gray-600 mb-3">{insight.description}</p>
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-green-600">
                  +€{insight.potential_revenue.toFixed(0)} potential
                </span>
                {insight.action_url && (
                  <button
                    onClick={() => handleTakeAction(insight)}
                    className="text-sm text-blue-600 hover:text-blue-700 font-medium flex items-center gap-1"
                  >
                    {insight.action_label}
                    <ArrowRight className="w-4 h-4" />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>

        {insights.length > 3 && (
          <button
            onClick={() => onViewChange?.('revenue-boosters')}
            className="w-full mt-4 text-center text-sm text-blue-600 hover:text-blue-700 font-medium"
          >
            View all {insights.length} recommendations →
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Sparkles className="w-8 h-8 text-green-600" />
          <h1 className="text-3xl font-bold text-gray-900">Revenue Boosters</h1>
        </div>
        <p className="text-gray-600">Personalized recommendations to maximize your earnings</p>
      </div>

      {totalPotential > 0 && (
        <div className="bg-gradient-to-r from-green-500 to-blue-500 rounded-2xl p-8 mb-8 text-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-100 mb-1">Total Revenue Potential</p>
              <p className="text-4xl font-bold">+€{totalPotential.toFixed(0)}</p>
              <p className="text-green-100 mt-2">
                By implementing {insights.length} recommendation{insights.length !== 1 ? 's' : ''}
              </p>
            </div>
            <DollarSign className="w-24 h-24 text-white opacity-20" />
          </div>
        </div>
      )}

      {insights.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h3 className="text-2xl font-bold text-gray-900 mb-2">You're All Set!</h3>
          <p className="text-gray-600">
            Great job! You're following best practices. We'll notify you when new opportunities arise.
          </p>
        </div>
      ) : (
        <div className="space-y-6">
          {insights.map((insight) => (
            <div
              key={insight.id}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow"
            >
              <div className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-start gap-4 flex-1">
                    <div className={`p-3 rounded-lg ${getPriorityColor(insight.priority)}`}>
                      {getPriorityIcon(insight.priority)}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-xl font-bold text-gray-900">{insight.title}</h3>
                        <span
                          className={`text-xs font-medium px-3 py-1 rounded-full uppercase tracking-wider ${getPriorityColor(insight.priority)}`}
                        >
                          {insight.priority} Priority
                        </span>
                      </div>
                      <p className="text-gray-600 mb-4">{insight.description}</p>
                      <div className="flex items-center gap-2 text-green-700 font-semibold">
                        <DollarSign className="w-5 h-5" />
                        <span>Potential increase: €{insight.potential_revenue.toFixed(0)}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-3 pt-4 border-t border-gray-200">
                  {insight.action_url && (
                    <button
                      onClick={() => handleTakeAction(insight)}
                      className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                    >
                      {insight.action_label}
                      <ArrowRight className="w-5 h-5" />
                    </button>
                  )}
                  <button
                    onClick={() => handleDismiss(insight.id)}
                    disabled={dismissing === insight.id}
                    className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition-colors flex items-center gap-2 disabled:opacity-50"
                  >
                    <XCircle className="w-5 h-5" />
                    Dismiss
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
