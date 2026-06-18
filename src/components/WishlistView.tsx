import { useState, useEffect } from 'react';
import { Heart, MapPin, Star, Trash2, ShoppingCart, MessageCircle } from 'lucide-react';
import { getWishlist, removeFromWishlist, updateWishlistNotes } from '../lib/wishlist';
import { useAuth } from '../contexts/AuthContext';

type WishlistViewProps = {
  onViewChange: (view: string, listingId?: string) => void;
};

export function WishlistView({ onViewChange }: WishlistViewProps) {
  const { user } = useAuth();
  const [wishlistItems, setWishlistItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingNotes, setEditingNotes] = useState<string | null>(null);
  const [notesText, setNotesText] = useState('');

  useEffect(() => {
    loadWishlist();
  }, []);

  async function loadWishlist() {
    if (!user) return;

    try {
      const items = await getWishlist();
      setWishlistItems(items);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  }

  async function handleRemove(listingId: string) {
    if (!confirm('Remove this item from your wishlist?')) return;

    try {
      await removeFromWishlist(listingId);
      setWishlistItems(prev => prev.filter(item => item.listing_id !== listingId));
    } catch (error) {

      alert('Failed to remove item');
    }
  }

  async function handleSaveNotes(listingId: string) {
    try {
      await updateWishlistNotes(listingId, notesText);
      setWishlistItems(prev => prev.map(item =>
        item.listing_id === listingId ? { ...item, notes: notesText } : item
      ));
      setEditingNotes(null);
    } catch (error) {

      alert('Failed to update notes');
    }
  }

  function startEditingNotes(listingId: string, currentNotes: string) {
    setEditingNotes(listingId);
    setNotesText(currentNotes || '');
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-r from-red-500 to-pink-600 text-white py-12">
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex items-center gap-4 mb-4">
            <Heart className="w-12 h-12 fill-current" />
            <h1 className="text-4xl font-bold">My Wishlist</h1>
          </div>
          <p className="text-red-100 text-lg">
            {wishlistItems.length} {wishlistItems.length === 1 ? 'item' : 'items'} saved
          </p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-8">
        {wishlistItems.length === 0 ? (
          <div className="text-center py-20">
            <Heart className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-700 mb-2">Your wishlist is empty</h3>
            <p className="text-gray-500 mb-6">Start exploring and save your favorite souvenirs</p>
            <button
              onClick={() => onViewChange('discover')}
              className="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition"
            >
              Discover Souvenirs
            </button>
          </div>
        ) : (
          <div className="grid gap-6">
            {wishlistItems.map((item) => {
              const listing = item.listing;
              if (!listing) return null;

              return (
                <div
                  key={item.id}
                  className="bg-white rounded-lg shadow-md hover:shadow-lg transition-all duration-300"
                >
                  <div className="flex gap-6 p-6">
                    <img
                      src={listing.image_url || listing.images?.[0] || 'https://via.placeholder.com/200'}
                      alt={listing.title}
                      className="w-48 h-48 object-cover rounded-lg cursor-pointer hover:opacity-90 transition"
                      onClick={() => onViewChange('listing-detail', listing.id)}
                    />

                    <div className="flex-1">
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3
                            onClick={() => onViewChange('listing-detail', listing.id)}
                            className="text-2xl font-bold text-gray-900 mb-2 hover:text-blue-600 cursor-pointer transition"
                          >
                            {listing.title}
                          </h3>
                          <div className="flex items-center gap-2 text-gray-600 mb-2">
                            <MapPin className="w-4 h-4" />
                            <span>{listing.region}</span>
                            <span className="text-gray-400">•</span>
                            <span className="text-sm bg-gray-100 px-2 py-1 rounded">{listing.category}</span>
                          </div>
                        </div>
                        <button
                          onClick={() => handleRemove(listing.id)}
                          className="text-red-500 hover:text-red-700 p-2 hover:bg-red-50 rounded-lg transition"
                        >
                          <Trash2 className="w-5 h-5" />
                        </button>
                      </div>

                      <p className="text-gray-600 mb-4 line-clamp-2">
                        {listing.description}
                      </p>

                      {listing.picker && (
                        <div className="flex items-center gap-3 mb-4 p-3 bg-gray-50 rounded-lg">
                          <img
                            src={listing.picker.avatar_url || `https://ui-avatars.com/api/?name=${listing.picker.full_name}`}
                            alt={listing.picker.full_name}
                            className="w-10 h-10 rounded-full"
                          />
                          <div>
                            <div className="font-semibold text-gray-900">{listing.picker.full_name}</div>
                            {listing.picker.trust_score && (
                              <div className="flex items-center gap-1 text-sm text-yellow-600">
                                <Star className="w-4 h-4 fill-current" />
                                <span>{listing.picker.trust_score.toFixed(1)} rating</span>
                              </div>
                            )}
                          </div>
                        </div>
                      )}

                      <div className="mb-4">
                        {editingNotes === listing.id ? (
                          <div>
                            <label className="block text-sm font-semibold text-gray-700 mb-2">
                              Personal Notes
                            </label>
                            <textarea
                              value={notesText}
                              onChange={(e) => setNotesText(e.target.value)}
                              className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-400 outline-none"
                              rows={3}
                              placeholder="Add notes about this item..."
                            />
                            <div className="flex gap-2 mt-2">
                              <button
                                onClick={() => handleSaveNotes(listing.id)}
                                className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-blue-700 transition"
                              >
                                Save Notes
                              </button>
                              <button
                                onClick={() => setEditingNotes(null)}
                                className="bg-gray-200 text-gray-700 px-4 py-2 rounded-lg text-sm font-semibold hover:bg-gray-300 transition"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        ) : (
                          <div>
                            {item.notes ? (
                              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                                <div className="flex items-start justify-between">
                                  <div>
                                    <div className="text-xs font-semibold text-yellow-800 mb-1">YOUR NOTES</div>
                                    <p className="text-sm text-gray-700">{item.notes}</p>
                                  </div>
                                  <button
                                    onClick={() => startEditingNotes(listing.id, item.notes)}
                                    className="text-yellow-700 hover:text-yellow-900 text-xs font-semibold"
                                  >
                                    Edit
                                  </button>
                                </div>
                              </div>
                            ) : (
                              <button
                                onClick={() => startEditingNotes(listing.id, '')}
                                className="text-sm text-gray-500 hover:text-gray-700 underline"
                              >
                                Add notes
                              </button>
                            )}
                          </div>
                        )}
                      </div>

                      <div className="flex items-center justify-between pt-4 border-t">
                        <div className="text-3xl font-bold text-blue-600">
                          ${listing.price}
                        </div>

                        <div className="flex gap-3">
                          <button
                            onClick={() => onViewChange('messages')}
                            className="flex items-center gap-2 bg-gray-100 text-gray-700 px-4 py-2 rounded-lg font-semibold hover:bg-gray-200 transition"
                          >
                            <MessageCircle className="w-5 h-5" />
                            Contact Picker
                          </button>
                          <button
                            onClick={() => onViewChange('listing-detail', listing.id)}
                            className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-700 transition"
                          >
                            <ShoppingCart className="w-5 h-5" />
                            View Details
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
