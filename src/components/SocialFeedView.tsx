import { useState, useEffect } from 'react';
import { Camera, Heart, MessageCircle, Send, X, Plus, MapPin, Flame, ThumbsUp, Sparkles, Filter, ShoppingBag, Users, Share2, Facebook, Twitter, Check, Link as LinkIcon } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

interface Story {
  id: string;
  user_id: string;
  media_url: string;
  media_type: 'image' | 'video';
  thumbnail_url: string | null;
  caption: string | null;
  location: string | null;
  view_count: number;
  created_at: string;
  user: {
    full_name: string;
    avatar_url: string | null;
  };
}

interface FeedPost {
  id: string;
  user_id: string;
  content: string;
  images: string[] | null;
  videos: string[] | null;
  listing_id: string | null;
  created_at: string;
  user: {
    full_name: string;
    avatar_url: string | null;
    user_type: string;
  };
  like_count?: number;
  comment_count?: number;
  user_liked?: boolean;
}

interface Comment {
  id: string;
  user_id: string;
  content: string;
  created_at: string;
  user: {
    full_name: string;
    avatar_url: string | null;
  };
}

export default function SocialFeedView() {
  const { user, profile } = useAuth();
  const [stories, setStories] = useState<Story[]>([]);
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [selectedStory, setSelectedStory] = useState<Story | null>(null);
  const [storyIndex, setStoryIndex] = useState(0);
  const [showCreateStory, setShowCreateStory] = useState(false);
  const [showCreatePost, setShowCreatePost] = useState(false);
  const [newPostContent, setNewPostContent] = useState('');
  const [newPostMedia, setNewPostMedia] = useState<File[]>([]);
  const [selectedPost, setSelectedPost] = useState<FeedPost | null>(null);
  const [comments, setComments] = useState<Comment[]>([]);
  const [newComment, setNewComment] = useState('');
  const [loading, setLoading] = useState(true);
  const [storyMedia, setStoryMedia] = useState<File | null>(null);
  const [storyCaption, setStoryCaption] = useState('');
  const [storyPreview, setStoryPreview] = useState<string | null>(null);
  const [creatingStory, setCreatingStory] = useState(false);
  const [feedFilter, setFeedFilter] = useState<'all' | 'pickers' | 'collectors'>('all');
  const [showShareMenu, setShowShareMenu] = useState<string | null>(null);
  const [copiedPostId, setCopiedPostId] = useState<string | null>(null);

  useEffect(() => {
    loadStories();
    loadPosts();
  }, [feedFilter]);

  const loadStories = async () => {
    const { data, error } = await supabase
      .from('stories')
      .select(`
        *,
        user:profiles!user_id(full_name, avatar_url)
      `)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false });

    if (!error && data) {
      setStories(data);
    }
    setLoading(false);
  };

  const loadPosts = async () => {
    const { data, error } = await supabase
      .from('social_posts')
      .select(`
        *,
        user:profiles!user_id(full_name, avatar_url, user_type)
      `)
      .order('created_at', { ascending: false })
      .limit(20);

    if (!error && data) {
      let filteredData = data;
      if (feedFilter === 'pickers') {
        filteredData = data.filter(post => post.user.user_type === 'picker');
      } else if (feedFilter === 'collectors') {
        filteredData = data.filter(post => post.user.user_type === 'collector' || post.user.user_type === 'client');
      }

      if (user) {
        const postsWithCounts = await Promise.all(
          filteredData.map(async (post) => {
            const { count: likeCount } = await supabase
              .from('likes')
              .select('*', { count: 'exact', head: true })
              .eq('post_id', post.id);

            const { count: commentCount } = await supabase
              .from('comments')
              .select('*', { count: 'exact', head: true })
              .eq('post_id', post.id);

            const { data: userLike } = await supabase
              .from('likes')
              .select('id')
              .eq('post_id', post.id)
              .eq('user_id', user.id)
              .maybeSingle();

            return {
              ...post,
              like_count: likeCount || 0,
              comment_count: commentCount || 0,
              user_liked: !!userLike,
            };
          })
        );
        setPosts(postsWithCounts);
      } else {
        setPosts(filteredData.map(post => ({ ...post, like_count: 0, comment_count: 0, user_liked: false })));
      }
    }
  };

  const openStory = async (story: Story, index: number) => {
    setSelectedStory(story);
    setStoryIndex(index);

    if (user) {
      await supabase.from('story_views').insert({
        story_id: story.id,
        viewer_id: user.id,
      });
    }
  };

  const nextStory = () => {
    if (storyIndex < stories.length - 1) {
      const nextIndex = storyIndex + 1;
      openStory(stories[nextIndex], nextIndex);
    } else {
      setSelectedStory(null);
    }
  };

  const previousStory = () => {
    if (storyIndex > 0) {
      const prevIndex = storyIndex - 1;
      openStory(stories[prevIndex], prevIndex);
    }
  };

  const createPost = async () => {
    if (!user || !newPostContent.trim()) return;

    const imageUrls: string[] = [];
    const videoUrls: string[] = [];

    for (const file of newPostMedia) {
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.id}-${Date.now()}.${fileExt}`;
      const { data, error } = await supabase.storage
        .from('media')
        .upload(fileName, file);

      if (!error && data) {
        const { data: urlData } = supabase.storage.from('media').getPublicUrl(data.path);
        if (file.type.startsWith('video')) {
          videoUrls.push(urlData.publicUrl);
        } else {
          imageUrls.push(urlData.publicUrl);
        }
      }
    }

    const { error } = await supabase.from('social_posts').insert({
      user_id: user.id,
      content: newPostContent,
      images: imageUrls.length > 0 ? imageUrls : null,
      videos: videoUrls.length > 0 ? videoUrls : null,
    });

    if (!error) {
      setNewPostContent('');
      setNewPostMedia([]);
      setShowCreatePost(false);
      loadPosts();
    }
  };

  const toggleReaction = async (postId: string) => {
    if (!user) return;

    const post = posts.find((p) => p.id === postId);
    if (!post) return;

    if (post.user_liked) {
      await supabase
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', user.id);

      setPosts(
        posts.map((p) =>
          p.id === postId
            ? { ...p, user_liked: false, like_count: (p.like_count || 1) - 1 }
            : p
        )
      );
    } else {
      await supabase.from('likes').insert({
        post_id: postId,
        user_id: user.id,
      });

      setPosts(
        posts.map((p) =>
          p.id === postId
            ? { ...p, user_liked: true, like_count: (p.like_count || 0) + 1 }
            : p
        )
      );
    }
  };

  const loadComments = async (postId: string) => {
    const { data, error } = await supabase
      .from('comments')
      .select(`
        *,
        user:profiles!user_id(full_name, avatar_url)
      `)
      .eq('post_id', postId)
      .order('created_at', { ascending: true });

    if (!error && data) {
      setComments(data);
    }
  };

  const addComment = async (postId: string) => {
    if (!user || !newComment.trim()) return;

    const { error } = await supabase.from('comments').insert({
      post_id: postId,
      user_id: user.id,
      content: newComment,
    });

    if (!error) {
      setNewComment('');
      loadComments(postId);
      setPosts(
        posts.map((p) =>
          p.id === postId ? { ...p, comment_count: (p.comment_count || 0) + 1 } : p
        )
      );
    }
  };

  const openComments = (post: FeedPost) => {
    setSelectedPost(post);
    loadComments(post.id);
  };

  const handleStoryMediaChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setStoryMedia(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setStoryPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const createStory = async () => {
    if (!user || !storyMedia) return;

    setCreatingStory(true);

    try {
      const fileExt = storyMedia.name.split('.').pop();
      const fileName = `story-${user.id}-${Date.now()}.${fileExt}`;
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('media')
        .upload(fileName, storyMedia);

      if (uploadError) {
        alert('Failed to upload media. Please try again.');
        setCreatingStory(false);
        return;
      }

      const { data: urlData } = supabase.storage.from('media').getPublicUrl(uploadData.path);
      const mediaType = storyMedia.type.startsWith('video') ? 'video' : 'image';

      const { error: insertError } = await supabase.from('stories').insert({
        user_id: user.id,
        media_url: urlData.publicUrl,
        media_type: mediaType,
        caption: storyCaption || null,
      });

      if (insertError) {
        alert('Failed to create story. Please try again.');
        setCreatingStory(false);
        return;
      }

      setStoryMedia(null);
      setStoryCaption('');
      setStoryPreview(null);
      setShowCreateStory(false);
      loadStories();
    } catch (error) {

      alert('An error occurred. Please try again.');
    } finally {
      setCreatingStory(false);
    }
  };

  const handleSharePost = (postId: string, platform: string) => {
    const shareUrl = `${window.location.origin}?post=${postId}`;
    const post = posts.find(p => p.id === postId);
    const shareText = post ? `Check out this post from ${post.user.full_name}` : 'Check out this post';

    let url = '';

    switch (platform) {
      case 'facebook':
        url = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;
        break;
      case 'twitter':
        url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(shareUrl)}`;
        break;
      case 'whatsapp':
        url = `https://wa.me/?text=${encodeURIComponent(shareText + ' ' + shareUrl)}`;
        break;
    }

    if (url) {
      window.open(url, '_blank', 'width=600,height=400');
      setShowShareMenu(null);
    }
  };

  const copyPostLink = async (postId: string) => {
    const shareUrl = `${window.location.origin}?post=${postId}`;
    try {
      await navigator.clipboard.writeText(shareUrl);
      setCopiedPostId(postId);
      setTimeout(() => setCopiedPostId(null), 2000);
    } catch (error) {
      alert('Failed to copy link');
    }
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading social feed..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <h1 className="text-2xl font-bold">Social Feed</h1>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 bg-white rounded-lg border shadow-sm p-1">
            <button
              onClick={() => setFeedFilter('all')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                feedFilter === 'all'
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Users className="h-4 w-4" />
              All
            </button>
            <button
              onClick={() => setFeedFilter('pickers')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                feedFilter === 'pickers'
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <ShoppingBag className="h-4 w-4" />
              Pickers
            </button>
            <button
              onClick={() => setFeedFilter('collectors')}
              className={`flex items-center gap-2 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                feedFilter === 'collectors'
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Heart className="h-4 w-4" />
              Collectors
            </button>
          </div>
          <button
            onClick={() => setShowCreatePost(true)}
            className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
          >
            <Plus className="h-5 w-5" />
            Create Post
          </button>
        </div>
      </div>

      {feedFilter === 'pickers' && (
        <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl shadow-sm p-6 mb-6">
          <div className="flex items-center gap-3 mb-2">
            <ShoppingBag className="h-6 w-6" />
            <h2 className="text-xl font-bold">Discover Pickers</h2>
          </div>
          <p className="text-blue-100">
            Connect with pickers from around the world who can find and deliver unique souvenirs to you. Browse their posts to see what they're finding!
          </p>
        </div>
      )}

      {feedFilter === 'collectors' && (
        <div className="bg-gradient-to-r from-green-600 to-green-700 text-white rounded-xl shadow-sm p-6 mb-6">
          <div className="flex items-center gap-3 mb-2">
            <Heart className="h-6 w-6" />
            <h2 className="text-xl font-bold">Collector Community</h2>
          </div>
          <p className="text-green-100">
            See what fellow collectors are sharing and discover their souvenir collections from around the world.
          </p>
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm p-4 mb-6 overflow-x-auto">
        <div className="flex gap-4">
          {user && (
            <button
              onClick={() => setShowCreateStory(true)}
              className="flex-shrink-0 flex flex-col items-center gap-2"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-white">
                <Plus className="h-8 w-8" />
              </div>
              <span className="text-xs">Your Story</span>
            </button>
          )}

          {stories.map((story, index) => (
            <button
              key={story.id}
              onClick={() => openStory(story, index)}
              className="flex-shrink-0 flex flex-col items-center gap-2"
            >
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-orange-500 to-pink-500 p-0.5">
                <div className="w-full h-full rounded-full bg-white p-0.5">
                  <img
                    src={story.user.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${story.user_id}`}
                    alt={story.user.full_name}
                    className="w-full h-full rounded-full object-cover"
                  />
                </div>
              </div>
              <span className="text-xs max-w-[64px] truncate">{story.user.full_name}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-6">
        {posts.length === 0 ? (
          <div className="bg-white rounded-xl shadow-sm p-12 text-center">
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              {feedFilter === 'pickers' ? (
                <ShoppingBag className="h-8 w-8 text-gray-400" />
              ) : feedFilter === 'collectors' ? (
                <Heart className="h-8 w-8 text-gray-400" />
              ) : (
                <Users className="h-8 w-8 text-gray-400" />
              )}
            </div>
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No posts yet</h3>
            <p className="text-gray-600">
              {feedFilter === 'pickers'
                ? 'No picker posts to show. Try switching to "All" to see more content.'
                : feedFilter === 'collectors'
                ? 'No collector posts to show. Try switching to "All" to see more content.'
                : 'Be the first to share something with the community!'}
            </p>
          </div>
        ) : (
          posts.map((post) => (
            <div key={post.id} className="bg-white rounded-xl shadow-sm overflow-hidden">
            <div className="p-4 flex items-center gap-3">
              <img
                src={post.user.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${post.user_id}`}
                alt={post.user.full_name}
                className="w-10 h-10 rounded-full object-cover"
              />
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-semibold">{post.user.full_name}</span>
                  {post.user.user_type === 'picker' ? (
                    <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded-full flex items-center gap-1">
                      <ShoppingBag className="h-3 w-3" />
                      Picker
                    </span>
                  ) : (post.user.user_type === 'collector' || post.user.user_type === 'client') ? (
                    <span className="px-2 py-0.5 bg-green-100 text-green-700 text-xs font-medium rounded-full flex items-center gap-1">
                      <Heart className="h-3 w-3" />
                      Collector
                    </span>
                  ) : null}
                </div>
                <div className="text-sm text-gray-500">
                  {new Date(post.created_at).toLocaleDateString()}
                </div>
              </div>
            </div>

            {((post.images && post.images.length > 0) || (post.videos && post.videos.length > 0)) && (
              <div className="relative">
                {post.videos && post.videos.length > 0 ? (
                  <video
                    src={post.videos[0]}
                    className="w-full"
                    controls
                    preload="metadata"
                    playsInline
                  />
                ) : post.images && post.images.length > 0 ? (
                  <img src={post.images[0]} alt="" className="w-full" />
                ) : null}
              </div>
            )}

            <div className="p-4">
              <p className="mb-3">{post.content}</p>

              {post.listing_id && (
                <div className="mb-3 p-3 bg-gradient-to-r from-blue-50 to-green-50 rounded-lg border border-blue-200">
                  <div className="flex items-center gap-2 mb-2">
                    <ShoppingBag className="h-4 w-4 text-blue-600" />
                    <span className="text-sm font-semibold text-blue-900">Featured Listing</span>
                  </div>
                  <p className="text-xs text-gray-700 mb-2">This picker is showcasing an available souvenir</p>
                  <button
                    onClick={() => window.location.href = `/discover?listing=${post.listing_id}`}
                    className="text-xs bg-blue-600 text-white px-3 py-1.5 rounded-lg hover:bg-blue-700 font-medium"
                  >
                    View Listing Details
                  </button>
                </div>
              )}

              {post.user.user_type === 'picker' && !post.listing_id && (
                <div className="mb-3 p-3 bg-gradient-to-r from-amber-50 to-orange-50 rounded-lg border border-amber-200">
                  <div className="flex items-center gap-2">
                    <MapPin className="h-4 w-4 text-amber-600" />
                    <p className="text-xs text-amber-900">
                      <span className="font-semibold">{post.user.full_name}</span> is a picker who can help you find souvenirs
                    </p>
                  </div>
                </div>
              )}

              <div className="flex items-center justify-between text-sm text-gray-600 mb-3">
                <span>{post.like_count || 0} likes</span>
                <span>{post.comment_count || 0} comments</span>
              </div>

              <div className="flex items-center gap-4 pt-3 border-t">
                <button
                  onClick={() => toggleReaction(post.id)}
                  className={`flex items-center gap-2 ${
                    post.user_liked ? 'text-red-600' : 'text-gray-600'
                  } hover:text-red-600`}
                >
                  <Heart className={`h-5 w-5 ${post.user_liked ? 'fill-current' : ''}`} />
                  <span>Like</span>
                </button>

                <button
                  onClick={() => openComments(post)}
                  className="flex items-center gap-2 text-gray-600 hover:text-blue-600"
                >
                  <MessageCircle className="h-5 w-5" />
                  <span>Comment</span>
                </button>

                <div className="relative">
                  <button
                    onClick={() => setShowShareMenu(showShareMenu === post.id ? null : post.id)}
                    className="flex items-center gap-2 text-gray-600 hover:text-green-600"
                  >
                    <Share2 className="h-5 w-5" />
                    <span>Share</span>
                  </button>

                  {showShareMenu === post.id && (
                    <>
                      <div
                        className="fixed inset-0 z-10"
                        onClick={() => setShowShareMenu(null)}
                      />
                      <div className="absolute bottom-full left-0 mb-2 w-56 bg-white rounded-xl shadow-2xl border border-gray-200 z-20 overflow-hidden">
                        <div className="p-2">
                          <button
                            onClick={() => handleSharePost(post.id, 'facebook')}
                            className="w-full flex items-center gap-3 px-3 py-2 hover:bg-blue-50 rounded-lg transition-colors group"
                          >
                            <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center">
                              <Facebook className="w-4 h-4 text-white fill-current" />
                            </div>
                            <span className="font-medium text-gray-700 group-hover:text-blue-600">Facebook</span>
                          </button>

                          <button
                            onClick={() => handleSharePost(post.id, 'twitter')}
                            className="w-full flex items-center gap-3 px-3 py-2 hover:bg-sky-50 rounded-lg transition-colors group"
                          >
                            <div className="w-8 h-8 rounded-full bg-sky-500 flex items-center justify-center">
                              <Twitter className="w-4 h-4 text-white fill-current" />
                            </div>
                            <span className="font-medium text-gray-700 group-hover:text-sky-600">Twitter</span>
                          </button>

                          <button
                            onClick={() => handleSharePost(post.id, 'whatsapp')}
                            className="w-full flex items-center gap-3 px-3 py-2 hover:bg-green-50 rounded-lg transition-colors group"
                          >
                            <div className="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center">
                              <MessageCircle className="w-4 h-4 text-white" />
                            </div>
                            <span className="font-medium text-gray-700 group-hover:text-green-600">WhatsApp</span>
                          </button>

                          <div className="border-t my-2" />

                          <button
                            onClick={() => copyPostLink(post.id)}
                            className="w-full flex items-center gap-3 px-3 py-2 hover:bg-gray-50 rounded-lg transition-colors group"
                          >
                            <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center">
                              {copiedPostId === post.id ? (
                                <Check className="w-4 h-4 text-green-600" />
                              ) : (
                                <LinkIcon className="w-4 h-4 text-gray-600" />
                              )}
                            </div>
                            <span className={`font-medium ${copiedPostId === post.id ? 'text-green-600' : 'text-gray-700 group-hover:text-gray-900'}`}>
                              {copiedPostId === post.id ? 'Link copied!' : 'Copy link'}
                            </span>
                          </button>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
          ))
        )}
      </div>

      {selectedStory && (
        <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
          <button
            onClick={() => setSelectedStory(null)}
            className="absolute top-4 right-4 text-white z-10"
          >
            <X className="h-8 w-8" />
          </button>

          <button
            onClick={previousStory}
            disabled={storyIndex === 0}
            className="absolute left-4 text-white disabled:opacity-30"
          >
            <div className="text-4xl">‹</div>
          </button>

          <button
            onClick={nextStory}
            disabled={storyIndex === stories.length - 1}
            className="absolute right-4 text-white disabled:opacity-30"
          >
            <div className="text-4xl">›</div>
          </button>

          <div className="max-w-md w-full h-full flex flex-col">
            <div className="p-4 flex items-center gap-3">
              <img
                src={selectedStory.user.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${selectedStory.user_id}`}
                alt={selectedStory.user.full_name}
                className="w-10 h-10 rounded-full object-cover"
              />
              <div className="flex-1 text-white">
                <div className="font-semibold">{selectedStory.user.full_name}</div>
                <div className="text-sm opacity-75">
                  {new Date(selectedStory.created_at).toLocaleTimeString()}
                </div>
              </div>
            </div>

            <div className="flex-1 flex items-center justify-center">
              {selectedStory.media_type === 'video' ? (
                <video
                  src={selectedStory.media_url}
                  className="max-h-full"
                  controls
                  autoPlay
                  preload="metadata"
                  playsInline
                  crossOrigin="anonymous"
                />
              ) : (
                <img src={selectedStory.media_url} alt="" className="max-h-full" />
              )}
            </div>

            {selectedStory.caption && (
              <div className="p-4 text-white text-center">{selectedStory.caption}</div>
            )}
          </div>
        </div>
      )}

      {showCreatePost && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-lg w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold">Create Post</h2>
              <button onClick={() => setShowCreatePost(false)}>
                <X className="h-6 w-6" />
              </button>
            </div>

            <textarea
              value={newPostContent}
              onChange={(e) => setNewPostContent(e.target.value)}
              placeholder="What's on your mind?"
              className="w-full border rounded-lg p-3 mb-4 min-h-32"
            />

            <input
              type="file"
              accept="image/*,video/*"
              multiple
              onChange={(e) => setNewPostMedia(Array.from(e.target.files || []))}
              className="mb-4"
            />

            <button
              onClick={createPost}
              className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700"
            >
              Post
            </button>
          </div>
        </div>
      )}

      {selectedPost && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-lg w-full max-h-[80vh] flex flex-col">
            <div className="p-4 border-b flex items-center justify-between">
              <h2 className="text-xl font-bold">Comments</h2>
              <button onClick={() => setSelectedPost(null)}>
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {comments.map((comment) => (
                <div key={comment.id} className="flex gap-3">
                  <img
                    src={comment.user.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${comment.user_id}`}
                    alt={comment.user.full_name}
                    className="w-8 h-8 rounded-full object-cover"
                  />
                  <div className="flex-1">
                    <div className="bg-gray-100 rounded-lg p-3">
                      <div className="font-semibold text-sm">{comment.user.full_name}</div>
                      <div className="text-sm">{comment.content}</div>
                    </div>
                    <div className="text-xs text-gray-500 mt-1">
                      {new Date(comment.created_at).toLocaleString()}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="p-4 border-t">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newComment}
                  onChange={(e) => setNewComment(e.target.value)}
                  placeholder="Write a comment..."
                  className="flex-1 border rounded-lg px-3 py-2"
                  onKeyPress={(e) => e.key === 'Enter' && addComment(selectedPost.id)}
                />
                <button
                  onClick={() => addComment(selectedPost.id)}
                  className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
                >
                  <Send className="h-5 w-5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showCreateStory && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold">Create Story</h2>
              <button
                onClick={() => {
                  setShowCreateStory(false);
                  setStoryMedia(null);
                  setStoryCaption('');
                  setStoryPreview(null);
                }}
                disabled={creatingStory}
              >
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="space-y-4">
              {!storyPreview ? (
                <div>
                  <label className="block text-sm font-medium mb-2">Upload Photo or Video</label>
                  <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-blue-500 transition-colors cursor-pointer">
                    <input
                      type="file"
                      accept="image/*,video/*"
                      onChange={handleStoryMediaChange}
                      className="hidden"
                      id="story-upload"
                      disabled={creatingStory}
                    />
                    <label htmlFor="story-upload" className="cursor-pointer">
                      <Camera className="h-12 w-12 mx-auto text-gray-400 mb-2" />
                      <p className="text-sm text-gray-600">Click to upload image or video</p>
                      <p className="text-xs text-gray-400 mt-1">Story will expire in 24 hours</p>
                    </label>
                  </div>
                </div>
              ) : (
                <div>
                  <label className="block text-sm font-medium mb-2">Preview</label>
                  <div className="relative rounded-lg overflow-hidden bg-black">
                    {storyMedia?.type.startsWith('video') ? (
                      <video
                        src={storyPreview}
                        className="w-full max-h-64 object-contain"
                        controls
                        preload="metadata"
                        playsInline
                          />
                    ) : (
                      <img src={storyPreview} alt="Preview" className="w-full max-h-64 object-contain" />
                    )}
                    <button
                      onClick={() => {
                        setStoryMedia(null);
                        setStoryPreview(null);
                      }}
                      className="absolute top-2 right-2 bg-red-600 text-white p-2 rounded-full hover:bg-red-700"
                      disabled={creatingStory}
                    >
                      <X className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              )}

              {storyPreview && (
                <div>
                  <label className="block text-sm font-medium mb-2">Caption (optional)</label>
                  <textarea
                    value={storyCaption}
                    onChange={(e) => setStoryCaption(e.target.value)}
                    placeholder="Add a caption to your story..."
                    className="w-full border rounded-lg px-3 py-2 min-h-20"
                    disabled={creatingStory}
                  />
                </div>
              )}

              <button
                onClick={createStory}
                disabled={!storyMedia || creatingStory}
                className="w-full bg-gradient-to-r from-orange-500 to-pink-500 text-white py-3 rounded-lg hover:from-orange-600 hover:to-pink-600 disabled:opacity-50 disabled:cursor-not-allowed font-semibold flex items-center justify-center gap-2"
              >
                {creatingStory ? (
                  <>
                    <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                    Creating Story...
                  </>
                ) : (
                  <>
                    <Sparkles className="h-5 w-5" />
                    Share Story
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
