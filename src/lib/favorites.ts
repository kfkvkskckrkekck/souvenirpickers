import { supabase } from './supabase';

export async function toggleFavorite(clientId: string, listingId: string): Promise<boolean> {
  try {
    const { data: existing } = await supabase
      .from('favorites')
      .select('id')
      .eq('client_id', clientId)
      .eq('listing_id', listingId)
      .maybeSingle();

    if (existing) {
      await supabase
        .from('favorites')
        .delete()
        .eq('id', existing.id);
      return false;
    } else {
      await supabase
        .from('favorites')
        .insert({
          client_id: clientId,
          listing_id: listingId,
        });
      return true;
    }
  } catch (error) {
    throw error;
  }
}

export async function toggleFavoritePicker(clientId: string, pickerId: string): Promise<boolean> {
  try {
    const { data: existing } = await supabase
      .from('favorite_pickers')
      .select('id')
      .eq('client_id', clientId)
      .eq('picker_id', pickerId)
      .maybeSingle();

    if (existing) {
      await supabase
        .from('favorite_pickers')
        .delete()
        .eq('id', existing.id);
      return false;
    } else {
      await supabase
        .from('favorite_pickers')
        .insert({
          client_id: clientId,
          picker_id: pickerId,
        });
      return true;
    }
  } catch (error) {
    throw error;
  }
}

export async function isFavorite(clientId: string, listingId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('favorites')
      .select('id')
      .eq('client_id', clientId)
      .eq('listing_id', listingId)
      .maybeSingle();

    return !!data;
  } catch (error) {
    return false;
  }
}

export async function isFavoritePicker(clientId: string, pickerId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('favorite_pickers')
      .select('id')
      .eq('client_id', clientId)
      .eq('picker_id', pickerId)
      .maybeSingle();

    return !!data;
  } catch (error) {
    return false;
  }
}

export async function getFavoriteListings(clientId: string) {
  try {
    const { data, error } = await supabase
      .from('favorites')
      .select('*, listing:listings(*)')
      .eq('client_id', clientId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  } catch (error) {
    return [];
  }
}

export async function reportUser(reporterId: string, reportedUserId: string, reason: string, description?: string) {
  try {
    const { error } = await supabase
      .from('reported_users')
      .insert({
        reporter_id: reporterId,
        reported_user_id: reportedUserId,
        reason,
        description,
        status: 'pending',
      });

    if (error) throw error;
  } catch (error) {
    throw error;
  }
}

export async function blockUser(userId: string, blockedUserId: string) {
  try {
    const { error } = await supabase
      .from('blocked_users')
      .insert({
        user_id: userId,
        blocked_user_id: blockedUserId,
      });

    if (error) throw error;
  } catch (error) {
    throw error;
  }
}

export async function unblockUser(userId: string, blockedUserId: string) {
  try {
    const { error } = await supabase
      .from('blocked_users')
      .delete()
      .eq('user_id', userId)
      .eq('blocked_user_id', blockedUserId);

    if (error) throw error;
  } catch (error) {
    throw error;
  }
}

export async function isBlocked(userId: string, otherUserId: string): Promise<boolean> {
  try {
    const { data } = await supabase
      .from('blocked_users')
      .select('id')
      .eq('user_id', userId)
      .eq('blocked_user_id', otherUserId)
      .maybeSingle();

    return !!data;
  } catch (error) {
    return false;
  }
}

export async function createNotification(
  userId: string,
  type: string,
  title: string,
  message: string,
  link?: string
) {
  try {
    const { error } = await supabase
      .from('notifications')
      .insert({
        user_id: userId,
        type,
        title,
        message,
        link,
        read: false,
      });

    if (error) throw error;
  } catch (error) {
    throw error;
  }
}
