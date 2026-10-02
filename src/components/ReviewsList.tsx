import { useState, useEffect } from 'react';
import { Star, User, ThumbsUp, ThumbsDown, CheckCircle, Image as ImageIcon, Video as VideoIcon } from 'lucide-react';
import { supabase, Review, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

type ReviewWithProfile = Review & {
  client?: Profile;
  images?: string[];
  videos?: string[];
  verified_purchase?: boolean;
  helpful_count?: number;
  unhelpful_count?: number;
};

type ReviewsListProps = {
  pickerId: string;
};

export function ReviewsList({ pickerId }: ReviewsListProps) {
  const { user } = useAuth();
  const [reviews, setReviews] = useState<ReviewWithProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [userVotes, setUserVotes] = useState<Record<string, 'helpful' | 'unhelpful'>>({});
  const [selectedImage, setSelectedImage] = useState<string | null>(null);

  useEffect(() => {
    loadReviews();
    if (user) {
      loadUserVotes();
    }
  }, [pickerId, user]);

  const loadReviews = async () => {
    try {
      const { data, error } = await supabase
        .from('reviews')
        .select(`
          *,
          client:profiles!reviews_client_id_fkey(*)
        `)
        .eq('picker_id', pickerId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setReviews(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const loadUserVotes = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('review_votes')
        .select('review_id, vote_type')
        .eq('user_id', user.id);

      if (error) throw error;

      const votesMap: Record<string, 'helpful' | 'unhelpful'> = {};
      data?.forEach(vote => {
        votesMap[vote.review_id] = vote.vote_type;
      });
      setUserVotes(votesMap);
    } catch (error) {

    }
  };

  const handleVote = async (reviewId: string, voteType: 'helpful' | 'unhelpful') => {
    if (!user) return;

    try {
      const currentVote = userVotes[reviewId];

      if (currentVote === voteType) {
        await supabase
          .from('review_votes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', user.id);

        const { [reviewId]: _, ...rest } = userVotes;
        setUserVotes(rest);
      } else {
        await supabase
          .from('review_votes')
          .upsert({
            review_id: reviewId,
            user_id: user.id,
            vote_type: voteType,
          });

        setUserVotes({ ...userVotes, [reviewId]: voteType });
      }

      loadReviews();
    } catch (error) {

    }
  };

  if (loading) {
    return (
      <div className="py-4">
        <SouvenirLoader message="Loading reviews..." />
      </div>
    );
  }

  if (reviews.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        No reviews yet
      </div>
    );
  }

  return (
    <>
      <div className="space-y-4">
        {reviews.map((review) => (
          <div
            key={review.id}
            className="bg-white border border-gray-200 rounded-xl p-6 hover:shadow-md transition-shadow"
          >
            <div className="flex items-start gap-4">
              <div className="flex-shrink-0">
                {review.client?.avatar_url ? (
                  <img
                    src={review.client.avatar_url}
                    alt={review.client.full_name}
                    className="w-12 h-12 rounded-full object-cover"
                  />
                ) : (
                  <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center">
                    <User className="w-6 h-6 text-gray-400" />
                  </div>
                )}
              </div>

              <div className="flex-1">
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <div className="flex items-center gap-2">
                      <h4 className="font-semibold text-gray-900">
                        {review.client?.full_name || 'Anonymous'}
                      </h4>
                      {review.verified_purchase && (
                        <span className="inline-flex items-center gap-1 text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full">
                          <CheckCircle className="w-3 h-3" />
                          Verified Purchase
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-500">
                      {new Date(review.created_at).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric',
                      })}
                    </p>
                  </div>
                  <div className="flex items-center gap-1">
                    {Array.from({ length: 5 }).map((_, i) => (
                      <Star
                        key={i}
                        className={`w-5 h-5 ${
                          i < review.rating
                            ? 'fill-yellow-400 text-yellow-400'
                            : 'text-gray-300'
                        }`}
                      />
                    ))}
                  </div>
                </div>

                {review.comment && (
                  <p className="text-gray-700 leading-relaxed mb-4">{review.comment}</p>
                )}

                {review.images && review.images.length > 0 && (
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2 text-sm text-gray-600">
                      <ImageIcon className="w-4 h-4" />
                      <span>Photos</span>
                    </div>
                    <div className="grid grid-cols-4 gap-2">
                      {review.images.map((image, index) => (
                        <img
                          key={index}
                          src={image}
                          alt={`Review ${index + 1}`}
                          className="w-full h-24 object-cover rounded-lg cursor-pointer hover:opacity-75 transition-opacity"
                          onClick={() => setSelectedImage(image)}
                        />
                      ))}
                    </div>
                  </div>
                )}

                {review.videos && review.videos.length > 0 && (
                  <div className="mb-4">
                    <div className="flex items-center gap-2 mb-2 text-sm text-gray-600">
                      <VideoIcon className="w-4 h-4" />
                      <span>Video</span>
                    </div>
                    {review.videos.map((video, index) => (
                      <video
                        key={index}
                        src={video}
                        className="w-full max-h-64 rounded-lg"
                        controls
                        preload="metadata"
                        playsInline
                      />
                    ))}
                  </div>
                )}

                <div className="flex items-center gap-4 pt-3 border-t">
                  <button
                    onClick={() => handleVote(review.id, 'helpful')}
                    className={`flex items-center gap-2 px-3 py-1.5 rounded-lg transition-colors ${
                      userVotes[review.id] === 'helpful'
                        ? 'bg-green-100 text-green-700'
                        : 'hover:bg-gray-100 text-gray-600'
                    }`}
                  >
                    <ThumbsUp className="w-4 h-4" />
                    <span className="text-sm font-medium">
                      Helpful {review.helpful_count ? `(${review.helpful_count})` : ''}
                    </span>
                  </button>

                  <button
                    onClick={() => handleVote(review.id, 'unhelpful')}
                    className={`flex items-center gap-2 px-3 py-1.5 rounded-lg transition-colors ${
                      userVotes[review.id] === 'unhelpful'
                        ? 'bg-red-100 text-red-700'
                        : 'hover:bg-gray-100 text-gray-600'
                    }`}
                  >
                    <ThumbsDown className="w-4 h-4" />
                    <span className="text-sm font-medium">
                      Not Helpful {review.unhelpful_count ? `(${review.unhelpful_count})` : ''}
                    </span>
                  </button>
                </div>

                {review.response && (
                  <div className="mt-4 bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center">
                        <User className="w-4 h-4 text-white" />
                      </div>
                      <div>
                        <p className="font-semibold text-gray-900">Picker Response</p>
                        <p className="text-xs text-gray-500">
                          {review.response_at && new Date(review.response_at).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                    <p className="text-gray-700">{review.response}</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {selectedImage && (
        <div
          className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedImage(null)}
        >
          <img
            src={selectedImage}
            alt="Review"
            className="max-w-full max-h-full object-contain"
          />
        </div>
      )}
    </>
  );
}
