import { useState, useEffect } from 'react';
import { Search, MapPin, DollarSign, Tag, Plus, Upload, X, Image as ImageIcon, Video, MessageCircle, ShoppingCart, ShoppingBag, Truck as TruckIcon, CreditCard as Edit2, Trash2, Heart } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { supabase, Listing, PickerProfile, Profile } from '../lib/supabase';
import { uploadImage, uploadVideo } from '../lib/storage';
import { getOrCreateConversation } from '../lib/conversations';
import { MediaGallery } from './MediaGallery';
import { LocationPicker } from './LocationPicker';
import { OrderCheckoutModal } from './OrderCheckoutModal';
import { SearchFilters } from './SearchFilters';
import { FollowButton } from './FollowButton';
import { VerificationBadge } from './VerificationBadge';
import { ConfirmDialog } from './ConfirmDialog';
import ProfileCompletionBanner from './ProfileCompletionBanner';
import { trackPickerView } from '../lib/viewTracking';

type SortOption = 'newest' | 'price_low' | 'price_high' | 'distance';

type ListingWithPicker = Listing & {
  picker?: PickerProfile & { profile?: Profile };
};

type ListingsViewProps = {
  onContactPicker?: (pickerId: string) => void;
  onViewChange?: (view: string) => void;
};

