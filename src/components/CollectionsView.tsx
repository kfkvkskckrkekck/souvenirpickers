import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Heart, Plus, Trash2, Eye, EyeOff, Loader, Package, Star, Sparkles } from 'lucide-react';

interface Collection {
  id: string;
  name: string;
  description: string;
  is_public: boolean;
  created_at: string;
  updated_at: string;
  items?: CollectionItem[];
}

interface CollectionItem {
  id: string;
  listing_id?: string;
  desire_id?: string;
  notes: string;
  added_at: string;
  listing?: {
    title: string;
    price: number;
    image_url: string;
    location: string;
  };
  desire?: {
    title: string;
    description: string;
  };
}

export default function CollectionsView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [collections, setCollections] = useState<Collection[]>([]);
  const [selectedCollection, setSelectedCollection] = useState<Collection | null>(null);
  const [showNewCollectionModal, setShowNewCollectionModal] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState('');
  const [newCollectionDescription, setNewCollectionDescription] = useState('');
  const [newCollectionPublic, setNewCollectionPublic] = useState(false);

  useEffect(() => {
    if (user) {
      loadCollections();
    }
  }, [user]);

  const loadCollections = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('collections')
        .select('*')
        .eq('user_id', user?.id)
        .order('updated_at', { ascending: false });

      if (error) throw error;
      setCollections(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const loadCollectionItems = async (collectionId: string) => {
    try {
      const { data, error } = await supabase
        .from('collection_items')
        .select(`
          *,
          listing:listings(title, price, image_url, location),
          desire:client_desires(title, description)
        `)
        .eq('collection_id', collectionId)
        .order('added_at', { ascending: false });

      if (error) throw error;

      const collection = collections.find(c => c.id === collectionId);
      if (collection) {
        setSelectedCollection({ ...collection, items: data || [] });
      }
    } catch (error) {

    }
  };

  const createCollection = async () => {
    if (!newCollectionName.trim()) {
      alert('Please enter a collection name');
      return;
    }

    try {
      const { data, error } = await supabase
        .from('collections')
        .insert({
          user_id: user?.id,
          name: newCollectionName,
          description: newCollectionDescription,
          is_public: newCollectionPublic
        })
        .select()
        .single();

      if (error) throw error;

      setCollections([data, ...collections]);
      setShowNewCollectionModal(false);
      setNewCollectionName('');
      setNewCollectionDescription('');
      setNewCollectionPublic(false);
    } catch (error) {

    }
  };

  const deleteCollection = async (collectionId: string) => {
    if (!confirm('Are you sure you want to delete this collection?')) return;

    try {
      const { error } = await supabase
        .from('collections')
        .delete()
        .eq('id', collectionId);

      if (error) throw error;

      setCollections(collections.filter(c => c.id !== collectionId));
      if (selectedCollection?.id === collectionId) {
        setSelectedCollection(null);
      }
    } catch (error) {

    }
  };

  const togglePublic = async (collectionId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('collections')
        .update({ is_public: !currentStatus })
        .eq('id', collectionId);

      if (error) throw error;

      setCollections(collections.map(c =>
        c.id === collectionId ? { ...c, is_public: !currentStatus } : c
      ));

      if (selectedCollection?.id === collectionId) {
        setSelectedCollection({ ...selectedCollection, is_public: !currentStatus });
      }
    } catch (error) {

    }
  };

  const removeItem = async (itemId: string) => {
    if (!selectedCollection) return;

    try {
      const { error } = await supabase
        .from('collection_items')
        .delete()
        .eq('id', itemId);

      if (error) throw error;

      setSelectedCollection({
        ...selectedCollection,
        items: selectedCollection.items?.filter(item => item.id !== itemId)
      });
    } catch (error) {

    }
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center py-12">
          <Loader className="w-8 h-8 animate-spin text-green-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
            <Heart className="w-8 h-8 text-red-600" />
            My Collections
          </h1>
          <p className="text-gray-600">Organize your favorite listings and desires into curated collections</p>
        </div>
        <button
          onClick={() => setShowNewCollectionModal(true)}
          className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium flex items-center gap-2"
        >
          <Plus className="w-5 h-5" />
          New Collection
        </button>
      </div>

      <div className="mb-8 bg-gradient-to-r from-pink-50 to-purple-50 rounded-xl p-6 border-2 border-pink-200">
        <div className="flex items-start gap-4">
          <div className="bg-pink-600 p-3 rounded-lg flex-shrink-0">
            <Sparkles className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">Organize Your Souvenir Journey</h3>
            <p className="text-gray-700 mb-3">
              Collections help you keep track of souvenirs you love and want to remember. Think of them as personalized wishlists!
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="bg-white rounded-lg p-3 border border-pink-200">
                <p className="text-sm text-gray-700"><strong>Save Listings:</strong> Bookmark items you're interested in</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-purple-200">
                <p className="text-sm text-gray-700"><strong>Track Desires:</strong> Keep your wish list organized</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-pink-200">
                <p className="text-sm text-gray-700"><strong>Share Collections:</strong> Make them public to inspire others</p>
              </div>
              <div className="bg-white rounded-lg p-3 border border-purple-200">
                <p className="text-sm text-gray-700"><strong>Add Notes:</strong> Remember why each item is special</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {showNewCollectionModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 max-w-md w-full">
            <h3 className="text-xl font-bold text-gray-900 mb-4">Create New Collection</h3>

            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">Collection Name *</label>
              <input
                type="text"
                value={newCollectionName}
                onChange={(e) => setNewCollectionName(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                placeholder="e.g., European Souvenirs, Dream Destinations"
              />
            </div>

            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">Description (Optional)</label>
              <textarea
                value={newCollectionDescription}
                onChange={(e) => setNewCollectionDescription(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                rows={3}
                placeholder="Describe what this collection is about..."
              />
            </div>

            <div className="mb-6">
              <label className="flex items-start gap-3">
                <input
                  type="checkbox"
                  checked={newCollectionPublic}
                  onChange={(e) => setNewCollectionPublic(e.target.checked)}
                  className="w-4 h-4 text-green-600 rounded focus:ring-green-500 mt-1"
                />
                <div>
                  <span className="text-sm font-medium text-gray-700">Make this collection public</span>
                  <p className="text-xs text-gray-500 mt-1">Others can view and get inspired by your collection</p>
                </div>
              </label>
            </div>

            <div className="flex gap-3">
              <button
                onClick={createCollection}
                className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium"
              >
                Create Collection
              </button>
              <button
                onClick={() => {
                  setShowNewCollectionModal(false);
                  setNewCollectionName('');
                  setNewCollectionDescription('');
                  setNewCollectionPublic(false);
                }}
                className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {collections.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12">
          <div className="max-w-2xl mx-auto text-center">
            <Heart className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-3">Start Your First Collection</h3>

            <div className="text-left bg-gray-50 rounded-lg p-6 mb-6">
              <h4 className="font-semibold text-gray-900 mb-3">Collection Ideas to Get Started:</h4>
              <ul className="space-y-3 text-gray-700">
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-pink-500 text-white rounded-full flex items-center justify-center text-xs">✈</div>
                  <span><strong>Dream Destinations:</strong> Save listings from places you want to visit</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-purple-500 text-white rounded-full flex items-center justify-center text-xs">🎁</div>
                  <span><strong>Gift Ideas:</strong> Organize potential gifts for friends and family</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center text-xs">🏛</div>
                  <span><strong>Cultural Treasures:</strong> Collect unique cultural items from around the world</span>
                </li>
                <li className="flex gap-3">
                  <div className="flex-shrink-0 w-6 h-6 bg-green-500 text-white rounded-full flex items-center justify-center text-xs">💎</div>
                  <span><strong>Premium Items:</strong> Track high-value or rare souvenirs</span>
                </li>
              </ul>

              <div className="mt-4 p-4 bg-pink-50 border border-pink-200 rounded-lg">
                <p className="text-sm text-pink-800">
                  <strong>Pro Tip:</strong> When browsing listings or creating desires, look for the heart icon to quickly add items to your collections!
                </p>
              </div>
            </div>

            <button
              onClick={() => setShowNewCollectionModal(true)}
              className="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium inline-flex items-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Create Your First Collection
            </button>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-1 space-y-4">
            {collections.map(collection => (
              <div
                key={collection.id}
                className={`bg-white rounded-xl shadow-sm border-2 ${
                  selectedCollection?.id === collection.id ? 'border-green-500' : 'border-gray-200'
                } p-4 cursor-pointer hover:border-green-300 transition-colors`}
                onClick={() => loadCollectionItems(collection.id)}
              >
                <div className="flex items-start justify-between mb-2">
                  <h3 className="font-bold text-gray-900">{collection.name}</h3>
                  <div className="flex items-center gap-2">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        togglePublic(collection.id, collection.is_public);
                      }}
                      className="text-gray-400 hover:text-gray-600"
                      title={collection.is_public ? 'Public' : 'Private'}
                    >
                      {collection.is_public ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteCollection(collection.id);
                      }}
                      className="text-gray-400 hover:text-red-600"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
                {collection.description && (
                  <p className="text-sm text-gray-600 mb-2 line-clamp-2">{collection.description}</p>
                )}
                <div className="flex items-center gap-2 text-xs text-gray-500">
                  <span>{collection.is_public ? 'Public' : 'Private'}</span>
                  <span>•</span>
                  <span>Updated {new Date(collection.updated_at).toLocaleDateString()}</span>
                </div>
              </div>
            ))}
          </div>

          <div className="lg:col-span-2">
            {selectedCollection ? (
              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
                <div className="mb-6">
                  <h2 className="text-2xl font-bold text-gray-900 mb-2">{selectedCollection.name}</h2>
                  {selectedCollection.description && (
                    <p className="text-gray-600">{selectedCollection.description}</p>
                  )}
                </div>

                {!selectedCollection.items || selectedCollection.items.length === 0 ? (
                  <div className="text-center py-12">
                    <Package className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                    <p className="text-gray-600 mb-2">No items in this collection yet</p>
                    <p className="text-sm text-gray-500">
                      Browse listings or desires and click the heart icon to add them here!
                    </p>
                  </div>
                ) : (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {selectedCollection.items.map(item => (
                      <div key={item.id} className="border border-gray-200 rounded-lg p-4 hover:border-green-300 transition-colors">
                        {item.listing ? (
                          <>
                            {item.listing.image_url && (
                              <img
                                src={item.listing.image_url}
                                alt={item.listing.title}
                                className="w-full h-32 object-cover rounded-lg mb-3"
                              />
                            )}
                            <h4 className="font-semibold text-gray-900 mb-1">{item.listing.title}</h4>
                            <p className="text-sm text-gray-600 mb-2">{item.listing.location}</p>
                            <p className="text-lg font-bold text-green-600 mb-3">${item.listing.price}</p>
                          </>
                        ) : (
                          <>
                            <div className="bg-blue-50 rounded-lg p-3 mb-3">
                              <Star className="w-5 h-5 text-blue-600 mb-2" />
                              <h4 className="font-semibold text-gray-900 mb-1">{item.desire?.title}</h4>
                              <p className="text-xs text-gray-600 line-clamp-2">{item.desire?.description}</p>
                            </div>
                          </>
                        )}
                        {item.notes && (
                          <p className="text-sm text-gray-600 italic mb-3 bg-yellow-50 p-2 rounded">{item.notes}</p>
                        )}
                        <button
                          onClick={() => removeItem(item.id)}
                          className="w-full px-3 py-2 text-sm border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors flex items-center justify-center gap-2"
                        >
                          <Trash2 className="w-4 h-4" />
                          Remove from Collection
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12 text-center">
                <Heart className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-600">Select a collection from the left to view its items</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
