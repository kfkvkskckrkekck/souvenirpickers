import { useState, useEffect } from 'react';
import { Plus, X, MapPin, DollarSign, Tag, AlertCircle, Heart, MessageCircle, Upload, CreditCard as Edit2, Trash2 } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { supabase, ClientDesire, Profile } from '../lib/supabase';
import { LocationPicker } from './LocationPicker';
import { uploadVideo } from '../lib/storage';
import { ConfirmDialog } from './ConfirmDialog';

type DesireWithClient = ClientDesire & {
  client?: Profile;
};

type DesiresViewProps = {
  onViewChange?: (view: string, id?: string) => void;
};

export function DesiresView({ onViewChange }: DesiresViewProps = {}) {
  const { profile, user } = useAuth();
  const toast = useToast();
  const [desires, setDesires] = useState<DesireWithClient[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingDesire, setEditingDesire] = useState<DesireWithClient | null>(null);
  const [deletingDesireId, setDeletingDesireId] = useState<string | null>(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [preferredRegions, setPreferredRegions] = useState<string[]>([]);
  const [preferredLocations, setPreferredLocations] = useState<string[]>([]);
  const [newRegion, setNewRegion] = useState('');
  const [newLocation, setNewLocation] = useState('');
  const [latitude, setLatitude] = useState<number | undefined>();
  const [longitude, setLongitude] = useState<number | undefined>();
  const [budgetMin, setBudgetMin] = useState('');
  const [budgetMax, setBudgetMax] = useState('');
  const [urgency, setUrgency] = useState<'low' | 'medium' | 'high'>('medium');
  const [referenceLinks, setReferenceLinks] = useState<string[]>([]);
  const [newReferenceLink, setNewReferenceLink] = useState('');
  const [error, setError] = useState('');
  const [respondingDesire, setRespondingDesire] = useState<DesireWithClient | null>(null);
  const [responseMessage, setResponseMessage] = useState('');
  const [uploadingVideo, setUploadingVideo] = useState(false);

  useEffect(() => {
    if (profile) {
      setLoading(true);
      loadDesires();
    }
  }, [profile?.user_type, profile?.id]);

  const loadDesires = async () => {
    try {
      if (profile?.user_type === 'client') {
        const { data, error } = await supabase
          .from('client_desires')
          .select('*')
          .eq('client_id', user?.id)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setDesires(data || []);
      } else if (profile?.user_type === 'picker') {
        const { data, error } = await supabase
          .from('client_desires')
          .select(`
            *,
            client:profiles!client_desires_client_id_fkey(*)
          `)
          .eq('active', true)
          .order('created_at', { ascending: false });

        if (error) throw error;
        setDesires(data || []);
      }
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const addRegion = () => {
    if (newRegion.trim() && !preferredRegions.includes(newRegion.trim())) {
      setPreferredRegions([...preferredRegions, newRegion.trim()]);
      setNewRegion('');
    }
  };

  const removeRegion = (region: string) => {
    setPreferredRegions(preferredRegions.filter(r => r !== region));
  };

  const addLocation = () => {
    if (newLocation.trim() && !preferredLocations.includes(newLocation.trim())) {
      setPreferredLocations([...preferredLocations, newLocation.trim()]);
      setNewLocation('');
    }
  };

  const removeLocation = (location: string) => {
    setPreferredLocations(preferredLocations.filter(l => l !== location));
  };

  const addReferenceLink = () => {
    const trimmedLink = newReferenceLink.trim();
    if (trimmedLink && !referenceLinks.includes(trimmedLink)) {
      setReferenceLinks([...referenceLinks, trimmedLink]);
      setNewReferenceLink('');
    }
  };

  const removeReferenceLink = (link: string) => {
    setReferenceLinks(referenceLinks.filter(l => l !== link));
  };

  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploadingVideo(true);
    setError('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadVideo(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setReferenceLinks([...referenceLinks, ...urls]);
      setError('');
    } catch (error: any) {
      setError('Error uploading videos: ' + error.message);
    } finally {
      setUploadingVideo(false);
      // Reset the input
      if (e.target) {
        e.target.value = '';
      }
    }
  };

  const startEditDesire = (desire: DesireWithClient) => {
    setEditingDesire(desire);
    setTitle(desire.title);
    setDescription(desire.description);
    setCategory(desire.category || '');
    setPreferredRegions(desire.preferred_regions || []);
    setPreferredLocations(desire.preferred_locations || []);
    setLatitude(desire.latitude || undefined);
    setLongitude(desire.longitude || undefined);
    setBudgetMin(desire.budget_min?.toString() || '');
    setBudgetMax(desire.budget_max?.toString() || '');
    setUrgency(desire.urgency);
    setReferenceLinks(desire.reference_links || []);
    setShowEditModal(true);
  };

  const cancelEdit = () => {
    setEditingDesire(null);
    setTitle('');
    setDescription('');
    setCategory('');
    setPreferredRegions([]);
    setPreferredLocations([]);
    setReferenceLinks([]);
    setNewReferenceLink('');
    setLatitude(undefined);
    setLongitude(undefined);
    setBudgetMin('');
    setBudgetMax('');
    setUrgency('medium');
    setError('');
    setShowCreateForm(false);
    setShowEditModal(false);
  };

  const handleCreateDesire = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (preferredRegions.length === 0 && preferredLocations.length === 0) {
      setError('Please add at least one preferred region or location');
      return;
    }

    try {
      const desireData = {
        client_id: user?.id,
        title,
        description,
        category: category || '',
        preferred_regions: preferredRegions,
        preferred_locations: preferredLocations,
        latitude: latitude || null,
        longitude: longitude || null,
        budget_min: budgetMin ? parseFloat(budgetMin) : null,
        budget_max: budgetMax ? parseFloat(budgetMax) : null,
        urgency,
        reference_links: referenceLinks,
      };

      if (editingDesire) {
        // Update existing desire
        const { error } = await supabase
          .from('client_desires')
          .update(desireData)
          .eq('id', editingDesire.id);

        if (error) throw error;
        toast.success('Desire updated successfully!');
      } else {
        // Create new desire
        const { error } = await supabase.from('client_desires').insert(desireData);
        if (error) throw error;
        toast.success('Desire created successfully!');
      }

      cancelEdit();
      loadDesires();
    } catch (error) {
      const errorMsg = `Failed to ${editingDesire ? 'update' : 'create'} desire. Please try again.`;
      setError(errorMsg);
      toast.error(errorMsg);
    }
  };

  const toggleDesireActive = async (desireId: string, currentActive: boolean) => {
    try {
      const { error } = await supabase
        .from('client_desires')
        .update({ active: !currentActive })
        .eq('id', desireId);

      if (error) throw error;
      toast.success(currentActive ? 'Desire marked as inactive' : 'Desire reactivated');
      loadDesires();
    } catch (error: any) {
      toast.error('Failed to update desire: ' + error.message);
    }
  };

  const deleteDesire = async (desireId: string) => {
    try {
      const { error } = await supabase
        .from('client_desires')
        .delete()
        .eq('id', desireId);

      if (error) throw error;
      toast.success('Desire deleted successfully!');
      loadDesires();
    } catch (error: any) {
      toast.error('Failed to delete desire: ' + error.message);
    } finally {
      setDeletingDesireId(null);
    }
  };

  const handleRespondToDesire = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!respondingDesire || !user?.id || !respondingDesire.client_id) return;

    try {
      let conversationId: string | null = null;

      const { data: existingConversation } = await supabase
        .from('conversations')
        .select('id')
        .eq('picker_id', user.id)
        .eq('client_id', respondingDesire.client_id)
        .maybeSingle();

      if (existingConversation) {
        conversationId = existingConversation.id;
      } else {
        const { data: newConversation, error: convError } = await supabase
          .from('conversations')
          .insert({
            picker_id: user.id,
            client_id: respondingDesire.client_id,
          })
          .select('id')
          .single();

        if (convError) throw convError;
        conversationId = newConversation.id;
      }

      const messageContent = `Re: ${respondingDesire.title}\n\n${responseMessage}`;

      const { error: msgError } = await supabase
        .from('conversation_messages')
        .insert({
          conversation_id: conversationId,
          sender_id: user.id,
          content: messageContent,
        });

      if (msgError) throw msgError;

      const { data: currentConv } = await supabase
        .from('conversations')
        .select('client_unread_count')
        .eq('id', conversationId)
        .single();

      await supabase
        .from('conversations')
        .update({
          last_message: messageContent.substring(0, 100),
          last_message_at: new Date().toISOString(),
          client_unread_count: (currentConv?.client_unread_count || 0) + 1,
        })
        .eq('id', conversationId);

      await supabase.from('notifications').insert({
        user_id: respondingDesire.client_id,
        type: 'new_message',
        title: 'New Message',
        message: `A picker responded to your desire: ${respondingDesire.title}`,
        link: '/messages',
      });

      setResponseMessage('');
      setRespondingDesire(null);
    } catch (error) {

    }
  };

  const urgencyColors = {
    low: 'bg-gray-100 text-gray-700',
    medium: 'bg-yellow-100 text-yellow-700',
    high: 'bg-red-100 text-red-700',
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Loading desires...</div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            {profile?.user_type === 'client' ? 'My Souvenir Desires' : 'Client Desires'}
          </h1>
          <p className="text-gray-600 mt-1">
            {profile?.user_type === 'client'
              ? 'Tell pickers what you\'re looking for'
              : 'Browse what clients are looking for'}
          </p>
        </div>
        {profile?.user_type === 'client' && (
          <button
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-8 py-4 rounded-xl font-bold hover:from-blue-700 hover:to-blue-800 transition-all transform hover:scale-105 flex items-center gap-3 whitespace-nowrap shadow-xl text-lg"
          >
            <Plus className="w-6 h-6" />
            Add New Desire
          </button>
        )}
      </div>

      {showCreateForm && profile?.user_type === 'client' && (
        <div className="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            {editingDesire ? 'Edit Desire' : 'Create New Desire'}
          </h2>
          <form onSubmit={handleCreateDesire} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                What are you looking for?
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Vintage Japanese Tea Set"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Detailed Description
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Describe exactly what you want, including style, materials, size, etc."
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Tag className="w-4 h-4 inline mr-1" />
                Category (optional)
              </label>
              <input
                type="text"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Traditional Crafts, Fashion, Food"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Preferred Regions/Countries
              </label>
              <div className="flex gap-2 mb-3">
                <input
                  type="text"
                  value={newRegion}
                  onChange={(e) => setNewRegion(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addRegion())}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Japan, Southeast Asia"
                />
                <button
                  type="button"
                  onClick={addRegion}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  <Plus className="w-5 h-5" />
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {preferredRegions.map((region) => (
                  <span
                    key={region}
                    className="inline-flex items-center gap-1 bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-sm"
                  >
                    {region}
                    <button
                      type="button"
                      onClick={() => removeRegion(region)}
                      className="hover:text-blue-900"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </span>
                ))}
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Specific Locations (optional)
              </label>
              <div className="flex gap-2 mb-3">
                <input
                  type="text"
                  value={newLocation}
                  onChange={(e) => setNewLocation(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addLocation())}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Tokyo, Kyoto, Bali"
                />
                <button
                  type="button"
                  onClick={addLocation}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  <Plus className="w-5 h-5" />
                </button>
              </div>
              <div className="flex flex-wrap gap-2">
                {preferredLocations.map((location) => (
                  <span
                    key={location}
                    className="inline-flex items-center gap-1 bg-green-100 text-green-700 px-3 py-1 rounded-full text-sm"
                  >
                    {location}
                    <button
                      type="button"
                      onClick={() => removeLocation(location)}
                      className="hover:text-green-900"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </span>
                ))}
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
              <p className="text-sm text-blue-800">
                <strong>Note:</strong> You don't need GPS coordinates! Adding countries, cities, or regions above is enough for matching with pickers. GPS location is only needed if you want to specify an exact place.
              </p>
            </div>

            <LocationPicker
              latitude={latitude}
              longitude={longitude}
              onLocationChange={(lat, lng) => {
                setLatitude(lat);
                setLongitude(lng);
              }}
              label="GPS Coordinates (optional - only for exact locations)"
            />

            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Min Budget (USD)
                </label>
                <div className="relative">
                  <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="number"
                    value={budgetMin}
                    onChange={(e) => setBudgetMin(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="0.00"
                    min="0"
                    step="0.01"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Max Budget (USD)
                </label>
                <div className="relative">
                  <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="number"
                    value={budgetMax}
                    onChange={(e) => setBudgetMax(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="0.00"
                    min="0"
                    step="0.01"
                  />
                </div>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Reference Videos & Links (optional)
              </label>
              <p className="text-sm text-gray-600 mb-3">
                Upload videos or add TikTok links showing examples of what you want
              </p>

              {/* Video Upload Section */}
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 mb-3 hover:border-blue-400 transition-colors">
                <input
                  type="file"
                  accept="video/mp4,video/webm,video/quicktime"
                  multiple
                  onChange={handleVideoUpload}
                  className="hidden"
                  id="desire-video-upload"
                  disabled={uploadingVideo}
                />
                <label
                  htmlFor="desire-video-upload"
                  className="flex flex-col items-center justify-center cursor-pointer"
                >
                  <Upload className="w-8 h-8 text-gray-400 mb-2" />
                  <p className="text-sm text-gray-600 text-center">
                    {uploadingVideo ? 'Uploading videos...' : 'Click to upload videos (MP4, WebM, MOV)'}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">Max 50MB per video</p>
                </label>
              </div>

              {/* Link Input Section */}
              <div className="flex gap-2 mb-3">
                <input
                  type="url"
                  value={newReferenceLink}
                  onChange={(e) => setNewReferenceLink(e.target.value)}
                  placeholder="Or paste a TikTok/video link..."
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <button
                  type="button"
                  onClick={addReferenceLink}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  <Plus className="w-5 h-5" />
                </button>
              </div>

              {/* Display uploaded videos and links */}
              {referenceLinks.length > 0 && (
                <div className="grid grid-cols-2 gap-3 mt-3">
                  {referenceLinks.map((link, index) => (
                    <div key={index} className="relative group">
                      {link.includes('supabase') ? (
                        // Display uploaded video
                        <div className="relative aspect-video bg-gray-100 rounded-lg overflow-hidden">
                          <video
                            src={link}
                            className="w-full h-full object-cover"
                            controls
                            preload="metadata"
                            playsInline
                            onError={(e) => {
                              console.error('Video load error:', e);
                              console.log('Failed video URL:', link);
                            }}
                          />
                          <button
                            type="button"
                            onClick={() => removeReferenceLink(link)}
                            className="absolute top-2 right-2 bg-red-500 text-white p-1 rounded-full hover:bg-red-600 transition-colors"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      ) : (
                        // Display link
                        <span className="inline-flex items-center gap-2 px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm">
                          <a href={link} target="_blank" rel="noopener noreferrer" className="hover:underline max-w-xs truncate">
                            {link}
                          </a>
                          <button
                            type="button"
                            onClick={() => removeReferenceLink(link)}
                            className="hover:text-blue-900"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Urgency</label>
              <select
                value={urgency}
                onChange={(e) => setUrgency(e.target.value as 'low' | 'medium' | 'high')}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="low">Low - No rush</option>
                <option value="medium">Medium - Within a few weeks</option>
                <option value="high">High - ASAP</option>
              </select>
            </div>

            {error && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm flex items-center gap-2">
                <AlertCircle className="w-4 h-4" />
                {error}
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="submit"
                className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
              >
                {editingDesire ? 'Update Desire' : 'Create Desire'}
              </button>
              <button
                type="button"
                onClick={cancelEdit}
                className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {desires.length === 0 ? (
        <div className="bg-white rounded-2xl shadow-lg p-12 text-center">
          <Heart className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-2">
            {profile?.user_type === 'client' ? 'No desires yet' : 'No active desires'}
          </h3>
          <p className="text-gray-600">
            {profile?.user_type === 'client'
              ? 'Create your first desire to let pickers know what you\'re looking for'
              : 'No clients are currently looking for souvenirs'}
          </p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 lg:grid-cols-2 gap-6">
          {desires.map((desire) => (
            <div
              key={desire.id}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow"
            >
              <div className="p-6">
                <div className="flex items-start justify-between mb-3">
                  <h3 className="text-xl font-bold text-gray-900 flex-1">{desire.title}</h3>
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${urgencyColors[desire.urgency]}`}>
                    {desire.urgency}
                  </span>
                </div>

                <p className="text-gray-600 mb-4 line-clamp-3">{desire.description}</p>

                {desire.category && (
                  <div className="flex items-center gap-1 text-sm text-gray-600 mb-3">
                    <Tag className="w-4 h-4" />
                    <span>{desire.category}</span>
                  </div>
                )}

                {(desire.preferred_regions.length > 0 || desire.preferred_locations.length > 0) && (
                  <div className="mb-4">
                    <div className="text-sm font-medium text-gray-700 mb-2 flex items-center gap-1">
                      <MapPin className="w-4 h-4" />
                      Preferred Locations:
                    </div>
                    <div className="flex flex-wrap gap-1">
                      {desire.preferred_regions.map((region) => (
                        <span
                          key={region}
                          className="bg-blue-50 text-blue-700 px-2 py-1 rounded text-xs"
                        >
                          {region}
                        </span>
                      ))}
                      {desire.preferred_locations.map((location) => (
                        <span
                          key={location}
                          className="bg-green-50 text-green-700 px-2 py-1 rounded text-xs"
                        >
                          {location}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {(desire.budget_min || desire.budget_max) && (
                  <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                    <div className="text-sm font-medium text-gray-700 mb-1">Budget Range:</div>
                    <div className="text-gray-900 font-semibold">
                      ${desire.budget_min?.toFixed(2) || '0.00'} - $
                      {desire.budget_max?.toFixed(2) || '∞'}
                    </div>
                  </div>
                )}

                {profile?.user_type === 'picker' && desire.client && (
                  <div className="mb-4 pb-4 border-t border-gray-200 pt-4">
                    <p className="text-sm text-gray-600">
                      Requested by <span className="font-medium">{desire.client.full_name}</span>
                    </p>
                  </div>
                )}

                {profile?.user_type === 'client' && (
                  <div className="flex flex-col gap-2 mt-4">
                    <div className="flex gap-2">
                      <button
                        onClick={() => startEditDesire(desire)}
                        className="flex-1 bg-blue-50 text-blue-600 py-2 rounded-lg font-medium hover:bg-blue-100 transition-colors flex items-center justify-center gap-2"
                      >
                        <Edit2 className="w-4 h-4" />
                        Edit
                      </button>
                      <button
                        onClick={() => toggleDesireActive(desire.id, desire.active)}
                        className={`flex-1 py-2 rounded-lg font-medium transition-colors ${
                          desire.active
                            ? 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                            : 'bg-green-100 text-green-700 hover:bg-green-200'
                        }`}
                      >
                        {desire.active ? 'Mark Inactive' : 'Reactivate'}
                      </button>
                    </div>
                    <button
                      onClick={() => setDeletingDesireId(desire.id)}
                      className="w-full py-2 bg-red-50 text-red-600 rounded-lg font-medium hover:bg-red-100 transition-colors flex items-center justify-center gap-2"
                    >
                      <Trash2 className="w-4 h-4" />
                      Delete
                    </button>
                  </div>
                )}

                {profile?.user_type === 'picker' && (
                  <button
                    onClick={() => {
                      if (onViewChange && desire.client_id) {
                        onViewChange('messages', desire.client_id);
                      } else {
                        setRespondingDesire(desire);
                      }
                    }}
                    className="w-full mt-4 bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                  >
                    <MessageCircle className="w-4 h-4" />
                    Contact Client
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {respondingDesire && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-gray-900">Contact Client</h2>
              <button
                onClick={() => setRespondingDesire(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="mb-6 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-900 mb-1">{respondingDesire.title}</h3>
              <p className="text-sm text-gray-600 mb-2">{respondingDesire.description}</p>
              <p className="text-xs text-gray-500">
                Requested by <span className="font-medium">{respondingDesire.client?.full_name}</span>
              </p>
            </div>

            <form onSubmit={handleRespondToDesire} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Your Message
                </label>
                <textarea
                  value={responseMessage}
                  onChange={(e) => setResponseMessage(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Tell the client about what you can find for them..."
                  required
                />
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setRespondingDesire(null)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors"
                >
                  Send Message
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && editingDesire && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto animate-scale-in">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between z-10">
              <h2 className="text-2xl font-bold text-gray-900">Edit Desire</h2>
              <button
                onClick={cancelEdit}
                className="text-gray-500 hover:text-gray-700 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleCreateDesire} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  What are you looking for?
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Vintage Japanese Tea Set"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Detailed Description
                </label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Describe exactly what you want..."
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Category (optional)</label>
                <input
                  type="text"
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Traditional Crafts, Fashion, Food"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Preferred Regions/Countries
                </label>
                <div className="flex gap-2 mb-3">
                  <input
                    type="text"
                    value={newRegion}
                    onChange={(e) => setNewRegion(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addRegion())}
                    className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Japan, Southeast Asia"
                  />
                  <button
                    type="button"
                    onClick={addRegion}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    <Plus className="w-5 h-5" />
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {preferredRegions.map((region) => (
                    <span
                      key={region}
                      className="inline-flex items-center gap-1 bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-sm"
                    >
                      {region}
                      <button
                        type="button"
                        onClick={() => removeRegion(region)}
                        className="hover:text-blue-900"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Min Budget (USD)</label>
                  <input
                    type="number"
                    value={budgetMin}
                    onChange={(e) => setBudgetMin(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="0.00"
                    min="0"
                    step="0.01"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Max Budget (USD)</label>
                  <input
                    type="number"
                    value={budgetMax}
                    onChange={(e) => setBudgetMax(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="0.00"
                    min="0"
                    step="0.01"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Urgency</label>
                <select
                  value={urgency}
                  onChange={(e) => setUrgency(e.target.value as 'low' | 'medium' | 'high')}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="low">Low - No rush</option>
                  <option value="medium">Medium - Within a few weeks</option>
                  <option value="high">High - ASAP</option>
                </select>
              </div>

              {error && (
                <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                  {error}
                </div>
              )}

              <div className="flex gap-3">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
                >
                  Update Desire
                </button>
                <button
                  type="button"
                  onClick={cancelEdit}
                  className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Dialog */}
      <ConfirmDialog
        isOpen={deletingDesireId !== null}
        title="Delete Desire"
        message="Are you sure you want to delete this desire? This action cannot be undone."
        confirmText="Delete"
        cancelText="Cancel"
        variant="danger"
        onConfirm={() => {
          if (deletingDesireId) {
            deleteDesire(deletingDesireId);
          }
        }}
        onCancel={() => setDeletingDesireId(null)}
      />
    </div>
  );
}
