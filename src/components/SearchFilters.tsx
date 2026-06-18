import { Search, SlidersHorizontal, X, DollarSign, Star, MapPin, ArrowUpDown } from 'lucide-react';
import { useState } from 'react';

type SortOption = 'newest' | 'price_low' | 'price_high' | 'distance';

type SearchFiltersProps = {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  selectedRegion: string;
  onRegionChange: (region: string) => void;
  selectedCategory: string;
  onCategoryChange: (category: string) => void;
  minPrice: string;
  onMinPriceChange: (price: string) => void;
  maxPrice: string;
  onMaxPriceChange: (price: string) => void;
  sortBy: SortOption;
  onSortChange: (sort: SortOption) => void;
  regions: string[];
  categories: string[];
  onClearFilters: () => void;
  hasActiveFilters: boolean;
};

export function SearchFilters({
  searchQuery,
  onSearchChange,
  selectedRegion,
  onRegionChange,
  selectedCategory,
  onCategoryChange,
  minPrice,
  onMinPriceChange,
  maxPrice,
  onMaxPriceChange,
  sortBy,
  onSortChange,
  regions,
  categories,
  onClearFilters,
  hasActiveFilters,
}: SearchFiltersProps) {
  const [showFilters, setShowFilters] = useState(false);

  return (
    <div className="bg-white rounded-xl shadow-md p-6 mb-6">
      <div className="flex flex-col md:flex-row gap-4 mb-4">
        <div className="flex-1 relative">
          <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Search souvenirs by title or description..."
            className="w-full pl-12 pr-4 py-3 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          />
        </div>

        <button
          onClick={() => setShowFilters(!showFilters)}
          className="flex items-center gap-2 px-6 py-3 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition-colors"
        >
          <SlidersHorizontal className="w-5 h-5" />
          Filters
          {hasActiveFilters && (
            <span className="bg-blue-600 text-white text-xs px-2 py-1 rounded-full">Active</span>
          )}
        </button>

        {hasActiveFilters && (
          <button
            onClick={onClearFilters}
            className="flex items-center gap-2 px-6 py-3 bg-red-50 text-red-600 hover:bg-red-100 rounded-lg font-medium transition-colors"
          >
            <X className="w-5 h-5" />
            Clear
          </button>
        )}
      </div>

      {showFilters && (
        <div className="border-t pt-4 space-y-4 animate-in fade-in slide-in-from-top-2">
          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <MapPin className="w-4 h-4 inline mr-1" />
                Region
              </label>
              <select
                value={selectedRegion}
                onChange={(e) => onRegionChange(e.target.value)}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">All Regions</option>
                {regions.map((region) => (
                  <option key={region} value={region}>
                    {region}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Star className="w-4 h-4 inline mr-1" />
                Category
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => onCategoryChange(e.target.value)}
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">All Categories</option>
                {categories.map((category) => (
                  <option key={category} value={category}>
                    {category}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="w-4 h-4 inline mr-1" />
                Min Price
              </label>
              <input
                type="number"
                value={minPrice}
                onChange={(e) => onMinPriceChange(e.target.value)}
                placeholder="0"
                min="0"
                step="1"
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="w-4 h-4 inline mr-1" />
                Max Price
              </label>
              <input
                type="number"
                value={maxPrice}
                onChange={(e) => onMaxPriceChange(e.target.value)}
                placeholder="Any"
                min="0"
                step="1"
                className="w-full px-4 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <ArrowUpDown className="w-4 h-4 inline mr-1" />
              Sort By
            </label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => onSortChange('newest')}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  sortBy === 'newest'
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Newest First
              </button>
              <button
                onClick={() => onSortChange('price_low')}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  sortBy === 'price_low'
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Price: Low to High
              </button>
              <button
                onClick={() => onSortChange('price_high')}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  sortBy === 'price_high'
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                Price: High to Low
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
