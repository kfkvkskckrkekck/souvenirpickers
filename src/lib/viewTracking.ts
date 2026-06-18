import { supabase } from './supabase';

export type ViewType = 'profile' | 'listing' | 'search_result';

export async function trackPickerView(
  pickerId: string,
  viewType: ViewType,
  listingId?: string
): Promise<void> {
  try {
    const { data: { user } } = await supabase.auth.getUser();

    const { data, error } = await supabase
      .from('picker_profile_views')
      .insert({
        picker_id: pickerId,
        viewer_id: user?.id || null,
        view_type: viewType,
        listing_id: listingId || null
      })
      .select();

    if (error) {
      console.error('Error tracking view:', error);
    } else {
      console.log('View tracked successfully:', data);
    }
  } catch (error) {
    console.error('Exception tracking view:', error);
  }
}

export async function getPickerViewCount(
  pickerId: string,
  startDate?: Date
): Promise<number> {
  try {
    let query = supabase
      .from('picker_profile_views')
      .select('id', { count: 'exact', head: true })
      .eq('picker_id', pickerId);

    if (startDate) {
      query = query.gte('created_at', startDate.toISOString());
    }

    const { count } = await query;
    return count || 0;
  } catch (error) {
    console.error('Error getting view count:', error);
    return 0;
  }
}