export function ListingsView({ onContactPicker, onViewChange }: ListingsViewProps) {
  const { profile, user } = useAuth();
  const toast = useToast();
  const [listings, setListings] = useState<ListingWithPicker[]>([]);
  const [filteredListings, setFilteredListings] = useState<ListingWithPicker[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedRegion, setSelectedRegion] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [sortBy, setSortBy] = useState<SortOption>('newest');
  const [loading, setLoading] = useState(true);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingListing, setEditingListing] = useState<ListingWithPicker | null>(null);
  const [deletingListingId, setDeletingListingId] = useState<string | null>(null);
  const [pickerProfile, setPickerProfile] = useState<PickerProfile | null>(null);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState('');
  const [region, setRegion] = useState('');
  const [price, setPrice] = useState('');
  const [pickupLocation, setPickupLocation] = useState('');
  const [latitude, setLatitude] = useState<number | undefined>();
  const [longitude, setLongitude] = useState<number | undefined>();
  const [uploadedImages, setUploadedImages] = useState<string[]>([]);
  const [uploadedVideos, setUploadedVideos] = useState<string[]>([]);
  const [mediaLinks, setMediaLinks] = useState<string[]>([]);
  const [newMediaLink, setNewMediaLink] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const [createError, setCreateError] = useState('');
  const [creating, setCreating] = useState(false);
  const [checkoutListing, setCheckoutListing] = useState<ListingWithPicker | null>(null);
  const [selectedListing, setSelectedListing] = useState<ListingWithPicker | null>(null);
  const [collections, setCollections] = useState<any[]>([]);
  const [showAddToCollectionModal, setShowAddToCollectionModal] = useState(false);
  const [selectedListingForCollection, setSelectedListingForCollection] = useState<ListingWithPicker | null>(null);
  const [collectionNotes, setCollectionNotes] = useState('');

  // Fetch listings on mount and whenever profile changes
  useEffect(() => {
    const init = async () => {
      console.log('ListingsView mounted or profile changed, loading data...');
      setLoading(true);

      if (!profile || !user) {
        console.log('No profile or user available yet');
        setLoading(false);
        return;
      }

      if (profile.user_type === 'picker') {
        console.log('Loading picker profile and listings...');
        const pickerProf = await loadPickerProfile();
        // After loading picker profile, load listings with the loaded profile
        await loadListings(pickerProf);
      } else if (profile.user_type === 'client') {
        console.log('Loading listings for client...');
        // For clients, load listings directly
        await loadListings();
      } else {
        console.log('Unknown user type:', profile.user_type);
        setLoading(false);
      }
    };
    init();
  }, [profile?.user_type, profile?.id, user?.id]);

  useEffect(() => {
    filterListings();
  }, [listings, searchQuery, selectedRegion, selectedCategory, minPrice, maxPrice, sortBy]);

  const loadPickerProfile = async (): Promise<PickerProfile | null> => {
    try {
      console.log('loadPickerProfile - user:', user?.id, 'profile:', profile?.id);

      if (!user?.id) {
        throw new Error('User ID is missing');
      }

      const { data, error } = await supabase
        .from('picker_profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      console.log('Existing picker profile query result:', { data, error });

      if (error && error.code !== 'PGRST116') {
        console.error('Error fetching picker profile:', error);
        throw error;
      }

      // If picker profile doesn't exist, create it with default values
      if (!data) {
        console.log('Picker profile not found, creating new one...');

        if (!profile) {
          throw new Error('Profile data is not available');
        }

        const newPickerProfile = {
          user_id: user.id,
          current_location: profile.full_name ? `${profile.full_name}'s location` : 'My location',
          regions: [],
          specialties: [],
          rating: 0,
          total_reviews: 0,
          verified: false
        };

        console.log('Creating picker profile with data:', newPickerProfile);

        const { data: newProfile, error: createError } = await supabase
          .from('picker_profiles')
          .insert(newPickerProfile)
          .select()
          .single();

        console.log('Create picker profile result:', { newProfile, createError });

        if (createError) {
          console.error('Failed to create picker profile:', createError);
          // Check if it's a unique constraint violation - profile might already exist
          if (createError.code === '23505') {
            // Try to fetch again
            console.log('Duplicate found, fetching existing profile...');
            const { data: existingProfile } = await supabase
              .from('picker_profiles')
              .select('*')
              .eq('user_id', user.id)
              .maybeSingle();

            if (existingProfile) {
              console.log('Found existing picker profile:', existingProfile);
              setPickerProfile(existingProfile);
              return existingProfile;
            }
          }
          throw createError;
        }

        console.log('Successfully created picker profile:', newProfile);
        setPickerProfile(newProfile);
        return newProfile;
      } else {
        console.log('Found existing picker profile:', data);
        setPickerProfile(data);
        return data;
      }
    } catch (error: any) {
      console.error('Error in loadPickerProfile:', error);
      setPickerProfile(null);
      return null;
    }
  };

  const loadListings = async (pickerProf?: PickerProfile | null) => {
    try {
      // Use the provided picker profile or fall back to state
      const currentPickerProfile = pickerProf !== undefined ? pickerProf : pickerProfile;

      console.log('loadListings called with:', {
        userType: profile?.user_type,
        pickerProf,
        currentPickerProfile,
        pickerProfileState: pickerProfile
      });

      // If picker but no picker profile, can't load listings
      if (profile?.user_type === 'picker' && !currentPickerProfile) {
        console.warn('Picker profile not available, cannot load listings');
        setListings([]);
        setLoading(false);
        return;
      }

      let query = supabase
        .from('listings')
        .select(`
          *,
          picker:picker_profiles!listings_picker_id_fkey(
            *,
            profile:profiles!picker_profiles_user_id_fkey(*)
          )
        `)
        .eq('available', true)
        .order('created_at', { ascending: false });

      if (profile?.user_type === 'picker' && currentPickerProfile) {
        console.log('Filtering listings for picker_id:', currentPickerProfile.id);
        query = query.eq('picker_id', currentPickerProfile.id);
      }

      const { data, error } = await query;

      console.log('Listings query result:', { data, error, count: data?.length });

      if (error) {
        console.error('Error loading listings:', error);
        throw error;
      }
      setListings(data || []);
      console.log('Listings state updated with', data?.length || 0, 'items');
    } catch (error) {
      console.error('Failed to load listings:', error);
      setListings([]);
    } finally {
      setLoading(false);
    }
  };

  const filterListings = () => {
    console.log('filterListings called, listings count:', listings.length);
    let filtered = [...listings];

    if (searchQuery) {
      filtered = filtered.filter(
        (listing) =>
          listing.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
          listing.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
          listing.region.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    if (selectedRegion) {
      filtered = filtered.filter((listing) =>
        listing.region.toLowerCase().includes(selectedRegion.toLowerCase())
      );
    }

    if (selectedCategory) {
      filtered = filtered.filter((listing) =>
        listing.category.toLowerCase().includes(selectedCategory.toLowerCase())
      );
    }

    if (minPrice) {
      const min = parseFloat(minPrice);
      if (!isNaN(min)) {
        filtered = filtered.filter((listing) => listing.price >= min);
      }
    }

    if (maxPrice) {
      const max = parseFloat(maxPrice);
      if (!isNaN(max)) {
        filtered = filtered.filter((listing) => listing.price <= max);
      }
    }

    filtered.sort((a, b) => {
      switch (sortBy) {
        case 'price_low':
          return a.price - b.price;
        case 'price_high':
          return b.price - a.price;
        case 'newest':
        default:
          return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
      }
    });

    console.log('filterListings result:', filtered.length, 'items');
    setFilteredListings(filtered);
  };

  const clearFilters = () => {
    setSearchQuery('');
    setSelectedRegion('');
    setSelectedCategory('');
    setMinPrice('');
    setMaxPrice('');
    setSortBy('newest');
  };

  const hasActiveFilters = !!(searchQuery || selectedRegion || selectedCategory || minPrice || maxPrice || sortBy !== 'newest');

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    setUploadError('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadImage(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setUploadedImages([...uploadedImages, ...urls]);
    } catch (error: any) {
      setUploadError(error.message || 'Failed to upload images');
    } finally {
      setUploading(false);
    }
  };

  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    setUploadError('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadVideo(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setUploadedVideos([...uploadedVideos, ...urls]);
    } catch (error: any) {
      setUploadError(error.message || 'Failed to upload videos');
    } finally {
      setUploading(false);
    }
  };

  const removeImage = (url: string) => {
    setUploadedImages(uploadedImages.filter(img => img !== url));
  };

  const removeVideo = (url: string) => {
    setUploadedVideos(uploadedVideos.filter(vid => vid !== url));
  };

  const addMediaLink = () => {
    const trimmedLink = newMediaLink.trim();
    if (trimmedLink && !mediaLinks.includes(trimmedLink)) {
      setMediaLinks([...mediaLinks, trimmedLink]);
      setNewMediaLink('');
    }
  };

  const removeMediaLink = (url: string) => {
    setMediaLinks(mediaLinks.filter(link => link !== url));
  };

  const handleContactPicker = async (listing: ListingWithPicker) => {
    if (!profile || !listing.picker?.profile || profile.user_type !== 'client') return;

    try {
      await getOrCreateConversation(
        profile.id,
        listing.picker.profile.id
      );
      if (onContactPicker) {
        onContactPicker(listing.picker.profile.id);
      }
    } catch (error) {

    }
  };

  const handleAddToCart = async (listing: Listing) => {

    if (!user) {

      toast.error('Please log in to add items to cart');
      return;
    }

    if (profile?.user_type !== 'client') {

      toast.warning('Only collectors can add items to cart. Switch to collector mode first.');
      return;
    }

    const { data: sessionData } = await supabase.auth.getSession();

    if (!sessionData.session) {
      toast.error('Your session has expired. Please log in again.');
      return;
    }


    try {
      const { data: existingItem, error: checkError } = await supabase
        .from('cart_items')
        .select('id, quantity')
        .eq('client_id', user.id)
        .eq('listing_id', listing.id)
        .maybeSingle();

      if (checkError) {

        throw checkError;
      }

      if (existingItem) {

        const { error: updateError } = await supabase
          .from('cart_items')
          .update({ quantity: existingItem.quantity + 1 })
          .eq('id', existingItem.id);

        if (updateError) {

          throw updateError;
        }
        toast.success('Quantity updated in cart!');
      } else {

        const { error: insertError } = await supabase
          .from('cart_items')
          .insert({
            client_id: user.id,
            listing_id: listing.id,
            quantity: 1,
          });

        if (insertError) {

          throw insertError;
        }
        toast.success('Added to cart successfully!');
      }

    } catch (error: any) {

      const errorMsg = error.message || 'Could not add to cart';
      toast.error(`Failed to add to cart: ${errorMsg}`);
    }
  };

  const loadCollections = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase
        .from('collections')
        .select('id, name')
        .eq('user_id', user.id)
        .order('updated_at', { ascending: false });

      if (error) throw error;
      setCollections(data || []);
    } catch (error) {
      console.error('Error loading collections:', error);
    }
  };

  const openAddToCollectionModal = async (listing: ListingWithPicker) => {
    setSelectedListingForCollection(listing);
    await loadCollections();
    setShowAddToCollectionModal(true);
  };

  const addToCollection = async (collectionId: string) => {
    if (!selectedListingForCollection || !user) return;

    try {
      const { error } = await supabase
        .from('collection_items')
        .insert({
          collection_id: collectionId,
          listing_id: selectedListingForCollection.id,
          notes: collectionNotes
        });

      if (error) throw error;

      toast.success('Added to collection successfully!');
      setShowAddToCollectionModal(false);
      setSelectedListingForCollection(null);
      setCollectionNotes('');
    } catch (error: any) {
      toast.error('Failed to add to collection: ' + error.message);
    }
  };

  const startEditListing = (listing: ListingWithPicker) => {
    setEditingListing(listing);
    setTitle(listing.title);
    setDescription(listing.description);
    setCategory(listing.category || '');
    setRegion(listing.region);
    setPrice(listing.price.toString());
    setPickupLocation(listing.pickup_location || '');
    setLatitude(listing.latitude || undefined);
    setLongitude(listing.longitude || undefined);
    setUploadedImages(listing.images || []);
    setUploadedVideos(listing.videos || []);
    setMediaLinks(listing.media_links || []);
    setShowEditModal(true);
  };

  const cancelEdit = () => {
    setEditingListing(null);
    setTitle('');
    setDescription('');
    setCategory('');
    setRegion('');
    setPrice('');
    setPickupLocation('');
    setLatitude(undefined);
    setLongitude(undefined);
    setUploadedImages([]);
    setUploadedVideos([]);
    setMediaLinks([]);
    setNewMediaLink('');
    setUploadError('');
    setCreateError('');
    setShowCreateForm(false);
    setShowEditModal(false);
  };

  const handleDeleteListing = async (listingId: string) => {
    try {
      const { error } = await supabase
        .from('listings')
        .delete()
        .eq('id', listingId);

      if (error) throw error;

      setListings(prev => prev.filter(l => l.id !== listingId));
      toast.success('Listing deleted successfully!');
    } catch (error: any) {
      toast.error('Failed to delete listing: ' + error.message);
    } finally {
      setDeletingListingId(null);
    }
  };

  const handleCreateListing = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pickerProfile) {
      setCreateError('Picker profile not found. Please refresh the page.');
      return;
    }

    setCreating(true);
    setCreateError('');

    try {
      const listingData = {
        picker_id: pickerProfile.id,
        title,
        description,
        category: category || 'General',
        region,
        price: parseFloat(price),
        image_url: uploadedImages[0] || null,
        images: uploadedImages,
        videos: uploadedVideos,
        media_links: mediaLinks,
        latitude: latitude || null,
        longitude: longitude || null,
        pickup_location: pickupLocation || null,
        available: true,
      };

      if (editingListing) {
        // Update existing listing
        const { data, error } = await supabase
          .from('listings')
          .update(listingData)
          .eq('id', editingListing.id)
          .select(`
            *,
            picker:picker_profiles!listings_picker_id_fkey(
              *,
              profile:profiles!picker_profiles_user_id_fkey(*)
            )
          `)
          .single();

        if (error) throw error;

        if (data) {
          setListings(prev => prev.map(l => l.id === editingListing.id ? data : l));
        }

        toast.success('Listing updated successfully!');
      } else {
        // Create new listing
        const { data, error } = await supabase
          .from('listings')
          .insert(listingData)
          .select(`
            *,
            picker:picker_profiles!listings_picker_id_fkey(
              *,
              profile:profiles!picker_profiles_user_id_fkey(*)
            )
          `)
          .single();

        if (error) throw error;

        if (data) {
          setListings(prev => [data, ...prev]);
        }

        toast.success('Listing created successfully!');
      }

      // Clear form
      cancelEdit();
    } catch (error: any) {
      const errorMessage = error.message || `Failed to ${editingListing ? 'update' : 'create'} listing. Please try again.`;
      setCreateError(errorMessage);
      toast.error(errorMessage);
    } finally {
      setCreating(false);
    }
  };

  const uniqueRegions = Array.from(new Set(listings.map((l) => l.region))).sort();
  const uniqueCategories = Array.from(new Set(listings.map((l) => l.category).filter(Boolean))).sort();

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-500">Loading listings...</div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {profile?.user_type === 'picker' && onViewChange && (
        <ProfileCompletionBanner onNavigateToProfile={() => onViewChange('profile')} />
      )}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">
            {profile?.user_type === 'picker' ? 'My Listings' : 'Browse Listings'}
          </h1>
          <p className="text-gray-600 mt-1">
            {profile?.user_type === 'picker'
              ? 'Manage your souvenir listings and add new products'
              : 'Discover unique souvenirs from around the world'}
          </p>
        </div>
        {profile?.user_type === 'picker' && pickerProfile && (
          <button
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center gap-2"
          >
            <Plus className="w-5 h-5" />
            Add Product
          </button>
        )}
      </div>

      {profile?.user_type === 'picker' && !pickerProfile && !loading && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
          <h3 className="text-blue-900 font-semibold mb-2">Setting Up Your Picker Profile</h3>
          <p className="text-blue-800 mb-4">
            We're setting up your picker profile. Click the button below to complete the setup and start creating listings.
          </p>
          <button
            onClick={async () => {
              setLoading(true);
              setCreateError('');
              try {
                console.log('Starting picker profile setup...');
                await loadPickerProfile();
                console.log('Picker profile loaded, loading listings...');
                await loadListings();
                console.log('Setup complete');
              } catch (err: any) {
                console.error('Setup error:', err);
                setCreateError('Failed to setup profile: ' + err.message);
              } finally {
                setLoading(false);
              }
            }}
            disabled={loading}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Setting up...' : 'Complete Setup'}
          </button>
          {createError && (
            <p className="mt-3 text-sm text-red-600">{createError}</p>
          )}
        </div>
      )}

      {showCreateForm && (
        <div className="bg-white rounded-2xl shadow-lg p-8 mb-8">
          <h2 className="text-2xl font-bold text-gray-900 mb-6">
            {editingListing ? 'Edit Listing' : 'Create New Listing'}
          </h2>
          <form onSubmit={handleCreateListing} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Title <span className="text-red-600">*</span></label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Handcrafted Wooden Mask"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Description <span className="text-red-600">*</span></label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Describe the item in detail..."
                required
              />
            </div>

            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Region <span className="text-red-600">*</span></label>
                <input
                  type="text"
                  value={region}
                  onChange={(e) => setRegion(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Bali, Indonesia"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Category <span className="text-red-600">*</span></label>
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

            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
              <p className="text-sm text-blue-800">
                <strong>Pricing Tip:</strong> Set your item price only. When collectors place orders, you'll receive their delivery address and can provide a custom shipping quote based on actual courier costs to their specific location.
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Item Price (€) <span className="text-red-600">*</span></label>
              <div className="relative">
                <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="number"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="0.00"
                  min="0"
                  step="0.01"
                  required
                />
              </div>
              <p className="text-xs text-gray-500 mt-1">Cost of the item/service only (delivery costs added at checkout)</p>
              {price && parseFloat(price) > 0 && (
                <div className="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <p className="text-sm text-yellow-900 font-semibold mb-1">
                    Platform Fee Notice: 10% will be deducted
                  </p>
                  <div className="text-xs text-yellow-800 space-y-1">
                    <div className="flex justify-between">
                      <span>Your listing price:</span>
                      <span className="font-bold">€{parseFloat(price).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Platform fee (10%):</span>
                      <span className="font-bold text-red-700">-€{(parseFloat(price) * 0.10).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between pt-1 border-t border-yellow-300">
                      <span className="font-bold">You receive:</span>
                      <span className="font-bold text-green-700">€{(parseFloat(price) * 0.90).toFixed(2)}</span>
                    </div>
                  </div>
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Pickup Location (optional)
              </label>
              <input
                type="text"
                value={pickupLocation}
                onChange={(e) => setPickupLocation(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Shibuya Station, Tokyo"
              />
            </div>

            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Item Location (Optional)</h3>
              <p className="text-xs text-gray-500 mb-3">Add exact coordinates where this item will be picked up</p>
              <LocationPicker
                latitude={latitude}
                longitude={longitude}
                onLocationChange={(lat, lng) => {
                  setLatitude(lat);
                  setLongitude(lng);
                }}
                label="Item Pickup Location"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <ImageIcon className="w-4 h-4 inline mr-1" />
                Upload Images
              </label>
              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
                <input
                  type="file"
                  accept="image/jpeg,image/jpg,image/png,image/webp"
                  multiple
                  onChange={handleImageUpload}
                  className="hidden"
                  id="image-upload"
                  disabled={uploading}
                />
                <label
                  htmlFor="image-upload"
                  className="flex flex-col items-center justify-center cursor-pointer"
                >
                  <Upload className="w-8 h-8 text-gray-400 mb-2" />
                  <span className="text-sm text-gray-600">
                    Click to upload images (JPG, PNG, WebP)
                  </span>
                  <span className="text-xs text-gray-500 mt-1">Max 5MB per image</span>
                </label>
              </div>

              {uploadedImages.length > 0 && (
                <div className="grid grid-cols-3 gap-3 mt-3">
                  {uploadedImages.map((url, index) => (
                    <div key={index} className="relative group">
                      <img
                        src={url}
                        alt={`Upload ${index + 1}`}
                        className="w-full h-24 object-cover rounded-lg"
                      />
                      <button
                        type="button"
                        onClick={() => removeImage(url)}
                        className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Video className="w-4 h-4 inline mr-1" />
                Videos & Media Links (optional)
              </label>

              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Add TikTok or Video Link
                </label>
                <div className="flex gap-2">
                  <input
                    type="url"
                    value={newMediaLink}
                    onChange={(e) => setNewMediaLink(e.target.value)}
                    placeholder="https://www.tiktok.com/@username/video/..."
                    className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                  <button
                    type="button"
                    onClick={addMediaLink}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    <Plus className="w-5 h-5" />
                  </button>
                </div>
                {mediaLinks.length > 0 && (
                  <div className="flex flex-wrap gap-2 mt-3">
                    {mediaLinks.map((link, index) => (
                      <span
                        key={index}
                        className="inline-flex items-center gap-2 px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm"
                      >
                        <a href={link} target="_blank" rel="noopener noreferrer" className="hover:underline max-w-xs truncate">
                          {link}
                        </a>
                        <button
                          type="button"
                          onClick={() => removeMediaLink(link)}
                          className="hover:text-blue-900"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </span>
                    ))}
                  </div>
                )}
              </div>

              <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
                <input
                  type="file"
                  accept="video/mp4,video/webm,video/quicktime"
                  multiple
                  onChange={handleVideoUpload}
                  className="hidden"
                  id="video-upload"
                  disabled={uploading}
                />
                <label
                  htmlFor="video-upload"
                  className="flex flex-col items-center justify-center cursor-pointer"
                >
                  <Upload className="w-8 h-8 text-gray-400 mb-2" />
                  <span className="text-sm text-gray-600">
                    Or upload videos (MP4, WebM)
                  </span>
                  <span className="text-xs text-gray-500 mt-1">Max 50MB • Use MP4 with H.264 codec for best compatibility</span>
                </label>
              </div>

              {uploadedVideos.length > 0 && (
                <div className="grid grid-cols-2 gap-3 mt-3">
                  {uploadedVideos.map((url, index) => (
                    <div key={index} className="relative group">
                      <video
                        src={url}
                        className="w-full h-32 object-cover rounded-lg"
                        controls
                        preload="metadata"
                        playsInline
                      />
                      <button
                        type="button"
                        onClick={() => removeVideo(url)}
                        className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {uploadError && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                {uploadError}
              </div>
            )}

            {createError && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                <strong>Error:</strong> {createError}
              </div>
            )}

            {uploading && (
              <div className="bg-blue-50 text-blue-600 p-3 rounded-lg text-sm">
                Uploading files...
              </div>
            )}

            {creating && (
              <div className="bg-blue-50 text-blue-600 p-3 rounded-lg text-sm">
                Creating listing...
              </div>
            )}

            <div className="flex gap-3">
              <button
                type="submit"
                disabled={uploading || creating}
                className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {creating ? (editingListing ? 'Updating...' : 'Creating...') : (editingListing ? 'Update Listing' : 'Create Listing')}
              </button>
              <button
                type="button"
                onClick={cancelEdit}
                className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
            {uploadedImages.length === 0 && (
              <p className="text-sm text-yellow-600 bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                💡 Tip: Adding at least one image will make your listing more attractive to collectors!
              </p>
            )}
          </form>
        </div>
      )}

      <SearchFilters
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        selectedRegion={selectedRegion}
        onRegionChange={setSelectedRegion}
        selectedCategory={selectedCategory}
        onCategoryChange={setSelectedCategory}
        minPrice={minPrice}
        onMinPriceChange={setMinPrice}
        maxPrice={maxPrice}
        onMaxPriceChange={setMaxPrice}
        sortBy={sortBy}
        onSortChange={setSortBy}
        regions={uniqueRegions}
        categories={uniqueCategories}
        onClearFilters={clearFilters}
        hasActiveFilters={hasActiveFilters}
      />


<div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredListings.length === 0 ? (
          <div className="col-span-full bg-white rounded-2xl shadow-lg p-12 text-center">
            <p className="text-gray-500 text-lg">No listings found</p>
          </div>
        ) : (
          filteredListings.map((listing) => (
            <div
              key={listing.id}
              className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow cursor-pointer"
              onClick={() => {
                if (listing.picker_id) {
                  trackPickerView(listing.picker_id, 'listing', listing.id);
                }
                setSelectedListing(listing);
              }}
            >
              <MediaGallery
                images={listing.images}
                videos={listing.videos || []}
                title={listing.title}
              />

              <div className="p-6">
                <div className="flex items-start justify-between gap-3 mb-3">
                  <h3 className="text-xl font-bold text-gray-900 flex-1 leading-tight">{listing.title}</h3>
                  {listing.images && listing.images.length > 0 && (
                    <VerificationBadge storagePath={listing.images[0]} />
                  )}
                </div>
                <p className="text-base text-gray-700 mb-4 line-clamp-2 leading-relaxed">{listing.description}</p>

                <div className="flex flex-wrap gap-3 mb-4 text-sm text-gray-700">
                  <div className="flex items-center gap-1.5">
                    <MapPin className="w-4 h-4 text-gray-600" />
                    <span className="font-medium">{listing.region}</span>
                  </div>
                  {listing.category && (
                    <div className="flex items-center gap-1.5">
                      <Tag className="w-4 h-4 text-gray-600" />
                      <span className="font-medium">{listing.category}</span>
                    </div>
                  )}
                </div>

                {(listing.pickup_location || (listing.latitude && listing.longitude)) && (
                  <div className="mb-4 p-3 bg-gray-50 rounded-lg text-sm">
                    {listing.pickup_location && (
                      <div className="flex items-start gap-2 text-gray-800">
                        <MapPin className="w-4 h-4 mt-0.5 flex-shrink-0 text-gray-600" />
                        <span className="font-medium">{listing.pickup_location}</span>
                      </div>
                    )}
                    {listing.latitude && listing.longitude && (
                      <div className="mt-2">
                        <a
                          href={`https://www.openstreetmap.org/?mlat=${listing.latitude}&mlon=${listing.longitude}#map=13/${listing.latitude}/${listing.longitude}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-blue-600 hover:text-blue-700 text-sm font-medium underline"
                        >
                          View on map
                        </a>
                      </div>
                    )}
                  </div>
                )}

                {listing.picker?.profile && (
                  <div className="mb-4 pb-4 border-b border-gray-200">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <p className="text-sm text-gray-700">
                          by <span className="font-semibold text-gray-900">{listing.picker.profile.full_name}</span>
                          {listing.picker.verified && (
                            <span className="text-green-600 ml-1 font-bold">✓</span>
                          )}
                        </p>
                        {listing.picker.rating > 0 && (
                          <p className="text-sm text-gray-700 mt-1">
                            ⭐ <span className="font-semibold">{listing.picker.rating.toFixed(1)}</span> ({listing.picker.total_reviews} reviews)
                          </p>
                        )}
                      </div>
                      {profile?.user_type === 'client' && (
                        <FollowButton pickerId={listing.picker.user_id} />
                      )}
                    </div>
                  </div>
                )}

                <div className="flex flex-col gap-4">
                  <div className="bg-gray-100 p-4 rounded-lg border-2 border-gray-300">
                    <div className="text-4xl font-black text-black">
                      €{listing.price.toFixed(2)}
                    </div>
                    <div className="text-base text-black mt-1 font-bold">
                      + delivery costs at checkout
                    </div>
                  </div>
                  {profile?.user_type === 'client' && (
                    <div className="flex flex-col gap-3">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setCheckoutListing(listing);
                        }}
                        className="w-full bg-blue-600 text-white px-6 py-3 rounded-lg font-bold text-base hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                      >
                        <ShoppingCart className="w-5 h-5" />
                        Buy Now
                      </button>
                      <div className="grid grid-cols-3 gap-2">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleAddToCart(listing);
                          }}
                          className="bg-green-600 text-white px-4 py-2.5 rounded-lg font-bold text-sm hover:bg-green-700 transition-colors flex items-center justify-center gap-2"
                        >
                          <ShoppingBag className="w-5 h-5" />
                          Cart
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            openAddToCollectionModal(listing);
                          }}
                          className="bg-pink-600 text-white px-4 py-2.5 rounded-lg font-bold text-sm hover:bg-pink-700 transition-colors flex items-center justify-center gap-2"
                        >
                          <Heart className="w-5 h-5" />
                          Save
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleContactPicker(listing);
                          }}
                          className="bg-gray-200 text-black px-4 py-2.5 rounded-lg font-bold text-sm hover:bg-gray-300 transition-colors flex items-center justify-center gap-2"
                        >
                          <MessageCircle className="w-5 h-5" />
                          Chat
                        </button>
                      </div>
                    </div>
                  )}
                  {profile?.user_type === 'picker' && (
                    <div className="flex gap-2">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          startEditListing(listing);
                        }}
                        className="flex-1 bg-blue-600 text-white px-4 py-3 rounded-lg font-bold text-base hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                      >
                        <Edit2 className="w-5 h-5" />
                        Edit
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setDeletingListingId(listing.id);
                        }}
                        className="flex-1 bg-red-600 text-white px-4 py-3 rounded-lg font-bold text-base hover:bg-red-700 transition-colors flex items-center justify-center gap-2"
                      >
                        <Trash2 className="w-5 h-5" />
                        Delete
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Listing Detail Modal */}
      {selectedListing && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between z-10">
              <h2 className="text-2xl font-bold text-gray-900">Listing Details</h2>
              <button
                onClick={() => setSelectedListing(null)}
                className="text-gray-500 hover:text-gray-700 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="p-6">
              <MediaGallery
                images={selectedListing.images}
                videos={selectedListing.videos || []}
                title={selectedListing.title}
              />

              <div className="mt-6">
                <div className="flex items-start justify-between gap-3 mb-4">
                  <h3 className="text-3xl font-bold text-gray-900 flex-1">{selectedListing.title}</h3>
                  {selectedListing.images && selectedListing.images.length > 0 && (
                    <VerificationBadge storagePath={selectedListing.images[0]} />
                  )}
                </div>

                <div className="flex flex-wrap gap-3 mb-6 text-sm">
                  <div className="flex items-center gap-1 bg-gray-100 px-3 py-1.5 rounded-lg">
                    <MapPin className="w-4 h-4 text-gray-600" />
                    <span className="text-gray-700 font-medium">{selectedListing.region}</span>
                  </div>
                  {selectedListing.category && (
                    <div className="flex items-center gap-1 bg-blue-50 px-3 py-1.5 rounded-lg">
                      <Tag className="w-4 h-4 text-blue-600" />
                      <span className="text-blue-700 font-medium">{selectedListing.category}</span>
                    </div>
                  )}
                </div>

                <div className="prose max-w-none mb-6">
                  <h4 className="text-lg font-bold text-gray-900 mb-3">Description</h4>
                  <p className="text-base text-gray-800 whitespace-pre-wrap leading-relaxed">{selectedListing.description}</p>
                </div>

                {(selectedListing.pickup_location || (selectedListing.latitude && selectedListing.longitude)) && (
                  <div className="mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
                    <h4 className="text-lg font-bold text-gray-900 mb-3">Location</h4>
                    {selectedListing.pickup_location && (
                      <div className="flex items-start gap-2 text-gray-800 mb-2">
                        <MapPin className="w-5 h-5 mt-0.5 flex-shrink-0 text-gray-600" />
                        <span className="font-medium">{selectedListing.pickup_location}</span>
                      </div>
                    )}
                    {selectedListing.latitude && selectedListing.longitude && (
                      <a
                        href={`https://www.openstreetmap.org/?mlat=${selectedListing.latitude}&mlon=${selectedListing.longitude}#map=13/${selectedListing.latitude}/${selectedListing.longitude}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:text-blue-700 underline font-semibold text-base"
                        onClick={(e) => e.stopPropagation()}
                      >
                        View on map
                      </a>
                    )}
                  </div>
                )}

                {selectedListing.media_links && selectedListing.media_links.length > 0 && (
                  <div className="mb-6">
                    <h4 className="text-lg font-bold text-gray-900 mb-3">Media Links</h4>
                    <div className="flex flex-wrap gap-2">
                      {selectedListing.media_links.map((link, index) => (
                        <a
                          key={index}
                          href={link}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-blue-600 hover:text-blue-700 underline text-base font-medium"
                          onClick={(e) => e.stopPropagation()}
                        >
                          Media Link {index + 1}
                        </a>
                      ))}
                    </div>
                  </div>
                )}

                {selectedListing.picker?.profile && (
                  <div className="mb-6 pb-6 border-b-2 border-gray-200">
                    <h4 className="text-lg font-bold text-gray-900 mb-3">Picker Information</h4>
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <p className="text-gray-900 font-bold text-base">
                          {selectedListing.picker.profile.full_name}
                          {selectedListing.picker.verified && (
                            <span className="text-green-600 ml-2 font-bold">✓ Verified</span>
                          )}
                        </p>
                        {selectedListing.picker.rating > 0 && (
                          <p className="text-gray-700 mt-2 font-medium">
                            ⭐ <span className="font-bold">{selectedListing.picker.rating.toFixed(1)}</span> ({selectedListing.picker.total_reviews} reviews)
                          </p>
                        )}
                        {selectedListing.picker.current_location && (
                          <p className="text-gray-700 mt-2 font-medium">
                            <MapPin className="w-4 h-4 inline mr-1" />
                            {selectedListing.picker.current_location}
                          </p>
                        )}
                      </div>
                      {profile?.user_type === 'client' && (
                        <FollowButton pickerId={selectedListing.picker.user_id} />
                      )}
                    </div>
                  </div>
                )}

                <div className="bg-gradient-to-r from-blue-50 to-green-50 rounded-xl p-6 mb-6 border-2 border-blue-200">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-xl font-bold text-gray-900">Item Price</h4>
                      <p className="text-sm text-gray-800 mt-1 font-semibold">+ delivery costs at checkout</p>
                    </div>
                    <div className="text-4xl font-bold text-gray-900">
                      €{selectedListing.price.toFixed(2)}
                    </div>
                  </div>
                </div>

                {profile?.user_type === 'client' && (
                  <div className="flex gap-3">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleContactPicker(selectedListing);
                        setSelectedListing(null);
                      }}
                      className="flex-1 bg-gray-100 text-gray-700 px-6 py-3 rounded-lg font-medium hover:bg-gray-200 transition-colors flex items-center justify-center gap-2"
                    >
                      <MessageCircle className="w-5 h-5" />
                      Message Picker
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleAddToCart(selectedListing);
                      }}
                      className="flex-1 bg-green-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-green-700 transition-colors flex items-center justify-center gap-2"
                    >
                      <ShoppingBag className="w-5 h-5" />
                      Add to Cart
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setCheckoutListing(selectedListing);
                        setSelectedListing(null);
                      }}
                      className="flex-1 bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
                    >
                      <ShoppingCart className="w-5 h-5" />
                      Buy Now
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {checkoutListing && (
        <OrderCheckoutModal
          listing={checkoutListing}
          onClose={() => setCheckoutListing(null)}
          onOrderCreated={(order) => {
            setCheckoutListing(null);
            toast.success(
              'Order placed successfully! The picker will provide a shipping quote soon. Check your Orders page to track progress.',
              8000
            );
            // Navigate to orders view if available
            if (onViewChange) {
              setTimeout(() => onViewChange('orders'), 1500);
            }
          }}
        />
      )}

      {/* Edit Modal */}
      {showEditModal && editingListing && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto animate-scale-in">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between z-10">
              <h2 className="text-2xl font-bold text-gray-900">Edit Listing</h2>
              <button
                onClick={cancelEdit}
                className="text-gray-500 hover:text-gray-700 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleCreateListing} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Title <span className="text-red-600">*</span></label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Handcrafted Wooden Mask"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Description <span className="text-red-600">*</span></label>
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Describe the item in detail..."
                  required
                />
              </div>

              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Region <span className="text-red-600">*</span></label>
                  <input
                    type="text"
                    value={region}
                    onChange={(e) => setRegion(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Bali, Indonesia"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Category <span className="text-red-600">*</span></label>
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
                <label className="block text-sm font-medium text-gray-700 mb-2">Item Price (€) <span className="text-red-600">*</span></label>
                <div className="relative">
                  <DollarSign className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="number"
                    value={price}
                    onChange={(e) => setPrice(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="0.00"
                    min="0"
                    step="0.01"
                    required
                  />
                </div>
                <p className="text-xs text-gray-500 mt-1">Cost of the item/service only (delivery costs added at checkout)</p>
                {price && parseFloat(price) > 0 && (
                  <div className="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                    <p className="text-sm text-yellow-900 font-semibold mb-1">
                      Platform Fee Notice: 10% will be deducted
                    </p>
                    <div className="text-xs text-yellow-800 space-y-1">
                      <div className="flex justify-between">
                        <span>Your listing price:</span>
                        <span className="font-bold">€{parseFloat(price).toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span>Platform fee (10%):</span>
                        <span className="font-bold text-red-700">-€{(parseFloat(price) * 0.10).toFixed(2)}</span>
                      </div>
                      <div className="flex justify-between pt-1 border-t border-yellow-300">
                        <span className="font-bold">You receive:</span>
                        <span className="font-bold text-green-700">€{(parseFloat(price) * 0.90).toFixed(2)}</span>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Pickup Location (optional)</label>
                <input
                  type="text"
                  value={pickupLocation}
                  onChange={(e) => setPickupLocation(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Shibuya Station, Tokyo"
                />
              </div>

              <LocationPicker
                latitude={latitude}
                longitude={longitude}
                onLocationChange={(lat, lng) => {
                  setLatitude(lat);
                  setLongitude(lng);
                }}
                label="Item Pickup Location"
              />

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <ImageIcon className="w-4 h-4 inline mr-1" />
                  Upload Images
                </label>
                <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
                  <input
                    type="file"
                    accept="image/jpeg,image/jpg,image/png,image/webp"
                    multiple
                    onChange={handleImageUpload}
                    className="hidden"
                    id="edit-image-upload"
                    disabled={uploading}
                  />
                  <label
                    htmlFor="edit-image-upload"
                    className="flex flex-col items-center justify-center cursor-pointer"
                  >
                    <Upload className="w-8 h-8 text-gray-400 mb-2" />
                    <span className="text-sm text-gray-600">Click to upload images</span>
                  </label>
                </div>

                {uploadedImages.length > 0 && (
                  <div className="grid grid-cols-3 gap-3 mt-3">
                    {uploadedImages.map((url, index) => (
                      <div key={index} className="relative group">
                        <img
                          src={url}
                          alt={`Upload ${index + 1}`}
                          className="w-full h-24 object-cover rounded-lg"
                        />
                        <button
                          type="button"
                          onClick={() => removeImage(url)}
                          className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {uploadError && (
                <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                  {uploadError}
                </div>
              )}

              {createError && (
                <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
                  {createError}
                </div>
              )}

              <div className="flex gap-3">
                <button
                  type="submit"
                  disabled={uploading || creating}
                  className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                  {creating ? 'Updating...' : 'Update Listing'}
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
        isOpen={deletingListingId !== null}
        title="Delete Listing"
        message="Are you sure you want to delete this listing? This action cannot be undone."
        confirmText="Delete"
        cancelText="Cancel"
        variant="danger"
        onConfirm={() => {
          if (deletingListingId) {
            handleDeleteListing(deletingListingId);
          }
        }}
        onCancel={() => setDeletingListingId(null)}
      />

      {/* Add to Collection Modal */}
      {showAddToCollectionModal && selectedListingForCollection && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 max-w-md w-full max-h-[80vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                <Heart className="w-6 h-6 text-pink-600" />
                Add to Collection
              </h3>
              <button
                onClick={() => {
                  setShowAddToCollectionModal(false);
                  setSelectedListingForCollection(null);
                  setCollectionNotes('');
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mb-4 p-3 bg-gray-50 rounded-lg">
              <p className="text-sm font-medium text-gray-900">{selectedListingForCollection.title}</p>
              <p className="text-xs text-gray-600 mt-1">{selectedListingForCollection.region}</p>
            </div>

            {collections.length === 0 ? (
              <div className="text-center py-6">
                <p className="text-gray-600 mb-4">You don't have any collections yet.</p>
                <button
                  onClick={() => {
                    setShowAddToCollectionModal(false);
                    setSelectedListingForCollection(null);
                    onViewChange?.('collections');
                  }}
                  className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium"
                >
                  Create Your First Collection
                </button>
              </div>
            ) : (
              <>
                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">Select Collection</label>
                  <div className="space-y-2 max-h-60 overflow-y-auto">
                    {collections.map((collection) => (
                      <button
                        key={collection.id}
                        onClick={() => addToCollection(collection.id)}
                        className="w-full text-left px-4 py-3 border-2 border-gray-200 rounded-lg hover:border-pink-500 hover:bg-pink-50 transition-colors"
                      >
                        <span className="font-medium text-gray-900">{collection.name}</span>
                      </button>
                    ))}
                  </div>
                </div>

                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">Add Notes (Optional)</label>
                  <textarea
                    value={collectionNotes}
                    onChange={(e) => setCollectionNotes(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-pink-500 focus:border-transparent"
                    rows={3}
                    placeholder="Why do you want to save this item?"
                  />
                </div>

                <button
                  onClick={() => {
                    setShowAddToCollectionModal(false);
                    setSelectedListingForCollection(null);
                    onViewChange?.('collections');
                  }}
                  className="w-full px-4 py-2 text-sm text-pink-600 hover:text-pink-700 font-medium"
                >
                  + Create New Collection
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
