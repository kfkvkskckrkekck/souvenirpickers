import { useState, useEffect } from "react";
import {
  Search,
  MapPin,
  Star,
  Tag,
  MessageCircle,
  CreditCard,
  Eye,
  Facebook,
  Twitter,
  Instagram,
  X,
  Users,
  BadgeCheck,
  User,
  SlidersHorizontal,
} from "lucide-react";
import {
  supabase,
  PickerProfile,
  Profile,
  PaymentMethod,
} from "../lib/supabase";
import { useAuth } from "../contexts/AuthContext";
import { ReviewsList } from "./ReviewsList";
import ProfileCompletionBanner from "./ProfileCompletionBanner";
import { trackPickerView } from "../lib/viewTracking";

type PickerWithProfile = PickerProfile & {
  profile?: Profile;
  payment_methods?: PaymentMethod[];
};

type PickersViewProps = {
  onViewChange?: (view: string) => void;
  onContactPicker?: (pickerId: string) => void;
  selectedPickerId?: string;
};

export function PickersView({
  onViewChange,
  onContactPicker,
}: PickersViewProps = {}) {
  const { profile: currentUser } = useAuth();
  const [pickers, setPickers] = useState<PickerWithProfile[]>([]);
  const [filteredPickers, setFilteredPickers] = useState<PickerWithProfile[]>(
    [],
  );
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedRegion, setSelectedRegion] = useState("");
  const [selectedSpecialty, setSelectedSpecialty] = useState("");
  const [minRating, setMinRating] = useState("");
  const [verifiedOnly, setVerifiedOnly] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [loading, setLoading] = useState(true);
  const [selectedPicker, setSelectedPicker] =
    useState<PickerWithProfile | null>(null);

  useEffect(() => {
    loadPickers();
  }, []);

  const loadPickers = async () => {
    try {
      const { data, error } = await supabase
        .from("picker_profiles")
        .select(
          `
          *,
          profile:profiles!picker_profiles_user_id_fkey(*)
        `,
        )
        .order("rating", { ascending: false });

      if (error) throw error;

      // Show all picker profiles including the current user's
      const pickersWithPayments = await Promise.all(
        (data || []).map(async (picker) => {
          const { data: paymentData } = await supabase
            .from("picker_payment_methods")
            .select("*")
            .eq("picker_id", picker.id)
            .eq("active", true)
            .order("preferred", { ascending: false });

          return {
            ...picker,
            payment_methods: paymentData || [],
          };
        }),
      );

      setPickers(pickersWithPayments);
      setFilteredPickers(pickersWithPayments);
    } catch (error) {
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    let filtered = [...pickers];

    if (searchQuery) {
      filtered = filtered.filter(
        (picker) =>
          picker.profile?.full_name
            .toLowerCase()
            .includes(searchQuery.toLowerCase()) ||
          picker.current_location
            .toLowerCase()
            .includes(searchQuery.toLowerCase()) ||
          picker.specialties.some((s) =>
            s.toLowerCase().includes(searchQuery.toLowerCase()),
          ),
      );
    }

    if (selectedRegion) {
      filtered = filtered.filter((picker) =>
        picker.regions.some((r) =>
          r.toLowerCase().includes(selectedRegion.toLowerCase()),
        ),
      );
    }

    if (selectedSpecialty) {
      filtered = filtered.filter((picker) =>
        picker.specialties.some((s) =>
          s.toLowerCase().includes(selectedSpecialty.toLowerCase()),
        ),
      );
    }

    if (minRating) {
      const ratingThreshold = parseFloat(minRating);
      filtered = filtered.filter((picker) => picker.rating >= ratingThreshold);
    }

    if (verifiedOnly) {
      filtered = filtered.filter((picker) => picker.verified);
    }

    setFilteredPickers(filtered);
  };

  const clearFilters = () => {
    setSearchQuery("");
    setSelectedRegion("");
    setSelectedSpecialty("");
    setMinRating("");
    setVerifiedOnly(false);
    setFilteredPickers(pickers);
  };

  const allRegions = Array.from(
    new Set(pickers.flatMap((p) => p.regions)),
  ).sort();

  const allSpecialties = Array.from(
    new Set(pickers.flatMap((p) => p.specialties)),
  ).sort();

  const activeFiltersCount = [
    searchQuery,
    selectedRegion,
    selectedSpecialty,
    minRating,
    verifiedOnly,
  ].filter(Boolean).length;

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-center h-64">
          <div className="text-gray-500">Loading pickers...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {currentUser?.user_type === "picker" && onViewChange && (
        <ProfileCompletionBanner
          onNavigateToProfile={() => onViewChange("profile")}
        />
      )}
      <div className="flex items-center gap-3 mb-8">
        <div className="w-11 h-11 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
          <Users className="w-5 h-5 text-blue-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">
            Find Pickers
          </h1>
          <p className="text-sm text-gray-500">
            Connect with verified pickers from around the world
          </p>
        </div>
      </div>

      <div className="sticky top-0 z-30 -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 py-3 bg-gray-50">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
          <div className="flex flex-col md:flex-row gap-3">
            <div className="flex-1 relative">
              <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyPress={(e) => e.key === "Enter" && handleSearch()}
                placeholder="Search by name, location, or specialty..."
                className="w-full pl-11 pr-4 py-2.5 border border-gray-200 bg-gray-50 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500 focus:bg-white transition-colors"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="flex items-center justify-center gap-2 px-5 py-2.5 bg-gray-50 border border-gray-200 hover:bg-gray-100 rounded-xl font-semibold text-sm text-gray-700 transition-colors relative"
            >
              <SlidersHorizontal className="w-4 h-4" />
              Filters
              {activeFiltersCount > 0 && (
                <span className="bg-blue-600 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
                  {activeFiltersCount}
                </span>
              )}
            </button>
            <button
              onClick={handleSearch}
              className="flex items-center justify-center gap-2 px-5 py-2.5 bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors font-semibold text-sm shadow-sm"
            >
              <Search className="w-4 h-4" />
              Search
            </button>
          </div>

          {showFilters && (
            <div className="mt-4 pt-4 border-t border-gray-100">
              <div className="grid md:grid-cols-3 gap-4 mb-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Region
                  </label>
                  <select
                    value={selectedRegion}
                    onChange={(e) => setSelectedRegion(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500"
                  >
                    <option value="">All Regions</option>
                    {allRegions.map((region) => (
                      <option key={region} value={region}>
                        {region}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Specialty
                  </label>
                  <select
                    value={selectedSpecialty}
                    onChange={(e) => setSelectedSpecialty(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500"
                  >
                    <option value="">All Specialties</option>
                    {allSpecialties.map((specialty) => (
                      <option key={specialty} value={specialty}>
                        {specialty}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Minimum Rating
                  </label>
                  <select
                    value={minRating}
                    onChange={(e) => setMinRating(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-blue-500/40 focus:border-blue-500"
                  >
                    <option value="">Any Rating</option>
                    <option value="4.5">4.5+ Stars</option>
                    <option value="4.0">4.0+ Stars</option>
                    <option value="3.5">3.5+ Stars</option>
                    <option value="3.0">3.0+ Stars</option>
                  </select>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={verifiedOnly}
                    onChange={(e) => setVerifiedOnly(e.target.checked)}
                    className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <span className="text-sm text-gray-700">
                    Show verified pickers only
                  </span>
                </label>

                {activeFiltersCount > 0 && (
                  <button
                    onClick={clearFilters}
                    className="text-sm text-red-600 hover:text-red-700 font-semibold flex items-center gap-1"
                  >
                    <X className="w-4 h-4" />
                    Clear all filters
                  </button>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredPickers.length === 0 ? (
          <div className="col-span-full bg-white rounded-2xl shadow-sm border border-gray-100 p-16 text-center">
            <div className="w-16 h-16 rounded-2xl bg-gray-50 flex items-center justify-center mx-auto mb-4">
              <Users className="w-8 h-8 text-gray-300" />
            </div>
            <p className="text-gray-700 font-semibold">No pickers found</p>
            <p className="text-sm text-gray-400 mt-1">
              Try adjusting your search or filters
            </p>
          </div>
        ) : (
          filteredPickers.map((picker) => {
            const avatarUrl = picker.profile?.avatar_url;
            const displayName = picker.full_name || picker.profile?.full_name;
            const tags = [...picker.regions, ...picker.specialties];

            return (
              <div
                key={picker.id}
                className="bg-white rounded-2xl shadow-sm border border-gray-100 hover:shadow-md hover:-translate-y-0.5 transition-all duration-300 h-full flex flex-col"
              >
                <div className="p-5 flex flex-col flex-1">
                  <div className="flex items-start gap-3 mb-3">
                    {avatarUrl ? (
                      <img
                        src={avatarUrl}
                        alt={displayName}
                        className="w-12 h-12 rounded-full object-cover ring-1 ring-gray-100 flex-shrink-0"
                      />
                    ) : (
                      <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center flex-shrink-0">
                        <User className="w-6 h-6 text-blue-600" />
                      </div>
                    )}
                    <div className="flex-1 min-w-0 pt-0.5">
                      <div className="flex items-center gap-1.5">
                        <h3 className="text-base font-bold text-gray-900 tracking-tight truncate">
                          {displayName}
                        </h3>
                        {picker.verified && (
                          <BadgeCheck className="w-4 h-4 text-blue-500 flex-shrink-0" />
                        )}
                      </div>
                      <div className="flex items-center gap-1 text-gray-500 mt-0.5">
                        <MapPin className="w-3.5 h-3.5 flex-shrink-0" />
                        <span className="text-xs truncate">
                          {picker.current_location}
                        </span>
                      </div>
                    </div>
                  </div>

                  {picker.rating > 0 && (
                    <div className="inline-flex self-start items-center gap-1 bg-amber-50 text-amber-700 px-2.5 py-1 rounded-full text-xs font-semibold mb-3">
                      <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                      {picker.rating.toFixed(1)}
                      <span className="font-normal text-amber-600">
                        ({picker.total_reviews})
                      </span>
                    </div>
                  )}

                  {(picker.bio || picker.profile?.bio) && (
                    <p className="text-sm text-gray-500 mb-3 line-clamp-2 leading-relaxed">
                      {picker.bio || picker.profile?.bio}
                    </p>
                  )}

                  {tags.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 mb-3">
                      {picker.regions.slice(0, 2).map((region) => (
                        <span
                          key={region}
                          className="inline-flex items-center gap-1 bg-blue-50 text-blue-700 text-xs font-semibold px-2.5 py-1 rounded-full"
                        >
                          <MapPin className="w-3 h-3" />
                          {region}
                        </span>
                      ))}
                      {picker.specialties.slice(0, 2).map((specialty) => (
                        <span
                          key={specialty}
                          className="inline-flex items-center gap-1 bg-orange-50 text-orange-700 text-xs font-semibold px-2.5 py-1 rounded-full"
                        >
                          <Tag className="w-3 h-3" />
                          {specialty}
                        </span>
                      ))}
                      {tags.length > 4 && (
                        <span className="text-xs text-gray-400 px-1 py-1 font-medium">
                          +{tags.length - 4} more
                        </span>
                      )}
                    </div>
                  )}

                  {picker.payment_methods &&
                    picker.payment_methods.length > 0 && (
                      <div className="mb-3 p-2.5 bg-gray-50 rounded-xl">
                        <p className="flex items-center gap-1 text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
                          <CreditCard className="w-3.5 h-3.5" />
                          Accepts
                        </p>
                        <div className="flex flex-wrap gap-1.5">
                          {picker.payment_methods.slice(0, 3).map((method) => (
                            <span
                              key={method.id}
                              className="inline-flex items-center gap-1 bg-white text-green-700 px-2 py-0.5 rounded-full text-xs font-medium border border-green-200"
                            >
                              {method.method_name}
                              {method.preferred && (
                                <Star className="w-2.5 h-2.5 fill-amber-400 text-amber-400" />
                              )}
                            </span>
                          ))}
                          {picker.payment_methods.length > 3 && (
                            <span className="text-xs text-gray-400 px-1 py-0.5">
                              +{picker.payment_methods.length - 3}
                            </span>
                          )}
                        </div>
                      </div>
                    )}

                  <div className="flex gap-2 mt-auto pt-1">
                    <button
                      onClick={() => {
                        trackPickerView(picker.id, "profile");
                        setSelectedPicker(picker);
                      }}
                      className="flex-1 bg-gray-100 text-gray-700 py-2 rounded-xl font-semibold text-sm hover:bg-gray-200 transition-colors flex items-center justify-center gap-1.5"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      View Reviews
                    </button>
                    <button
                      onClick={() => {
                        if (!picker.user_id) return;
                        trackPickerView(picker.id, "profile");
                        onContactPicker?.(picker.user_id);
                      }}
                      className="flex-1 bg-blue-600 text-white py-2 rounded-xl font-semibold text-sm hover:bg-blue-700 transition-colors shadow-sm flex items-center justify-center gap-1.5"
                    >
                      <MessageCircle className="w-3.5 h-3.5" />
                      Contact
                    </button>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      {selectedPicker && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-xl max-w-3xl w-full max-h-[90vh] overflow-y-auto p-8">
            <div className="flex items-start justify-between mb-6">
              <div>
                <h2 className="text-2xl font-bold text-gray-900">
                  {selectedPicker.full_name ||
                    selectedPicker.profile?.full_name}
                </h2>
                <div className="flex items-center gap-2 mt-2">
                  <div className="flex items-center gap-1">
                    {selectedPicker.rating > 0 && (
                      <>
                        <Star className="w-5 h-5 fill-yellow-400 text-yellow-400" />
                        <span className="font-semibold">
                          {selectedPicker.rating.toFixed(1)}
                        </span>
                        <span className="text-gray-500 text-sm">
                          ({selectedPicker.total_reviews}{" "}
                          {selectedPicker.total_reviews === 1
                            ? "review"
                            : "reviews"}
                          )
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedPicker(null)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <span className="text-2xl">&times;</span>
              </button>
            </div>

            {(selectedPicker.bio || selectedPicker.profile?.bio) && (
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  About
                </h3>
                <p className="text-gray-600">
                  {selectedPicker.bio || selectedPicker.profile?.bio}
                </p>
              </div>
            )}

            {(selectedPicker.profile?.facebook_url ||
              selectedPicker.profile?.twitter_url ||
              selectedPicker.profile?.instagram_url ||
              selectedPicker.profile?.threads_url) && (
              <div className="mb-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-3">
                  Social Media
                </h3>
                <div className="flex flex-wrap gap-3">
                  {selectedPicker.profile?.facebook_url && (
                    <a
                      href={selectedPicker.profile.facebook_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 transition-colors"
                    >
                      <Facebook className="w-5 h-5" />
                      <span className="font-medium">Facebook</span>
                    </a>
                  )}
                  {selectedPicker.profile?.twitter_url && (
                    <a
                      href={selectedPicker.profile.twitter_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-400 rounded-lg hover:bg-blue-100 transition-colors"
                    >
                      <Twitter className="w-5 h-5" />
                      <span className="font-medium">Twitter</span>
                    </a>
                  )}
                  {selectedPicker.profile?.instagram_url && (
                    <a
                      href={selectedPicker.profile.instagram_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-2 px-4 py-2 bg-pink-50 text-pink-600 rounded-lg hover:bg-pink-100 transition-colors"
                    >
                      <Instagram className="w-5 h-5" />
                      <span className="font-medium">Instagram</span>
                    </a>
                  )}
                  {selectedPicker.profile?.threads_url && (
                    <a
                      href={selectedPicker.profile.threads_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-2 px-4 py-2 bg-gray-50 text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"
                    >
                      <svg
                        className="w-5 h-5"
                        viewBox="0 0 24 24"
                        fill="currentColor"
                      >
                        <path d="M12.186 24h-.007c-3.581-.024-6.334-1.205-8.184-3.509C2.35 18.44 1.5 15.586 1.472 12.01v-.017c.03-3.579.879-6.43 2.525-8.482C5.845 1.205 8.6.024 12.18 0h.014c2.746.02 5.043.725 6.826 2.098 1.677 1.29 2.858 3.13 3.509 5.467l-2.04.569c-.542-1.937-1.488-3.427-2.812-4.424-1.452-1.094-3.387-1.67-5.746-1.708-3.05.022-5.317.977-6.73 2.838-1.33 1.749-2.052 4.14-2.084 6.912v.017c.032 2.766.755 5.156 2.084 6.91 1.413 1.862 3.68 2.816 6.73 2.838 2.36-.038 4.295-.613 5.746-1.707 1.324-.998 2.27-2.488 2.812-4.424l2.04.569c-.651 2.337-1.832 4.177-3.509 5.467-1.783 1.373-4.08 2.078-6.826 2.098z" />
                      </svg>
                      <span className="font-medium">Threads</span>
                    </a>
                  )}
                </div>
              </div>
            )}

            <div className="mb-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">
                Reviews
              </h3>
              <ReviewsList pickerId={selectedPicker.id} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
