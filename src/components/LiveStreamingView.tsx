import { useState, useEffect, useRef } from 'react';
import { Video, Users, MessageCircle, Send, ShoppingBag, X, Radio, MapPin, Trash2, Info } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

interface LiveStream {
  id: string;
  picker_id: string;
  title: string;
  description: string | null;
  thumbnail_url: string | null;
  location: string | null;
  viewer_count: number;
  started_at: string;
  picker: {
    full_name: string;
    avatar_url: string | null;
  };
}

interface ChatMessage {
  id: string;
  user_id: string;
  message: string;
  created_at: string;
  user: {
    full_name: string;
    avatar_url: string | null;
  };
}

interface ItemRequest {
  id: string;
  requester_id: string;
  item_name: string;
  description: string | null;
  max_price: number | null;
  status: string;
  created_at: string;
  requester: {
    full_name: string;
  };
}

export default function LiveStreamingView() {
  const { user, profile } = useAuth();
  const [streams, setStreams] = useState<LiveStream[]>([]);
  const [selectedStream, setSelectedStream] = useState<LiveStream | null>(null);
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [itemRequests, setItemRequests] = useState<ItemRequest[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [showRequestItem, setShowRequestItem] = useState(false);
  const [requestItemName, setRequestItemName] = useState('');
  const [requestDescription, setRequestDescription] = useState('');
  const [requestMaxPrice, setRequestMaxPrice] = useState('');
  const [showStartStream, setShowStartStream] = useState(false);
  const [streamTitle, setStreamTitle] = useState('');
  const [streamDescription, setStreamDescription] = useState('');
  const [loading, setLoading] = useState(true);
  const chatContainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    loadStreams();
    const interval = setInterval(() => {
      if (document.visibilityState === 'visible') loadStreams();
    }, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (selectedStream) {
      loadChatMessages(selectedStream.id);
      loadItemRequests(selectedStream.id);
      joinStream(selectedStream.id);

      const channel = supabase
        .channel(`stream:${selectedStream.id}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'stream_chat_messages',
            filter: `stream_id=eq.${selectedStream.id}`,
          },
          (payload) => {
            loadChatMessages(selectedStream.id);
          }
        )
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'stream_item_requests',
            filter: `stream_id=eq.${selectedStream.id}`,
          },
          () => {
            loadItemRequests(selectedStream.id);
          }
        )
        .subscribe();

      return () => {
        leaveStream(selectedStream.id);
        channel.unsubscribe();
      };
    }
  }, [selectedStream]);

  useEffect(() => {
    if (chatContainerRef.current) {
      chatContainerRef.current.scrollTop = chatContainerRef.current.scrollHeight;
    }
  }, [chatMessages]);

  const loadStreams = async () => {
    const { data, error } = await supabase
      .from('live_streams')
      .select(`
        *,
        picker:profiles!picker_id(full_name, avatar_url)
      `)
      .eq('status', 'live')
      .order('started_at', { ascending: false });

    if (!error && data) {
      setStreams(data);
    }
    setLoading(false);
  };

  const loadChatMessages = async (streamId: string) => {
    const { data, error } = await supabase
      .from('stream_chat_messages')
      .select(`
        *,
        user:profiles!user_id(full_name, avatar_url)
      `)
      .eq('stream_id', streamId)
      .order('created_at', { ascending: true })
      .limit(100);

    if (!error && data) {
      setChatMessages(data);
    }
  };

  const loadItemRequests = async (streamId: string) => {
    const { data, error } = await supabase
      .from('stream_item_requests')
      .select(`
        *,
        requester:profiles!requester_id(full_name)
      `)
      .eq('stream_id', streamId)
      .order('created_at', { ascending: false });

    if (!error && data) {
      setItemRequests(data);
    }
  };

  const joinStream = async (streamId: string) => {
    if (!user) return;

    await supabase.from('stream_viewers').upsert({
      stream_id: streamId,
      viewer_id: user.id,
      is_active: true,
    });
  };

  const leaveStream = async (streamId: string) => {
    if (!user) return;

    await supabase
      .from('stream_viewers')
      .update({ is_active: false, left_at: new Date().toISOString() })
      .eq('stream_id', streamId)
      .eq('viewer_id', user.id);
  };

  const sendMessage = async () => {
    if (!user || !selectedStream || !newMessage.trim()) return;

    await supabase.from('stream_chat_messages').insert({
      stream_id: selectedStream.id,
      user_id: user.id,
      message: newMessage,
    });

    setNewMessage('');
  };

  const requestItem = async () => {
    if (!user || !selectedStream || !requestItemName.trim()) return;

    await supabase.from('stream_item_requests').insert({
      stream_id: selectedStream.id,
      requester_id: user.id,
      item_name: requestItemName,
      description: requestDescription,
      max_price: requestMaxPrice ? parseFloat(requestMaxPrice) : null,
    });

    setRequestItemName('');
    setRequestDescription('');
    setRequestMaxPrice('');
    setShowRequestItem(false);
  };

  const updateRequestStatus = async (requestId: string, status: string) => {
    await supabase
      .from('stream_item_requests')
      .update({ status })
      .eq('id', requestId);

    loadItemRequests(selectedStream!.id);
  };

  const startStream = async () => {
    if (!user || !streamTitle.trim()) return;

    const { data, error } = await supabase
      .from('live_streams')
      .insert({
        picker_id: user.id,
        title: streamTitle,
        description: streamDescription,
      })
      .select()
      .single();

    if (!error && data) {
      setStreamTitle('');
      setStreamDescription('');
      setShowStartStream(false);
      loadStreams();
    }
  };

  const endStream = async (streamId: string) => {
    await supabase
      .from('live_streams')
      .update({
        status: 'ended',
        ended_at: new Date().toISOString(),
      })
      .eq('id', streamId);

    setSelectedStream(null);
    loadStreams();
  };

  const deleteStream = async (streamId: string) => {
    if (!confirm('Are you sure you want to delete this stream? This action cannot be undone.')) {
      return;
    }

    const { error } = await supabase
      .from('live_streams')
      .delete()
      .eq('id', streamId);

    if (!error) {
      setSelectedStream(null);
      loadStreams();
    } else {
      alert('Failed to delete stream. Please try again.');
    }
  };

  if (loading) {
    return (
      <div className="max-w-6xl mx-auto px-4 py-8">
        <SouvenirLoader message="Loading live streams..." />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Radio className="h-8 w-8 text-red-500 animate-pulse" />
            Live Streams
          </h1>
          <p className="text-gray-600">
            {profile?.user_type === 'picker'
              ? 'Go live while shopping and connect with collectors in real-time'
              : 'Watch pickers shop live and request items in real-time'}
          </p>
        </div>
        {profile?.user_type === 'picker' && (
          <button
            onClick={() => setShowStartStream(true)}
            className="flex items-center gap-2 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700"
          >
            <Video className="h-5 w-5" />
            Go Live
          </button>
        )}
      </div>

      <div className="mb-8 bg-gradient-to-r from-red-50 to-orange-50 rounded-2xl p-6 border-2 border-red-200">
        <div className="flex items-start gap-4">
          <div className="bg-red-600 p-3 rounded-lg flex-shrink-0">
            <Info className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-gray-900 mb-3">
              {profile?.user_type === 'picker'
                ? 'About Live Streaming (Coming Soon)'
                : 'Live Shopping Experience'}
            </h3>
            {profile?.user_type === 'picker' ? (
              <div className="space-y-3 text-gray-700">
                <p className="flex items-start gap-2">
                  <Video className="w-5 h-5 text-red-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Stream your shopping trips:</strong> Click "Go Live" to start streaming while you shop. Collectors can watch in real-time and request specific items they want you to find.
                  </span>
                </p>
                <p className="flex items-start gap-2">
                  <MessageCircle className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Interactive chat:</strong> Engage with viewers through live chat, answer questions about products, and receive instant item requests that you can fulfill during your stream.
                  </span>
                </p>
                <p className="flex items-start gap-2">
                  <Trash2 className="w-5 h-5 text-orange-600 mt-0.5 flex-shrink-0" />
                  <span>
                    <strong>Manage your streams:</strong> End or delete streams at any time. Use the trash icon on stream cards to permanently remove old streams.
                  </span>
                </p>
                <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <p className="text-sm text-yellow-800 mb-2">
                    <strong>Note:</strong> Full video streaming requires WebRTC or a streaming service integration. The current implementation provides the framework - video streaming will be enabled in a future update.
                  </p>
                  <a
                    href="/LIVE_STREAMING_INTEGRATION.md"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm text-blue-600 hover:text-blue-800 underline font-medium"
                  >
                    View Integration Guide →
                  </a>
                </div>
              </div>
            ) : (
              <div className="space-y-3 text-gray-700">
                <p>
                  Watch pickers shop live at markets and stores around the world. Request items in real-time during streams, chat with pickers, and get exactly what you're looking for.
                </p>
                <p className="flex items-start gap-2">
                  <ShoppingBag className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
                  <span>
                    Click "Request Item" during any stream to ask pickers to find specific items for you with your desired price range.
                  </span>
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      {streams.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center">
          <Video className="h-16 w-16 mx-auto text-gray-400 mb-4" />
          <h3 className="text-xl font-semibold mb-2">No Live Streams</h3>
          <p className="text-gray-600">Check back later for live shopping experiences</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {streams.map((stream) => (
            <div
              key={stream.id}
              className="bg-white rounded-xl shadow-sm overflow-hidden hover:shadow-lg transition-shadow"
            >
              <div
                onClick={() => setSelectedStream(stream)}
                className="relative aspect-video bg-gray-900 cursor-pointer"
              >
                {stream.thumbnail_url ? (
                  <img src={stream.thumbnail_url} alt={stream.title} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Video className="h-16 w-16 text-gray-600" />
                  </div>
                )}
                <div className="absolute top-2 left-2 bg-red-600 text-white px-2 py-1 rounded flex items-center gap-1 text-sm font-semibold">
                  <div className="w-2 h-2 bg-white rounded-full animate-pulse"></div>
                  LIVE
                </div>
                <div className="absolute bottom-2 right-2 bg-black bg-opacity-75 text-white px-2 py-1 rounded flex items-center gap-1 text-sm">
                  <Users className="h-4 w-4" />
                  {stream.viewer_count}
                </div>
              </div>
              <div className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2 flex-1">
                    <img
                      src={stream.picker.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${stream.picker_id}`}
                      alt={stream.picker.full_name}
                      className="w-8 h-8 rounded-full object-cover"
                    />
                    <span className="font-semibold">{stream.picker.full_name}</span>
                  </div>
                  {user?.id === stream.picker_id && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteStream(stream.id);
                      }}
                      className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      title="Delete stream"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  )}
                </div>
                <h3 className="font-bold mb-1">{stream.title}</h3>
                {stream.description && (
                  <p className="text-sm text-gray-600 line-clamp-2">{stream.description}</p>
                )}
                {stream.location && (
                  <div className="flex items-center gap-1 text-sm text-gray-600 mt-2">
                    <MapPin className="h-4 w-4" />
                    {stream.location}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedStream && (
        <div className="fixed inset-0 bg-black z-50 flex">
          <div className="flex-1 flex flex-col">
            <div className="bg-gray-900 p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <img
                  src={selectedStream.picker.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${selectedStream.picker_id}`}
                  alt={selectedStream.picker.full_name}
                  className="w-10 h-10 rounded-full object-cover"
                />
                <div className="text-white">
                  <div className="font-semibold">{selectedStream.picker.full_name}</div>
                  <div className="text-sm text-gray-300">{selectedStream.title}</div>
                </div>
                <div className="ml-4 bg-red-600 text-white px-3 py-1 rounded flex items-center gap-1 text-sm font-semibold">
                  <div className="w-2 h-2 bg-white rounded-full animate-pulse"></div>
                  LIVE
                </div>
              </div>
              <button onClick={() => setSelectedStream(null)} className="text-white">
                <X className="h-8 w-8" />
              </button>
            </div>

            <div className="flex-1 bg-gray-900 flex items-center justify-center">
              <div className="text-white text-center">
                <Video className="h-24 w-24 mx-auto mb-4 text-gray-600" />
                <p className="text-lg">Video streaming integration required</p>
                <p className="text-sm text-gray-400">Connect WebRTC or streaming service</p>
              </div>
            </div>

            {user?.id === selectedStream.picker_id && (
              <div className="bg-gray-900 p-4">
                <button
                  onClick={() => endStream(selectedStream.id)}
                  className="w-full bg-red-600 text-white py-3 rounded-lg hover:bg-red-700"
                >
                  End Stream
                </button>
              </div>
            )}
          </div>

          <div className="w-96 bg-white flex flex-col">
            <div className="flex border-b">
              <button className="flex-1 py-3 flex items-center justify-center gap-2 border-b-2 border-blue-600 text-blue-600">
                <MessageCircle className="h-5 w-5" />
                Chat
              </button>
              <button className="flex-1 py-3 flex items-center justify-center gap-2 text-gray-600">
                <ShoppingBag className="h-5 w-5" />
                Requests ({itemRequests.length})
              </button>
            </div>

            <div ref={chatContainerRef} className="flex-1 overflow-y-auto p-4 space-y-3">
              {chatMessages.map((msg) => (
                <div key={msg.id} className="flex gap-2">
                  <img
                    src={msg.user.avatar_url || `https://api.dicebear.com/7.x/avataaars/svg?seed=${msg.user_id}`}
                    alt={msg.user.full_name}
                    className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                  />
                  <div className="flex-1">
                    <div className="text-sm">
                      <span className="font-semibold">{msg.user.full_name}</span>
                      <span className="text-gray-600 ml-2">{msg.message}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="p-4 border-t space-y-2">
              {user && profile?.user_type === 'collector' && (
                <button
                  onClick={() => setShowRequestItem(true)}
                  className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 flex items-center justify-center gap-2"
                >
                  <ShoppingBag className="h-5 w-5" />
                  Request Item
                </button>
              )}
              <div className="flex gap-2">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Send a message..."
                  className="flex-1 border rounded-lg px-3 py-2"
                  onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
                />
                <button
                  onClick={sendMessage}
                  className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
                >
                  <Send className="h-5 w-5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showRequestItem && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold">Request Item</h2>
              <button onClick={() => setShowRequestItem(false)}>
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Item Name</label>
                <input
                  type="text"
                  value={requestItemName}
                  onChange={(e) => setRequestItemName(e.target.value)}
                  className="w-full border rounded-lg px-3 py-2"
                  placeholder="What are you looking for?"
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-1">Description</label>
                <textarea
                  value={requestDescription}
                  onChange={(e) => setRequestDescription(e.target.value)}
                  className="w-full border rounded-lg px-3 py-2"
                  rows={3}
                  placeholder="Any specific details?"
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-1">Max Price (optional)</label>
                <input
                  type="number"
                  value={requestMaxPrice}
                  onChange={(e) => setRequestMaxPrice(e.target.value)}
                  className="w-full border rounded-lg px-3 py-2"
                  placeholder="0.00"
                  step="0.01"
                />
              </div>

              <button
                onClick={requestItem}
                className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700"
              >
                Send Request
              </button>
            </div>
          </div>
        </div>
      )}

      {showStartStream && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold">Start Live Stream</h2>
              <button onClick={() => setShowStartStream(false)}>
                <X className="h-6 w-6" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Stream Title</label>
                <input
                  type="text"
                  value={streamTitle}
                  onChange={(e) => setStreamTitle(e.target.value)}
                  className="w-full border rounded-lg px-3 py-2"
                  placeholder="Shopping at Tokyo Market"
                />
              </div>

              <div>
                <label className="block text-sm font-medium mb-1">Description</label>
                <textarea
                  value={streamDescription}
                  onChange={(e) => setStreamDescription(e.target.value)}
                  className="w-full border rounded-lg px-3 py-2"
                  rows={3}
                  placeholder="Tell viewers what you'll be shopping for..."
                />
              </div>

              <button
                onClick={startStream}
                className="w-full bg-red-600 text-white py-2 rounded-lg hover:bg-red-700 flex items-center justify-center gap-2"
              >
                <Video className="h-5 w-5" />
                Go Live
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
