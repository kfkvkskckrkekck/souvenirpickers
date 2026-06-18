import { useState, useEffect } from 'react';
import { Heart } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type FollowButtonProps = {
  pickerId: string;
  onFollowChange?: () => void;
};

export function FollowButton({ pickerId, onFollowChange }: FollowButtonProps) {
  const { user, profile } = useAuth();
  const [isFollowing, setIsFollowing] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    checkFollowStatus();
  }, [user, pickerId]);

  const checkFollowStatus = async () => {
    if (!user || profile?.user_type !== 'client') return;

    try {
      const { data, error } = await supabase
        .from('favorite_pickers')
        .select('id')
        .eq('client_id', user.id)
        .eq('picker_id', pickerId)
        .maybeSingle();

      if (error) throw error;
      setIsFollowing(!!data);
    } catch (error) {

    }
  };

  const handleToggleFollow = async () => {
    if (!user || profile?.user_type !== 'client' || loading) return;

    setLoading(true);

    try {
      if (isFollowing) {
        const { error } = await supabase
          .from('favorite_pickers')
          .delete()
          .eq('client_id', user.id)
          .eq('picker_id', pickerId);

        if (error) throw error;
        setIsFollowing(false);
      } else {
        const { error } = await supabase
          .from('favorite_pickers')
          .insert({
            client_id: user.id,
            picker_id: pickerId,
          });

        if (error) throw error;
        setIsFollowing(true);
      }

      if (onFollowChange) {
        onFollowChange();
      }
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  if (!user || profile?.user_type !== 'client') {
    return null;
  }

  return (
    <button
      onClick={handleToggleFollow}
      disabled={loading}
      className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all ${
        isFollowing
          ? 'bg-red-50 text-red-600 hover:bg-red-100'
          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
      } disabled:opacity-50 disabled:cursor-not-allowed`}
    >
      <Heart
        className={`w-4 h-4 ${isFollowing ? 'fill-current' : ''}`}
      />
      <span>{isFollowing ? 'Following' : 'Follow'}</span>
    </button>
  );
}
