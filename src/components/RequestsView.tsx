import { useState, useEffect } from 'react';
import { Plus, MapPin, DollarSign, Clock, MessageCircle, Star, X } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase, Request, Profile } from '../lib/supabase';
import { ReviewForm } from './ReviewForm';
import SouvenirLoader from './SouvenirLoader';

export function RequestsView() {
  const { profile, user } = useAuth();
  const [requests, setRequests] = useState<(Request & { client?: Profile })[]>([]);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [region, setRegion] = useState('');
  const [category, setCategory] = useState('');
  const [budget, setBudget] = useState('');
  const [reviewingRequest, setReviewingRequest] = useState<Request | null>(null);
  const [respondingRequest, setRespondingRequest] = useState<Request | null>(null);
  const [responseMessage, setResponseMessage] = useState('');

  useEffect(() => {
    loadRequests();
  }, [profile]);

  const loadRequests = async () => {
    try {
      let query = supabase.from('requests').select(`
        *,
        client:profiles!requests_client_id_fkey(*)
      `);

      if (profile?.user_type === 'client') {
        query = query.eq('client_id', user?.id);
      } else {
        query = query.eq('status', 'open').is('picker_id', null);
      }

      const { data, error } = await query.order('created_at', { ascending: false });

      if (error) throw error;
      setRequests(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const handleCreateRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const { error } = await supabase.from('requests').insert({
        client_id: user?.id,
        title,
        description,
        region,
        category,
        budget: budget ? parseFloat(budget) : null,
      });

      if (error) throw error;

      setTitle('');
      setDescription('');
      setRegion('');
      setCategory('');
      setBudget('');
      setShowCreateForm(false);
      loadRequests();
    } catch (error) {

    }
  };

  const handleRespondToRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!respondingRequest || !user?.id || !profile?.id) return;

    try {
      const { data: pickerProfile, error: pickerError } = await supabase
        .from('picker_profiles')
        .select('id')
        .eq('user_id', profile.id)
        .maybeSingle();

      if (pickerError) throw pickerError;
      if (!pickerProfile) throw new Error('Picker profile not found');

      const { error: updateError } = await supabase
        .from('requests')
        .update({
          picker_id: pickerProfile.id,
          status: 'assigned',
        })
        .eq('id', respondingRequest.id);

      if (updateError) throw updateError;

      await supabase.from('messages').insert({
        sender_id: user.id,
        receiver_id: respondingRequest.client_id,
        request_id: respondingRequest.id,
        message: responseMessage,
      });

      setResponseMessage('');
      setRespondingRequest(null);
      loadRequests();
    } catch (error) {

    }
  };

  const getStatusColor = (status: string) => {
    const colors = {
      open: 'bg-green-100 text-green-700',
      assigned: 'bg-blue-100 text-blue-700',
      in_progress: 'bg-orange-100 text-orange-700',
      completed: 'bg-gray-100 text-gray-700',
      cancelled: 'bg-red-100 text-red-700',
    };
    return colors[status as keyof typeof colors] || 'bg-gray-100 text-gray-700';
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading requests..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            {profile?.user_type === 'picker' ? 'Open Requests' : 'My Requests'}
          </h1>
          <p className="text-gray-600 mt-1">
            {profile?.user_type === 'picker'
              ? 'Browse requests from clients looking for souvenirs'
              : 'Manage your souvenir requests'}
          </p>
        </div>
        {profile?.user_type === 'client' && (
          <button
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center gap-2"
          >
            <Plus className="w-5 h-5" />
            New Request
          </button>
        )}
      </div>

      {showCreateForm && (
        <div className="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">Create New Request</h2>
          <form onSubmit={handleCreateRequest} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Request Title
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Traditional Japanese Kokeshi Doll"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Description
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Describe the souvenir you're looking for in detail..."
                required
              />
            </div>

            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Region
                </label>
                <input
                  type="text"
                  value={region}
                  onChange={(e) => setRegion(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Tokyo, Japan"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Category
                </label>
                <input
                  type="text"
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Traditional crafts"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Budget (optional)
              </label>
              <div className="relative">
                <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="number"
                  value={budget}
                  onChange={(e) => setBudget(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Your budget"
                  min="0"
                  step="0.01"
                />
              </div>
            </div>

            <div className="flex gap-3">
              <button
                type="submit"
                className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
              >
                Submit Request
              </button>
              <button
                type="button"
                onClick={() => setShowCreateForm(false)}
                className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="grid gap-6">
        {requests.length === 0 ? (
          <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
            <p className="text-gray-500 text-lg">
              {profile?.user_type === 'picker'
                ? 'No open requests available at the moment'
                : 'You haven\'t created any requests yet'}
            </p>
          </div>
        ) : (
          requests.map((request) => (
            <div key={request.id} className="bg-white rounded-2xl shadow-lg p-6 hover:shadow-xl transition-shadow">
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-xl font-bold text-gray-900">{request.title}</h3>
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(request.status)}`}>
                      {request.status}
                    </span>
                  </div>
                  {profile?.user_type === 'picker' && request.client && (
                    <p className="text-sm text-gray-600 mb-2">
                      Requested by {request.client.full_name}
                    </p>
                  )}
                  <p className="text-gray-600 mb-4">{request.description}</p>
                </div>
              </div>

              <div className="flex flex-wrap gap-4 text-sm text-gray-600 mb-4">
                <div className="flex items-center gap-1">
                  <MapPin className="w-4 h-4" />
                  <span>{request.region}</span>
                </div>
                {request.budget && (
                  <div className="flex items-center gap-1">
                    <DollarSign className="w-4 h-4" />
                    <span>Budget: ${request.budget}</span>
                  </div>
                )}
                <div className="flex items-center gap-1">
                  <Clock className="w-4 h-4" />
                  <span>{new Date(request.created_at).toLocaleDateString()}</span>
                </div>
              </div>

              {request.category && (
                <div className="mb-4">
                  <span className="inline-block bg-gray-100 text-gray-700 px-3 py-1 rounded-full text-sm">
                    {request.category}
                  </span>
                </div>
              )}

              <div className="flex gap-3">
                {profile?.user_type === 'picker' && request.status === 'open' && (
                  <button
                    onClick={() => setRespondingRequest(request)}
                    className="flex-1 bg-blue-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                  >
                    <MessageCircle className="w-4 h-4" />
                    Respond to Request
                  </button>
                )}
                {profile?.user_type === 'client' && (
                  <>
                    <button className="flex-1 border border-gray-300 py-2 px-4 rounded-lg font-medium hover:bg-gray-50 transition-colors flex items-center justify-center gap-2">
                      <MessageCircle className="w-4 h-4" />
                      View Messages
                    </button>
                    {request.status === 'completed' && request.picker_id && (
                      <button
                        onClick={() => setReviewingRequest(request)}
                        className="border border-green-600 text-green-600 py-2 px-4 rounded-lg font-medium hover:bg-green-50 transition-colors flex items-center justify-center gap-2"
                      >
                        <Star className="w-4 h-4" />
                        Leave Review
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      {respondingRequest && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-gray-900">Respond to Request</h2>
              <button
                onClick={() => setRespondingRequest(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="mb-6 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-900 mb-2">{respondingRequest.title}</h3>
              <p className="text-sm text-gray-600">{respondingRequest.description}</p>
            </div>

            <form onSubmit={handleRespondToRequest} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Your Message
                </label>
                <textarea
                  value={responseMessage}
                  onChange={(e) => setResponseMessage(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Let the client know you're interested and provide details..."
                  required
                />
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setRespondingRequest(null)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors"
                >
                  Send Response
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {reviewingRequest && reviewingRequest.picker_id && user?.id && (
        <ReviewForm
          pickerId={reviewingRequest.picker_id}
          requestId={reviewingRequest.id}
          onReviewSubmitted={() => {
            setReviewingRequest(null);
            loadRequests();
          }}
          onClose={() => setReviewingRequest(null)}
        />
      )}
    </div>
  );
}
