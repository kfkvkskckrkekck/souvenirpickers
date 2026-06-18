import { supabase } from './supabase';

export interface WishlistItem {
  id: string;
  user_id: string;
  listing_id: string;
  notes: string;
  created_at: string;
  listing?: any;
}

export async function addToWishlist(listingId: string, notes = '') {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('Must be logged in to add to wishlist');
  }

  const { data, error } = await supabase
    .from('wishlists')
    .insert({
      user_id: user.id,
      listing_id: listingId,
      notes
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data;
}

export async function removeFromWishlist(listingId: string) {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('Must be logged in to remove from wishlist');
  }

  const { error } = await supabase
    .from('wishlists')
    .delete()
    .eq('user_id', user.id)
    .eq('listing_id', listingId);

  if (error) {
    throw error;
  }
}

export async function getWishlist() {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return [];
  }

  const { data, error } = await supabase
    .from('wishlists')
    .select(`
      *,
      listing:listings(
        *,
        picker:profiles!listings_picker_id_fkey(
          id,
          full_name,
          avatar_url,
          trust_score
        )
      )
    `)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  if (error) {
    return [];
  }

  return data as WishlistItem[];
}

export async function isInWishlist(listingId: string): Promise<boolean> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return false;
  }

  const { data, error } = await supabase
    .from('wishlists')
    .select('id')
    .eq('user_id', user.id)
    .eq('listing_id', listingId)
    .maybeSingle();

  if (error) {
    return false;
  }

  return !!data;
}

export async function updateWishlistNotes(listingId: string, notes: string) {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    throw new Error('Must be logged in to update wishlist');
  }

  const { error } = await supabase
    .from('wishlists')
    .update({ notes })
    .eq('user_id', user.id)
    .eq('listing_id', listingId);

  if (error) {
    throw error;
  }
}

export async function getWishlistCount(): Promise<number> {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return 0;
  }

  const { count, error } = await supabase
    .from('wishlists')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id);

  if (error) {
    return 0;
  }

  return count || 0;
}
