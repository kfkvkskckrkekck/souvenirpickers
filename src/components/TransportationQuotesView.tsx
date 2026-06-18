import { useState, useEffect } from 'react';
import { TruckIcon, CheckCircle, XCircle, Clock, MapPin, Package, DollarSign } from 'lucide-react';
import { supabase, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type TransportationQuote = {
  id: string;
  conversation_id: string;
  picker_id: string;
  client_id: string;
  from_location: string;
  to_location: string;
  item_description: string;
  transportation_cost: number;
  estimated_delivery_days: number | null;
  notes: string | null;
  status: string;
  accepted_at: string | null;
  expires_at: string;
  created_at: string;
  picker?: Profile;
};

export function TransportationQuotesView() {
  const { user, profile } = useAuth();
  const [quotes, setQuotes] = useState<TransportationQuote[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedQuote, setSelectedQuote] = useState<TransportationQuote | null>(null);
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    if (user) {
      loadQuotes();
    }
  }, [user, profile]);

  const loadQuotes = async () => {
    try {
      let query = supabase
        .from('transportation_quotes')
        .select(`
          *,
          picker:profiles!transportation_quotes_picker_id_fkey(*)
        `)
        .order('created_at', { ascending: false });

      if (profile?.user_type === 'picker') {
        query = query.eq('picker_id', user?.id);
      } else {
        query = query.eq('client_id', user?.id);
      }

      const { data, error } = await query;

      if (error) throw error;
      setQuotes(data || []);
    } catch (error) {
      console.error('Error loading quotes:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAcceptQuote = async (quoteId: string) => {
    setProcessing(true);
    try {
      const { error } = await supabase
        .from('transportation_quotes')
        .update({
          status: 'accepted',
          accepted_at: new Date().toISOString(),
        })
        .eq('id', quoteId);

      if (error) throw error;

      setSelectedQuote(null);
      loadQuotes();
    } catch (error) {
      console.error('Error accepting quote:', error);
      alert('Failed to accept quote');
    } finally {
      setProcessing(false);
    }
  };

  const handleRejectQuote = async (quoteId: string) => {
    setProcessing(true);
    try {
      const { error } = await supabase
        .from('transportation_quotes')
        .update({ status: 'rejected' })
        .eq('id', quoteId);

      if (error) throw error;

      setSelectedQuote(null);
      loadQuotes();
    } catch (error) {
      console.error('Error rejecting quote:', error);
      alert('Failed to reject quote');
    } finally {
      setProcessing(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges = {
      pending: { color: 'bg-yellow-100 text-yellow-800', text: 'Pending' },
      accepted: { color: 'bg-green-100 text-green-800', text: 'Accepted' },
      rejected: { color: 'bg-red-100 text-red-800', text: 'Rejected' },
      expired: { color: 'bg-gray-100 text-gray-800', text: 'Expired' },
    };
    const badge = badges[status as keyof typeof badges] || badges.pending;
    return (
      <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${badge.color}`}>
        {badge.text}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Loading transportation quotes...</div>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Transportation Quotes</h1>
        <p className="text-gray-600 mt-1">
          {profile?.user_type === 'picker'
            ? 'Transportation quotes you have sent to collectors'
            : 'Transportation quotes from pickers'}
        </p>
      </div>

      {quotes.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
          <TruckIcon className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-500 text-lg">No transportation quotes yet</p>
          <p className="text-gray-400 text-sm mt-2">
            {profile?.user_type === 'picker'
              ? 'Send transportation quotes to collectors through messages'
              : 'Transportation quotes from pickers will appear here'}
          </p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {quotes.map((quote) => (
            <div
              key={quote.id}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow"
            >
              <div className="bg-gradient-to-r from-orange-500 to-orange-600 p-4">
                <div className="flex items-center justify-between text-white">
                  <div className="flex items-center gap-2">
                    <TruckIcon className="w-6 h-6" />
                    <span className="font-semibold">Transportation Quote</span>
                  </div>
                  {getStatusBadge(quote.status)}
                </div>
              </div>

              <div className="p-6">
                {profile?.user_type === 'client' && quote.picker && (
                  <p className="text-sm text-gray-600 mb-3">
                    From: <span className="font-medium">{quote.picker.full_name}</span>
                  </p>
                )}

                <div className="space-y-3 mb-4">
                  <div className="flex items-start gap-2 text-sm">
                    <MapPin className="w-4 h-4 text-blue-600 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="font-medium text-gray-900">From: {quote.from_location}</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 text-sm">
                    <MapPin className="w-4 h-4 text-green-600 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="font-medium text-gray-900">To: {quote.to_location}</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 text-sm">
                    <Package className="w-4 h-4 text-gray-600 mt-0.5 flex-shrink-0" />
                    <p className="text-gray-700">{quote.item_description}</p>
                  </div>
                </div>

                <div className="bg-orange-50 rounded-lg p-3 mb-4">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-sm font-medium text-gray-700">Transportation Cost:</span>
                    <span className="text-xl font-bold text-orange-600">
                      €{quote.transportation_cost.toFixed(2)}
                    </span>
                  </div>
                  {quote.estimated_delivery_days && (
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Clock className="w-4 h-4" />
                      <span>Est. delivery: {quote.estimated_delivery_days} days</span>
                    </div>
                  )}
                </div>

                {quote.notes && (
                  <div className="text-sm text-gray-600 mb-4 p-3 bg-gray-50 rounded-lg">
                    <p className="font-medium mb-1">Notes:</p>
                    <p>{quote.notes}</p>
                  </div>
                )}

                <div className="flex items-center gap-2 text-xs text-gray-500 mb-4">
                  <Clock className="w-3 h-3" />
                  <span>
                    {quote.status === 'pending'
                      ? `Expires: ${new Date(quote.expires_at).toLocaleDateString()}`
                      : `Created: ${new Date(quote.created_at).toLocaleDateString()}`}
                  </span>
                </div>

                {profile?.user_type === 'client' && quote.status === 'pending' && (
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleRejectQuote(quote.id)}
                      disabled={processing}
                      className="flex-1 px-4 py-2 border border-red-300 text-red-700 rounded-lg font-medium hover:bg-red-50 transition-colors disabled:opacity-50"
                    >
                      Reject
                    </button>
                    <button
                      onClick={() => handleAcceptQuote(quote.id)}
                      disabled={processing}
                      className="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg font-medium hover:bg-orange-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                    >
                      <CheckCircle className="w-4 h-4" />
                      Accept
                    </button>
                  </div>
                )}

                {quote.status === 'accepted' && (
                  <div className="bg-green-50 border border-green-200 rounded-lg p-3 text-sm text-green-800">
                    <CheckCircle className="w-4 h-4 inline mr-1" />
                    Quote accepted on {new Date(quote.accepted_at!).toLocaleDateString()}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
