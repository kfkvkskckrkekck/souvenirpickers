import { useState } from 'react';
import { Share2, Facebook, Twitter, Link as LinkIcon, Mail, MessageCircle, Check, Instagram, Video } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type SocialShareButtonProps = {
  listingId: string;
  title: string;
  description: string;
};

export function SocialShareButton({ listingId, title, description }: SocialShareButtonProps) {
  const { user } = useAuth();
  const [showMenu, setShowMenu] = useState(false);
  const [copied, setCopied] = useState(false);

  const shareUrl = `${window.location.origin}?listing=${listingId}`;
  const shareText = `Check out this unique souvenir: ${title}`;

  const recordShare = async (platform: string) => {
    try {
      await supabase.from('listing_shares').insert({
        listing_id: listingId,
        user_id: user?.id || null,
        platform,
      });
    } catch (error) {

    }
  };

  const handleShare = (platform: string) => {
    let url = '';

    switch (platform) {
      case 'facebook':
        url = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;
        break;
      case 'twitter':
        url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(shareUrl)}`;
        break;
      case 'instagram':
        copyToClipboard();
        alert('Link copied! Open Instagram app and paste the link in your story or post.');
        recordShare('instagram');
        setShowMenu(false);
        return;
      case 'tiktok':
        copyToClipboard();
        alert('Link copied! Open TikTok app and paste the link in your video description.');
        recordShare('tiktok');
        setShowMenu(false);
        return;
      case 'whatsapp':
        url = `https://wa.me/?text=${encodeURIComponent(shareText + ' ' + shareUrl)}`;
        break;
      case 'email':
        url = `mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(shareText + '\n\n' + shareUrl)}`;
        break;
    }

    if (url) {
      window.open(url, '_blank', 'width=600,height=400');
      recordShare(platform);
      setShowMenu(false);
    }
  };

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(shareUrl);
      setCopied(true);
      recordShare('link');
      setTimeout(() => setCopied(false), 2000);
    } catch (error) {

    }
  };

  return (
    <div className="relative">
      <button
        onClick={() => setShowMenu(!showMenu)}
        className="flex items-center gap-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors text-gray-700 font-medium"
      >
        <Share2 className="w-4 h-4" />
        <span>Share</span>
      </button>

      {showMenu && (
        <>
          <div
            className="fixed inset-0 z-10"
            onClick={() => setShowMenu(false)}
          />
          <div className="absolute right-0 mt-2 w-64 bg-white rounded-xl shadow-2xl border border-gray-200 z-20 overflow-hidden">
            <div className="p-3 border-b bg-gray-50">
              <h3 className="font-semibold text-gray-900">Share this listing</h3>
            </div>
            <div className="p-2">
              <button
                onClick={() => handleShare('facebook')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-blue-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center">
                  <Facebook className="w-4 h-4 text-white fill-current" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-blue-600">Facebook</span>
              </button>

              <button
                onClick={() => handleShare('twitter')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-sky-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-sky-500 flex items-center justify-center">
                  <Twitter className="w-4 h-4 text-white fill-current" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-sky-600">Twitter</span>
              </button>

              <button
                onClick={() => handleShare('instagram')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-pink-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-600 to-pink-500 flex items-center justify-center">
                  <Instagram className="w-4 h-4 text-white" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-pink-600">Instagram</span>
              </button>

              <button
                onClick={() => handleShare('tiktok')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-gray-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-black flex items-center justify-center">
                  <Video className="w-4 h-4 text-white" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-gray-900">TikTok</span>
              </button>

              <button
                onClick={() => handleShare('whatsapp')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-green-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center">
                  <MessageCircle className="w-4 h-4 text-white" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-green-600">WhatsApp</span>
              </button>

              <button
                onClick={() => handleShare('email')}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-gray-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center">
                  <Mail className="w-4 h-4 text-white" />
                </div>
                <span className="font-medium text-gray-700 group-hover:text-gray-900">Email</span>
              </button>

              <div className="border-t my-2" />

              <button
                onClick={copyToClipboard}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-gray-50 rounded-lg transition-colors group"
              >
                <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center">
                  {copied ? (
                    <Check className="w-4 h-4 text-green-600" />
                  ) : (
                    <LinkIcon className="w-4 h-4 text-gray-600" />
                  )}
                </div>
                <span className={`font-medium ${copied ? 'text-green-600' : 'text-gray-700 group-hover:text-gray-900'}`}>
                  {copied ? 'Link copied!' : 'Copy link'}
                </span>
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
