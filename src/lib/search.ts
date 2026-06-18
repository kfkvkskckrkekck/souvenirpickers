import { supabase } from './supabase';

export interface SearchFilters {
  query?: string;
  category?: string;
  region?: string;
  minPrice?: number;
  maxPrice?: number;
  sortBy?: 'relevance' | 'price_asc' | 'price_desc' | 'newest' | 'trending';
  available?: boolean;
}

export interface SearchResult {
  id: string;
  title: string;
  description: string;
  category: string;
  region: string;
  price: number;
  image_url: string;
  images: string[];
  picker_id: string;
  created_at: string;
  pickup_location: string;
  available: boolean;
}

export async function searchListings(filters: SearchFilters = {}) {
  let query = supabase
    .from('listings')
    .select(`
      *,
      picker:profiles!listings_picker_id_fkey(
        id,
        full_name,
        avatar_url,
        trust_score
      )
    `);

  if (filters.query) {
    const searchTerm = filters.query.trim();

    // Try full-text search first if search_vector exists
    const { data: textSearchData, error: textSearchError } = await query.textSearch('search_vector', searchTerm, {
      type: 'websearch',
      config: 'english'
    });

    // If full-text search fails or returns no results, fall back to ILIKE search
    if (textSearchError || !textSearchData || textSearchData.length === 0) {
      query = query.or(`title.ilike.%${searchTerm}%,description.ilike.%${searchTerm}%,category.ilike.%${searchTerm}%,region.ilike.%${searchTerm}%`);
    } else {
      // Use the text search results
      return textSearchData as SearchResult[];
    }
  }

  if (filters.category) {
    query = query.eq('category', filters.category);
  }

  if (filters.region) {
    query = query.eq('region', filters.region);
  }

  if (filters.minPrice !== undefined) {
    query = query.gte('price', filters.minPrice);
  }

  if (filters.maxPrice !== undefined) {
    query = query.lte('price', filters.maxPrice);
  }

  if (filters.available !== undefined) {
    query = query.eq('available', filters.available);
  }

  switch (filters.sortBy) {
    case 'price_asc':
      query = query.order('price', { ascending: true });
      break;
    case 'price_desc':
      query = query.order('price', { ascending: false });
      break;
    case 'newest':
      query = query.order('created_at', { ascending: false });
      break;
    case 'relevance':
    default:
      query = query.order('created_at', { ascending: false });
  }

  const { data, error } = await query;

  if (error) {
    throw error;
  }

  return data as SearchResult[];
}

export async function recordSearch(searchQuery: string, filters: SearchFilters, resultsCount: number, userId?: string) {
  const { error: historyError } = await supabase
    .from('search_history')
    .insert({
      user_id: userId || null,
      search_query: searchQuery,
      filters_applied: filters,
      results_count: resultsCount
    });

  if (historyError) {
  }

  if (searchQuery.trim()) {
    const { error: popularError } = await supabase.rpc('upsert_popular_search', {
      term: searchQuery.toLowerCase().trim()
    });

    if (popularError) {
      const { error: insertError } = await supabase
        .from('popular_searches')
        .upsert({
          search_term: searchQuery.toLowerCase().trim(),
          search_count: 1,
          last_searched_at: new Date().toISOString()
        }, {
          onConflict: 'search_term',
          ignoreDuplicates: false
        });

      if (insertError) {
      }
    }
  }
}

export async function getPopularSearches(limit = 10) {
  const { data, error } = await supabase
    .from('popular_searches')
    .select('search_term, search_count')
    .order('search_count', { ascending: false })
    .limit(limit);

  if (error) {
    return [];
  }

  return data;
}

export async function getTrendingListings(limit = 10) {
  const { data, error } = await supabase.rpc('get_trending_listings', {
    time_period: '7 days',
    limit_count: limit
  });

  if (error || !data || data.length === 0) {
    // Fallback: return recent available listings if no trending data
    const { data: fallbackListings, error: fallbackError } = await supabase
      .from('listings')
      .select(`
        *,
        picker:profiles!listings_picker_id_fkey(
          id,
          full_name,
          avatar_url,
          trust_score
        )
      `)
      .eq('available', true)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (fallbackError) {
      return [];
    }

    return fallbackListings || [];
  }

  const listingIds = data.map((item: any) => item.listing_id);

  const { data: listings, error: listingsError } = await supabase
    .from('listings')
    .select(`
      *,
      picker:profiles!listings_picker_id_fkey(
        id,
        full_name,
        avatar_url,
        trust_score
      )
    `)
    .in('id', listingIds);

  if (listingsError) {
    return [];
  }

  return listings || [];
}

export async function recordListingView(listingId: string, userId?: string, sessionId?: string) {
  const { error } = await supabase
    .from('listing_views')
    .insert({
      listing_id: listingId,
      user_id: userId || null,
      session_id: sessionId || null
    });

  if (error) {
  }
}

export async function getUserSearchHistory(userId: string, limit = 20) {
  const { data, error } = await supabase
    .from('search_history')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    return [];
  }

  return data;
}

export async function getAvailableCategories() {
  const { data, error } = await supabase
    .from('listings')
    .select('category')
    .eq('available', true);

  if (error) {
    return [];
  }

  const uniqueCategories = [...new Set(data.map(item => item.category))].filter(Boolean);
  return uniqueCategories.sort();
}

export async function getAvailableRegions() {
  const { data, error } = await supabase
    .from('listings')
    .select('region')
    .eq('available', true);

  if (error) {
    return [];
  }

  const uniqueRegions = [...new Set(data.map(item => item.region))].filter(Boolean);
  return uniqueRegions.sort();
}
