import { useState } from 'react';
import { ChevronLeft, ChevronRight, X, Package } from 'lucide-react';

type MediaGalleryProps = {
  images: string[];
  videos: string[];
  title: string;
  size?: 'compact' | 'large';
};

export function MediaGallery({ images, videos, title, size = 'compact' }: MediaGalleryProps) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [showLightbox, setShowLightbox] = useState(false);

  const allMedia = [...images, ...videos];
  const totalMedia = allMedia.length;
  const isLarge = size === 'large';
  const heightClass = isLarge ? 'h-80 sm:h-[420px] lg:h-[460px]' : 'h-48';
  const roundingClass = isLarge ? 'rounded-2xl' : 'rounded-t-2xl';

  if (totalMedia === 0) {
    return (
      <div className={`w-full ${heightClass} bg-gradient-to-br from-blue-50 via-white to-orange-50 flex items-center justify-center ${roundingClass}`}>
        <div className="text-center">
          <div className="w-14 h-14 mx-auto mb-2.5 rounded-2xl bg-white shadow-sm ring-1 ring-gray-100 flex items-center justify-center">
            <Package className="w-6 h-6 text-gray-300" strokeWidth={1.75} />
          </div>
          <div className="text-xs font-medium text-gray-400 tracking-wide">No media available</div>
        </div>
      </div>
    );
  }

  const currentMedia = allMedia[currentIndex];
  const isVideo = videos.includes(currentMedia);

  const nextMedia = () => {
    setCurrentIndex((prev) => (prev + 1) % totalMedia);
  };

  const prevMedia = () => {
    setCurrentIndex((prev) => (prev - 1 + totalMedia) % totalMedia);
  };

  return (
    <>
      <div className="relative group">
        {isVideo ? (
          <video
            src={currentMedia}
            className={`w-full ${heightClass} object-cover ${roundingClass} cursor-pointer`}
            onClick={() => setShowLightbox(true)}
            controls={false}
            playsInline
            muted
            loop
            preload="metadata"
          />
        ) : (
          <img
            src={currentMedia}
            alt={title}
            className={`w-full ${heightClass} object-cover ${roundingClass} cursor-pointer`}
            onClick={() => setShowLightbox(true)}
          />
        )}

        {totalMedia > 1 && (
          <>
            <button
              onClick={(e) => {
                e.stopPropagation();
                prevMedia();
              }}
              className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity hover:bg-black/70"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                nextMedia();
              }}
              className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity hover:bg-black/70"
            >
              <ChevronRight className="w-5 h-5" />
            </button>

            <div className="absolute bottom-2 left-1/2 -translate-x-1/2 bg-black/50 text-white px-3 py-1 rounded-full text-xs">
              {currentIndex + 1} / {totalMedia}
            </div>
          </>
        )}

        {isVideo && (
          <div className="absolute top-2 right-2 bg-black/50 text-white px-2 py-1 rounded text-xs">
            Video
          </div>
        )}
      </div>

      {isLarge && totalMedia > 1 && (
        <div className="flex gap-2 mt-3 overflow-x-auto pb-1">
          {allMedia.map((media, index) => {
            const isThumbVideo = videos.includes(media);
            return (
              <button
                key={index}
                onClick={() => setCurrentIndex(index)}
                className={`flex-shrink-0 w-16 h-16 rounded-lg overflow-hidden ring-2 transition-all ${
                  index === currentIndex ? 'ring-blue-500' : 'ring-transparent hover:ring-gray-300'
                }`}
              >
                {isThumbVideo ? (
                  <video src={media} className="w-full h-full object-cover" muted />
                ) : (
                  <img src={media} alt="" className="w-full h-full object-cover" />
                )}
              </button>
            );
          })}
        </div>
      )}

      {showLightbox && (
        <div
          className="fixed inset-0 bg-black/90 z-50 flex items-center justify-center p-4"
          onClick={() => setShowLightbox(false)}
        >
          <button
            onClick={() => setShowLightbox(false)}
            className="absolute top-4 right-4 text-white p-2 hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-6 h-6" />
          </button>

          {totalMedia > 1 && (
            <>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  prevMedia();
                }}
                className="absolute left-4 top-1/2 -translate-y-1/2 bg-white/10 text-white p-3 rounded-full hover:bg-white/20 transition-colors"
              >
                <ChevronLeft className="w-6 h-6" />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  nextMedia();
                }}
                className="absolute right-4 top-1/2 -translate-y-1/2 bg-white/10 text-white p-3 rounded-full hover:bg-white/20 transition-colors"
              >
                <ChevronRight className="w-6 h-6" />
              </button>
            </>
          )}

          <div className="max-w-5xl max-h-[90vh] w-full" onClick={(e) => e.stopPropagation()}>
            {isVideo ? (
              <video
                src={currentMedia}
                className="w-full h-auto max-h-[90vh] object-contain"
                controls
                autoPlay
                playsInline
                preload="auto"
                  />
            ) : (
              <img
                src={currentMedia}
                alt={title}
                className="w-full h-auto max-h-[90vh] object-contain"
              />
            )}
          </div>

          <div className="absolute bottom-4 left-1/2 -translate-x-1/2 bg-white/10 text-white px-4 py-2 rounded-full text-sm">
            {currentIndex + 1} / {totalMedia}
          </div>
        </div>
      )}
    </>
  );
}
