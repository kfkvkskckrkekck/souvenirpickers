import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Shield, TrendingUp, Star, Clock, CheckCircle, Award, BarChart3 } from 'lucide-react';
import SouvenirLoader from './SouvenirLoader';

interface TrustScore {
  overall_score: number;
  verification_score: number;
  transaction_score: number;
  review_score: number;
  responsiveness_score: number;
  completed_orders: number;
  successful_transactions: number;
  disputes_filed: number;
  disputes_against: number;
  last_calculated_at: string;
}

export default function TrustScoreView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [trustScore, setTrustScore] = useState<TrustScore | null>(null);
  const [calculating, setCalculating] = useState(false);

  useEffect(() => {
    loadTrustScore();
  }, [user]);

  const loadTrustScore = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('trust_scores')
        .select('*')
        .eq('user_id', user?.id)
        .maybeSingle();

      if (error) throw error;
      setTrustScore(data);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const recalculateScore = async () => {
    try {
      setCalculating(true);
      const { data, error } = await supabase.rpc('calculate_trust_score', {
        p_user_id: user?.id
      });

      if (error) throw error;
      await loadTrustScore();
      alert('Trust score updated successfully!');
    } catch (error) {

      alert('Failed to update trust score');
    } finally {
      setCalculating(false);
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 80) return 'text-green-600 bg-green-100 border-green-300';
    if (score >= 60) return 'text-blue-600 bg-blue-100 border-blue-300';
    if (score >= 40) return 'text-yellow-600 bg-yellow-100 border-yellow-300';
    return 'text-red-600 bg-red-100 border-red-300';
  };

  const getScoreLabel = (score: number) => {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  };

  const getComponentColor = (current: number, max: number) => {
    const percentage = (current / max) * 100;
    if (percentage >= 80) return 'bg-green-500';
    if (percentage >= 60) return 'bg-blue-500';
    if (percentage >= 40) return 'bg-yellow-500';
    return 'bg-red-500';
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading trust score..." />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
            <Shield className="w-8 h-8 text-blue-600" />
            Your Trust Score
          </h1>
          <p className="text-gray-600">Build trust through verified transactions and positive reviews</p>
        </div>
        <button
          onClick={recalculateScore}
          disabled={calculating}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 flex items-center gap-2"
        >
          {calculating ? (
            <>
              <Clock className="w-5 h-5 animate-spin" />
              Updating...
            </>
          ) : (
            <>
              <TrendingUp className="w-5 h-5" />
              Refresh Score
            </>
          )}
        </button>
      </div>

      <div className="mb-8 bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-6 border-2 border-blue-200">
        <div className="flex items-start gap-4">
          <div className="bg-blue-600 p-3 rounded-lg flex-shrink-0">
            <BarChart3 className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">How Trust Scores Work</h3>
            <p className="text-gray-700 mb-3">
              Your trust score is calculated based on four key components. The higher your score, the more trust you build with other users.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <div className="flex items-center gap-2 mb-1">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                  <span className="font-semibold text-gray-900">Verification (25 pts)</span>
                </div>
                <p className="text-sm text-gray-600">Complete identity verification</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <div className="flex items-center gap-2 mb-1">
                  <Award className="w-5 h-5 text-blue-600" />
                  <span className="font-semibold text-gray-900">Transactions (35 pts)</span>
                </div>
                <p className="text-sm text-gray-600">Complete successful orders</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <div className="flex items-center gap-2 mb-1">
                  <Star className="w-5 h-5 text-yellow-600" />
                  <span className="font-semibold text-gray-900">Reviews (25 pts)</span>
                </div>
                <p className="text-sm text-gray-600">Receive positive reviews</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-blue-200">
                <div className="flex items-center gap-2 mb-1">
                  <Clock className="w-5 h-5 text-purple-600" />
                  <span className="font-semibold text-gray-900">Responsiveness (15 pts)</span>
                </div>
                <p className="text-sm text-gray-600">Reply quickly to messages</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {trustScore ? (
        <>
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8 mb-8">
            <div className="text-center mb-8">
              <div className={`inline-flex items-center gap-3 px-6 py-3 rounded-full border-2 text-2xl font-bold ${getScoreColor(trustScore.overall_score)}`}>
                <Shield className="w-8 h-8" />
                {trustScore.overall_score}/100
              </div>
              <p className="text-lg font-semibold text-gray-700 mt-3">
                {getScoreLabel(trustScore.overall_score)} Trust Score
              </p>
              <p className="text-sm text-gray-500 mt-1">
                Last updated: {new Date(trustScore.last_calculated_at).toLocaleDateString()}
              </p>
            </div>

            <div className="w-full bg-gray-200 rounded-full h-4 mb-8">
              <div
                className={`h-4 rounded-full transition-all ${getComponentColor(trustScore.overall_score, 100)}`}
                style={{ width: `${trustScore.overall_score}%` }}
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-green-50 rounded-lg p-4 border border-green-200">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <CheckCircle className="w-5 h-5 text-green-600" />
                    <span className="font-semibold text-gray-900">Verification</span>
                  </div>
                  <span className="text-lg font-bold text-green-600">{trustScore.verification_score}/25</span>
                </div>
                <div className="w-full bg-green-200 rounded-full h-2">
                  <div
                    className="bg-green-600 h-2 rounded-full"
                    style={{ width: `${(trustScore.verification_score / 25) * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-600 mt-2">
                  {trustScore.verification_score === 25
                    ? 'Fully verified'
                    : trustScore.verification_score > 0
                    ? 'Verification pending'
                    : 'Complete identity verification to earn 25 points'}
                </p>
              </div>

              <div className="bg-blue-50 rounded-lg p-4 border border-blue-200">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Award className="w-5 h-5 text-blue-600" />
                    <span className="font-semibold text-gray-900">Transactions</span>
                  </div>
                  <span className="text-lg font-bold text-blue-600">{trustScore.transaction_score}/35</span>
                </div>
                <div className="w-full bg-blue-200 rounded-full h-2">
                  <div
                    className="bg-blue-600 h-2 rounded-full"
                    style={{ width: `${(trustScore.transaction_score / 35) * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-600 mt-2">
                  {trustScore.completed_orders} completed orders · Earn 3 points per order
                </p>
              </div>

              <div className="bg-yellow-50 rounded-lg p-4 border border-yellow-200">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Star className="w-5 h-5 text-yellow-600" />
                    <span className="font-semibold text-gray-900">Reviews</span>
                  </div>
                  <span className="text-lg font-bold text-yellow-600">{trustScore.review_score}/25</span>
                </div>
                <div className="w-full bg-yellow-200 rounded-full h-2">
                  <div
                    className="bg-yellow-600 h-2 rounded-full"
                    style={{ width: `${(trustScore.review_score / 25) * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-600 mt-2">
                  Based on your average rating · Higher ratings earn more points
                </p>
              </div>

              <div className="bg-purple-50 rounded-lg p-4 border border-purple-200">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Clock className="w-5 h-5 text-purple-600" />
                    <span className="font-semibold text-gray-900">Responsiveness</span>
                  </div>
                  <span className="text-lg font-bold text-purple-600">{trustScore.responsiveness_score}/15</span>
                </div>
                <div className="w-full bg-purple-200 rounded-full h-2">
                  <div
                    className="bg-purple-600 h-2 rounded-full"
                    style={{ width: `${(trustScore.responsiveness_score / 15) * 100}%` }}
                  />
                </div>
                <p className="text-xs text-gray-600 mt-2">
                  Reply to messages quickly to maintain high score
                </p>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center gap-3 mb-2">
                <div className="bg-green-100 p-2 rounded-lg">
                  <CheckCircle className="w-5 h-5 text-green-600" />
                </div>
                <span className="text-sm font-medium text-gray-600">Successful Transactions</span>
              </div>
              <p className="text-3xl font-bold text-gray-900">{trustScore.successful_transactions}</p>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center gap-3 mb-2">
                <div className="bg-blue-100 p-2 rounded-lg">
                  <Award className="w-5 h-5 text-blue-600" />
                </div>
                <span className="text-sm font-medium text-gray-600">Completed Orders</span>
              </div>
              <p className="text-3xl font-bold text-gray-900">{trustScore.completed_orders}</p>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div className="flex items-center gap-3 mb-2">
                <div className="bg-yellow-100 p-2 rounded-lg">
                  <TrendingUp className="w-5 h-5 text-yellow-600" />
                </div>
                <span className="text-sm font-medium text-gray-600">Disputes</span>
              </div>
              <p className="text-3xl font-bold text-gray-900">
                {trustScore.disputes_filed + trustScore.disputes_against}
              </p>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 className="text-lg font-bold text-gray-900 mb-4">How to Improve Your Score</h3>
            <div className="space-y-3">
              {trustScore.verification_score < 25 && (
                <div className="flex items-start gap-3 p-3 bg-green-50 border border-green-200 rounded-lg">
                  <CheckCircle className="w-5 h-5 text-green-600 mt-0.5" />
                  <div>
                    <p className="font-semibold text-gray-900">Complete Identity Verification</p>
                    <p className="text-sm text-gray-600">Earn +{25 - trustScore.verification_score} points</p>
                  </div>
                </div>
              )}
              {trustScore.transaction_score < 35 && (
                <div className="flex items-start gap-3 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                  <Award className="w-5 h-5 text-blue-600 mt-0.5" />
                  <div>
                    <p className="font-semibold text-gray-900">Complete More Orders</p>
                    <p className="text-sm text-gray-600">Earn up to +{35 - trustScore.transaction_score} points (3 points per order)</p>
                  </div>
                </div>
              )}
              {trustScore.review_score < 25 && (
                <div className="flex items-start gap-3 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <Star className="w-5 h-5 text-yellow-600 mt-0.5" />
                  <div>
                    <p className="font-semibold text-gray-900">Improve Your Ratings</p>
                    <p className="text-sm text-gray-600">Provide excellent service to earn +{25 - trustScore.review_score} points</p>
                  </div>
                </div>
              )}
            </div>
          </div>
        </>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center">
          <Shield className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-3">No Trust Score Yet</h3>
          <p className="text-gray-600 mb-6">
            Your trust score will be calculated once you start using the platform. Complete your profile, verify your identity, and start transactions to build your trust score.
          </p>
          <button
            onClick={recalculateScore}
            disabled={calculating}
            className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50 inline-flex items-center gap-2"
          >
            <TrendingUp className="w-5 h-5" />
            Calculate My Score
          </button>
        </div>
      )}
    </div>
  );
}
