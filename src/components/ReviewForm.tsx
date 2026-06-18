import { useState } from 'react';
import { Star, X, Upload, Image as ImageIcon, Video as VideoIcon } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { uploadImage, uploadVideo } from '../lib/storage';
import { useAuth } from '../contexts/AuthContext';

type ReviewFormProps = {
  pickerId: string;
  requestId?: string;
  orderId?: string;
  listingId?: string;
  onClose: () => void;
  onReviewSubmitted: () => void;
};

export function ReviewForm({ pickerId, requestId, orderId, listingId, onClose, onReviewSubmitted }: ReviewFormProps) {
  const { profile, user } = useAuth();
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState('');
  const [hoveredRating, setHoveredRating] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const [uploadedImages, setUploadedImages] = useState<string[]>([]);
  const [uploadedVideos, setUploadedVideos] = useState<string[]>([]);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    setError('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadImage(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setUploadedImages([...uploadedImages, ...urls]);
    } catch (error: any) {
      setError(error.message || 'Failed to upload images');
    } finally {
      setUploading(false);
    }
  };

  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    setError('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadVideo(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setUploadedVideos([...uploadedVideos, ...urls]);
    } catch (error: any) {
      setError(error.message || 'Failed to upload videos');
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profile) return;

    setSubmitting(true);
    setError('');

    try {
      const reviewData: any = {
        picker_id: pickerId,
        client_id: profile.id,
        rating,
        comment: comment.trim() || null,
        images: uploadedImages,
        videos: uploadedVideos,
      };

      if (orderId) reviewData.order_id = orderId;
      if (requestId) reviewData.request_id = requestId;
      if (listingId) reviewData.listing_id = listingId;

      const { error: reviewError } = await supabase.from('reviews').insert(reviewData);

      if (reviewError) throw reviewError;

      const { data: pickerProfileData } = await supabase
        .from('picker_profiles')
        .select('id')
        .eq('user_id', pickerId)
        .single();

      if (pickerProfileData) {
        const { data: reviews, error: fetchError } = await supabase
          .from('reviews')
          .select('rating')
          .eq('picker_id', pickerId);

        if (fetchError) throw fetchError;

        if (reviews && reviews.length > 0) {
          const avgRating = reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;

          await supabase
            .from('picker_profiles')
            .update({
              rating: avgRating,
              total_reviews: reviews.length,
            })
            .eq('id', pickerProfileData.id);
        }
      }

      onReviewSubmitted();
    } catch (err: any) {
      setError(err.message || 'Failed to submit review');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl max-w-lg w-full p-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Leave a Review</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-3">
              Rating
            </label>
            <div className="flex gap-2">
              {[1, 2, 3, 4, 5].map((star) => (
                <button
                  key={star}
                  type="button"
                  onClick={() => setRating(star)}
                  onMouseEnter={() => setHoveredRating(star)}
                  onMouseLeave={() => setHoveredRating(0)}
                  className="p-1 transition-transform hover:scale-110"
                >
                  <Star
                    className={`w-10 h-10 ${
                      star <= (hoveredRating || rating)
                        ? 'fill-yellow-400 text-yellow-400'
                        : 'text-gray-300'
                    }`}
                  />
                </button>
              ))}
            </div>
            <p className="text-sm text-gray-500 mt-2">
              {rating === 1 && 'Poor'}
              {rating === 2 && 'Fair'}
              {rating === 3 && 'Good'}
              {rating === 4 && 'Very Good'}
              {rating === 5 && 'Excellent'}
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Comment (optional)
            </label>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              rows={4}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Share your experience with this picker..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <ImageIcon className="w-4 h-4 inline mr-1" />
              Add Photos (optional)
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
              <input
                type="file"
                accept="image/jpeg,image/jpg,image/png,image/webp"
                multiple
                onChange={handleImageUpload}
                className="hidden"
                id="review-image-upload"
                disabled={uploading}
              />
              <label
                htmlFor="review-image-upload"
                className="flex flex-col items-center justify-center cursor-pointer"
              >
                <Upload className="w-6 h-6 text-gray-400 mb-1" />
                <span className="text-sm text-gray-600">Click to upload photos</span>
              </label>
            </div>

            {uploadedImages.length > 0 && (
              <div className="grid grid-cols-3 gap-2 mt-3">
                {uploadedImages.map((url, index) => (
                  <div key={index} className="relative group">
                    <img
                      src={url}
                      alt={`Review ${index + 1}`}
                      className="w-full h-20 object-cover rounded-lg"
                    />
                    <button
                      type="button"
                      onClick={() => removeImage(url)}
                      className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <VideoIcon className="w-4 h-4 inline mr-1" />
              Add Video (optional)
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
              <input
                type="file"
                accept="video/mp4,video/webm,video/quicktime"
                onChange={handleVideoUpload}
                className="hidden"
                id="review-video-upload"
                disabled={uploading}
              />
              <label
                htmlFor="review-video-upload"
                className="flex flex-col items-center justify-center cursor-pointer"
              >
                <Upload className="w-6 h-6 text-gray-400 mb-1" />
                <span className="text-sm text-gray-600">Click to upload video</span>
              </label>
            </div>

            {uploadedVideos.length > 0 && (
              <div className="mt-3">
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
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {uploading && (
            <div className="bg-blue-50 text-blue-600 p-3 rounded-lg text-sm">
              Uploading media...
            </div>
          )}

          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
              {error}
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {submitting ? 'Submitting...' : 'Submit Review'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
