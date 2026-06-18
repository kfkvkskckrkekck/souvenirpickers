import { useState, useEffect, useRef } from 'react';
import { MessageCircle, Send, ArrowLeft, Image as ImageIcon, Smile, Check, CheckCheck, Loader, FileText, Lightbulb, User, Clock, Bell } from 'lucide-react';
import { supabase, Conversation, ConversationMessage, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useNotification } from '../contexts/NotificationContext';
import { getOrCreateConversation } from '../lib/conversations';
import { uploadImage } from '../lib/storage';
import { showMessageNotification, requestNotificationPermission } from '../lib/browserNotifications';
import { CustomOrderModal } from './CustomOrderModal';

type ConversationWithProfiles = Conversation & {
  client?: Profile;
  picker?: Profile;
  last_message?: string;
  last_message_at?: string;
  client_unread_count?: number;
  picker_unread_count?: number;
};

type MessageWithReactions = ConversationMessage & {
  reactions?: { reaction: string; count: number; users: string[] }[];
  read_at?: string;
};

type TypingUser = {
  user_id: string;
  full_name: string;
};

type RealTimeChatProps = {
  initialPickerId?: string | null;
};

export function RealTimeChat({ initialPickerId }: RealTimeChatProps = {}) {
  const { profile, user } = useAuth();
  const { showNotification } = useNotification();
  const [conversations, setConversations] = useState<ConversationWithProfiles[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<ConversationWithProfiles | null>(null);
  const [messages, setMessages] = useState<MessageWithReactions[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [typingUsers, setTypingUsers] = useState<TypingUser[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  const [showCustomOrderModal, setShowCustomOrderModal] = useState(false);
  const [showTip, setShowTip] = useState(true);
  const [hideConversationList, setHideConversationList] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const messageChannelRef = useRef<any>(null);

  useEffect(() => {
    if (profile && user) {
      console.log('🚀 Initializing chat for user:', user.id, 'profile:', profile.id);
      loadConversations();
      const conversationsCleanup = subscribeToConversations();
      const globalMessagesCleanup = subscribeToGlobalMessages();

      // Request notification permission for browser notifications
      requestNotificationPermission();

      return () => {
        if (conversationsCleanup) conversationsCleanup();
        if (globalMessagesCleanup) globalMessagesCleanup();
        if (messageChannelRef.current) {
          supabase.removeChannel(messageChannelRef.current);
        }
      };
    }
  }, [profile, user]);

  useEffect(() => {
    if (initialPickerId && profile) {
      handleInitialPicker(initialPickerId);
    }
  }, [initialPickerId, profile]);

  const handleInitialPicker = async (otherUserId: string) => {
    if (!profile) return;

    try {
      const { data: otherUserProfile, error: profileError } = await supabase
        .from('profiles')
        .select('id, user_type')
        .eq('id', otherUserId)
        .maybeSingle();

      if (profileError) throw profileError;

      let conversationId: string;
      if (profile.user_type === 'client' || otherUserProfile?.user_type === 'picker') {
        conversationId = await getOrCreateConversation(profile.id, otherUserId);
      } else {
        conversationId = await getOrCreateConversation(otherUserId, profile.id);
      }

      const { data: conversation, error } = await supabase
        .from('conversations')
        .select(`
          *,
          client:profiles!conversations_client_id_fkey(*),
          picker:profiles!conversations_picker_id_fkey(*)
        `)
        .eq('id', conversationId)
        .single();

      if (error) throw error;

      if (conversation) {
        setSelectedConversation(conversation);
        setHideConversationList(true);
      }
    } catch (error) {
      console.error('Error opening conversation:', error);
    }
  };

  useEffect(() => {
    if (selectedConversation) {
      loadMessages(selectedConversation.id);
      markMessagesAsRead(selectedConversation.id);
      subscribeToMessages(selectedConversation.id);
      subscribeToTyping(selectedConversation.id);
      // Scroll immediately when conversation is selected
      setTimeout(() => scrollToBottom('auto'), 100);
    }

    return () => {
      if (messageChannelRef.current) {
        supabase.removeChannel(messageChannelRef.current);
      }
    };
  }, [selectedConversation]);

  useEffect(() => {
    scrollToBottom('smooth');
  }, [messages]);

  const scrollToBottom = (behavior: ScrollBehavior = 'smooth') => {
    messagesEndRef.current?.scrollIntoView({ behavior, block: 'end' });
  };

  const subscribeToConversations = () => {
    const channel = supabase
      .channel('conversations_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'conversations',
        },
        () => {
          loadConversations();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const subscribeToGlobalMessages = () => {
    if (!user) {
      console.log('❌ Cannot subscribe to global messages: No user');
      return () => {}; // Return empty cleanup function
    }

    console.log('✅ Subscribing to global messages for user:', user.id);

    const channel = supabase
      .channel('global_messages_notifications')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'conversation_messages',
        },
        async (payload) => {
          console.log('📨 New message received:', payload.new);
          console.log('Current user ID:', user.id);
          console.log('Message sender ID:', payload.new.sender_id);

          // Only show notification if message is from someone else
          if (payload.new.sender_id === user.id) {
            console.log('⏭️ Skipping notification: Message is from current user');
            return;
          }

          // Check if this conversation involves the current user
          const { data: conversation, error } = await supabase
            .from('conversations')
            .select('*, client:profiles!conversations_client_id_fkey(full_name), picker:profiles!conversations_picker_id_fkey(full_name)')
            .eq('id', payload.new.conversation_id)
            .or(`client_id.eq.${user.id},picker_id.eq.${user.id}`)
            .single();

          console.log('Conversation check result:', { conversation, error });

          if (!conversation) {
            console.log('⏭️ Skipping notification: User not part of this conversation');
            return;
          }

          // Get sender name
          const isFromClient = conversation.client_id === payload.new.sender_id;
          const senderName = isFromClient
            ? (conversation.client?.full_name || 'Someone')
            : (conversation.picker?.full_name || 'Someone');

          // Show notification with message preview
          const messagePreview = payload.new.content.length > 50
            ? payload.new.content.substring(0, 50) + '...'
            : payload.new.content;

          console.log('🔔 Showing notification from:', senderName);

          // Show toast notification in app
          showNotification('info', `💬 ${senderName}: "${messagePreview}"`, 6000);

          // Show browser notification (if tab not focused)
          if (!document.hasFocus()) {
            showMessageNotification(
              senderName,
              messagePreview,
              payload.new.conversation_id
            );
          }

          // Reload conversations to update unread counts
          loadConversations();
        }
      )
      .subscribe();

    return () => {
      console.log('🧹 Cleaning up global messages subscription');
      supabase.removeChannel(channel);
    };
  };

  const subscribeToMessages = (conversationId: string) => {
    const channel = supabase
      .channel(`messages_${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'conversation_messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        async (payload) => {
          setMessages((prev) => {
            // Avoid duplicate messages - check if message with this ID already exists
            const exists = prev.some((msg) => msg.id === payload.new.id);
            if (exists) return prev;
            return [...prev, payload.new as ConversationMessage];
          });
          if (payload.new.sender_id !== user?.id) {
            markMessagesAsRead(conversationId);
            // Note: Global message listener will show notification, no need to duplicate here
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'conversation_messages',
          filter: `conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === payload.new.id ? { ...msg, ...payload.new } : msg
            )
          );
        }
      )
      .subscribe();

    messageChannelRef.current = channel;
  };

  const subscribeToTyping = (conversationId: string) => {
    const channel = supabase
      .channel(`typing_${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'typing_indicators',
          filter: `conversation_id=eq.${conversationId}`,
        },
        async () => {
          loadTypingIndicators(conversationId);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const loadTypingIndicators = async (conversationId: string) => {
    try {
      const { data, error } = await supabase
        .from('typing_indicators')
        .select(`
          user_id,
          is_typing
        `)
        .eq('conversation_id', conversationId)
        .eq('is_typing', true)
        .neq('user_id', user?.id || '')
        .gte('updated_at', new Date(Date.now() - 5000).toISOString());

      if (error) throw error;

      const typingUserIds = data?.map((t) => t.user_id) || [];

      if (typingUserIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', typingUserIds);

        setTypingUsers(
          profiles?.map((p) => ({ user_id: p.id, full_name: p.full_name })) || []
        );
      } else {
        setTypingUsers([]);
      }
    } catch (error) {

    }
  };

  const updateTypingStatus = async (conversationId: string, isTyping: boolean) => {
    try {
      await supabase.from('typing_indicators').upsert({
        conversation_id: conversationId,
        user_id: user?.id,
        is_typing: isTyping,
        updated_at: new Date().toISOString(),
      });
    } catch (error) {

    }
  };

  const handleTyping = () => {
    if (!selectedConversation) return;

    if (!isTyping) {
      setIsTyping(true);
      updateTypingStatus(selectedConversation.id, true);
    }

    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current);
    }

    typingTimeoutRef.current = setTimeout(() => {
      setIsTyping(false);
      updateTypingStatus(selectedConversation.id, false);
    }, 3000);
  };

  const loadConversations = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('conversations')
        .select(`
          *,
          client:profiles!conversations_client_id_fkey(*),
          picker:profiles!conversations_picker_id_fkey(*)
        `)
        .or(`client_id.eq.${user.id},picker_id.eq.${user.id}`)
        .order('updated_at', { ascending: false });

      if (error) throw error;
      setConversations(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async (conversationId: string) => {
    try {
      const { data, error } = await supabase
        .from('conversation_messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (error) {

    }
  };

  const markMessagesAsRead = async (conversationId: string) => {
    try {
      await supabase.rpc('mark_messages_read', {
        p_conversation_id: conversationId,
      });

      setConversations((prev) =>
        prev.map((conv) =>
          conv.id === conversationId
            ? {
                ...conv,
                client_unread_count: profile?.user_type === 'client' ? 0 : conv.client_unread_count,
                picker_unread_count: profile?.user_type === 'picker' ? 0 : conv.picker_unread_count,
              }
            : conv
        )
      );
    } catch (error) {

    }
  };

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedConversation || sending) return;

    setSending(true);
    setIsTyping(false);
    updateTypingStatus(selectedConversation.id, false);

    const messageContent = newMessage.trim();
    const tempId = `temp-${Date.now()}`;

    // Optimistically add message to UI immediately
    const optimisticMessage: MessageWithReactions = {
      id: tempId,
      conversation_id: selectedConversation.id,
      sender_id: user?.id || '',
      content: messageContent,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, optimisticMessage]);
    setNewMessage('');

    try {
      const { data, error } = await supabase.from('conversation_messages').insert({
        conversation_id: selectedConversation.id,
        sender_id: user?.id,
        content: messageContent,
        read: false,
      }).select().single();

      if (error) throw error;

      // Replace optimistic message with real one
      if (data) {
        setMessages((prev) =>
          prev.map((msg) => (msg.id === tempId ? data as MessageWithReactions : msg))
        );
      }
    } catch (error) {
      // Remove optimistic message on error
      setMessages((prev) => prev.filter((msg) => msg.id !== tempId));
      setNewMessage(messageContent); // Restore message content
    } finally {
      setSending(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const getOtherUser = (conversation: ConversationWithProfiles) => {
    if (profile?.user_type === 'client') {
      return conversation.picker;
    }
    return conversation.client;
  };

  const getUnreadCount = (conversation: ConversationWithProfiles) => {
    if (profile?.user_type === 'client') {
      return conversation.client_unread_count || 0;
    }
    return conversation.picker_unread_count || 0;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <Loader className="w-8 h-8 animate-spin text-blue-600" />
      </div>
    );
  }

  return (
    <div className="flex bg-gray-50 overflow-hidden flex-1 h-full">
      {!hideConversationList && (
        <div className={`${selectedConversation ? 'hidden md:block' : 'block'} w-full md:w-96 bg-white border-r border-gray-200 flex flex-col h-full`}>
          <div className="p-4 border-b bg-white flex-shrink-0">
            <h2 className="text-xl font-bold text-gray-900">Messages</h2>
          </div>

        {/* <div className="flex-1 overflow-y-auto min-h-0"> */}
          <div className="overflow-y-auto" style={{ height: '75vh' }}>
          {conversations.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-gray-500 p-8 text-center">
              <MessageCircle className="w-16 h-16 mb-4 text-gray-300" />
              <p>No conversations yet</p>
            </div>
          ) : (
            conversations.map((conversation) => {
              const otherUser = getOtherUser(conversation);
              const unread = getUnreadCount(conversation);
              const hasUnread = unread > 0;
              const lastMessageTime = conversation.last_message_at
                ? new Date(conversation.last_message_at)
                : null;

              const formatTime = (date: Date) => {
                const now = new Date();
                const diffMs = now.getTime() - date.getTime();
                const diffMins = Math.floor(diffMs / 60000);
                const diffHours = Math.floor(diffMs / 3600000);
                const diffDays = Math.floor(diffMs / 86400000);

                if (diffMins < 1) return 'Just now';
                if (diffMins < 60) return `${diffMins}m ago`;
                if (diffHours < 24) return `${diffHours}h ago`;
                if (diffDays < 7) return `${diffDays}d ago`;
                return date.toLocaleDateString();
              };

              return (
                <button
                  key={conversation.id}
                  onClick={() => setSelectedConversation(conversation)}
                  className={`w-full p-4 border-b hover:bg-gray-50 transition-colors text-left ${
                    selectedConversation?.id === conversation.id
                      ? 'bg-blue-50 border-l-4 border-l-blue-600'
                      : hasUnread
                        ? 'bg-blue-50/30'
                        : ''
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 relative">
                      {otherUser?.avatar_url ? (
                        <img
                          src={otherUser.avatar_url}
                          alt={otherUser.full_name}
                          className="w-12 h-12 rounded-full object-cover"
                        />
                      ) : (
                        <div className="w-12 h-12 rounded-full bg-gray-300 flex items-center justify-center">
                          <User className="w-6 h-6 text-gray-600" />
                        </div>
                      )}
                      {hasUnread && (
                        <div className="absolute -top-1 -right-1 w-5 h-5 bg-blue-600 rounded-full flex items-center justify-center">
                          <Bell className="w-3 h-3 text-white" />
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-baseline justify-between gap-2">
                        <h3 className={`font-semibold truncate ${hasUnread ? 'text-gray-900' : 'text-gray-700'}`}>
                          {otherUser?.full_name || 'Unknown User'}
                        </h3>
                        {lastMessageTime && (
                          <span className="text-xs text-gray-500 flex-shrink-0">
                            {formatTime(lastMessageTime)}
                          </span>
                        )}
                      </div>
                      {conversation.last_message && (
                        <p className={`text-sm truncate mt-1 ${hasUnread ? 'text-gray-900 font-medium' : 'text-gray-600'}`}>
                          {conversation.last_message}
                        </p>
                      )}
                      {hasUnread && (
                        <div className="flex items-center gap-1 mt-1">
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-600 text-white">
                            {unread} new {unread === 1 ? 'message' : 'messages'}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                </button>
              );
            })
          )}
        </div>
      </div>
      )}

      <div className={`${selectedConversation ? 'block' : 'hidden md:block'} flex-1 flex flex-col bg-white h-full overflow-hidden`}>
        {selectedConversation ? (
          <>
            <div className="p-4 border-b bg-white flex items-center justify-between gap-3 flex-shrink-0">
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <button
                  onClick={() => {
                    if (hideConversationList) {
                      setHideConversationList(false);
                      setSelectedConversation(null);
                    } else {
                      setSelectedConversation(null);
                    }
                  }}
                  className={`${hideConversationList ? '' : 'md:hidden'} p-2 hover:bg-gray-100 rounded-lg flex-shrink-0`}
                >
                  <ArrowLeft className="w-5 h-5" />
                </button>
                <div className="flex-shrink-0">
                  {getOtherUser(selectedConversation)?.avatar_url ? (
                    <img
                      src={getOtherUser(selectedConversation)?.avatar_url}
                      alt={getOtherUser(selectedConversation)?.full_name || 'User'}
                      className="w-10 h-10 rounded-full object-cover"
                    />
                  ) : (
                    <div className="w-10 h-10 rounded-full bg-gray-300 flex items-center justify-center">
                      <User className="w-5 h-5 text-gray-600" />
                    </div>
                  )}
                </div>
                <div className="min-w-0">
                  <h3 className="font-semibold text-gray-900 truncate">
                    {getOtherUser(selectedConversation)?.full_name || 'Unknown User'}
                  </h3>
                  {typingUsers.length > 0 ? (
                    <p className="text-sm text-green-600 flex items-center gap-1">
                      <span className="flex gap-0.5">
                        <span className="w-1.5 h-1.5 bg-green-600 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></span>
                        <span className="w-1.5 h-1.5 bg-green-600 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></span>
                        <span className="w-1.5 h-1.5 bg-green-600 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></span>
                      </span>
                      typing...
                    </p>
                  ) : (
                    <p className="text-xs text-gray-500">
                      {getOtherUser(selectedConversation)?.user_type === 'picker' ? 'Souvenir Picker' : 'Collector'}
                    </p>
                  )}
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    if (profile?.user_type === 'picker') {
                      setShowCustomOrderModal(true);
                    } else {
                      alert('Custom orders can only be created by pickers. Please discuss your request with the picker in chat, and they will create a custom order for you.');
                    }
                  }}
                  className="flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg transition-colors shadow-lg hover:shadow-xl flex-shrink-0 text-sm font-semibold"
                  title={profile?.user_type === 'picker' ? 'Create Custom Order' : 'Custom Orders (Picker only)'}
                >
                  <FileText className="w-5 h-5" />
                  <span className="hidden sm:inline">Custom Order</span>
                </button>
              </div>
            </div>

            {/* <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gradient-to-b from-gray-50 to-white" style={{ overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}> */}
            <div className="overflow-y-auto p-4 space-y-4 bg-gradient-to-b from-gray-50 to-white" style={{ height: '65vh', overflowY: 'auto', WebkitOverflowScrolling: 'touch' }}>
              {profile?.user_type === 'picker' && showTip && messages.length > 2 && (
                <div className="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-4 border-2 border-green-200 mb-4">
                  <div className="flex items-start gap-3">
                    <Lightbulb className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <p className="text-sm text-gray-700">
                        <strong className="text-green-700">Tip:</strong> Is this collector asking for something specific? Click the green <strong>"Custom Order"</strong> button above to create a personalized offer based on their exact demands!
                      </p>
                    </div>
                    <button
                      onClick={() => setShowTip(false)}
                      className="text-gray-400 hover:text-gray-600 flex-shrink-0"
                    >
                      ×
                    </button>
                  </div>
                </div>
              )}

              {profile?.user_type === 'collector' && showTip && messages.length > 2 && getOtherUser(selectedConversation)?.user_type === 'picker' && (
                <div className="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-4 border-2 border-green-200 mb-4">
                  <div className="flex items-start gap-3">
                    <Lightbulb className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <p className="text-sm text-gray-700">
                        <strong className="text-green-700">Tip:</strong> Need something specific that's not listed? Click the green <strong>"Custom Order"</strong> button above to request a personalized item from this picker!
                      </p>
                    </div>
                    <button
                      onClick={() => setShowTip(false)}
                      className="text-gray-400 hover:text-gray-600 flex-shrink-0"
                    >
                      ×
                    </button>
                  </div>
                </div>
              )}

              {messages.map((message) => {
                const isOwn = message.sender_id === user?.id;
                const sender = isOwn ? profile : getOtherUser(selectedConversation);
                const senderName = sender?.full_name || 'Unknown';
                const senderAvatar = sender?.avatar_url;

                return (
                  <div
                    key={message.id}
                    className={`flex gap-2 ${isOwn ? 'justify-end' : 'justify-start'}`}
                  >
                    {!isOwn && (
                      <div className="flex-shrink-0">
                        {senderAvatar ? (
                          <img
                            src={senderAvatar}
                            alt={senderName}
                            className="w-8 h-8 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-gray-300 flex items-center justify-center">
                            <User className="w-4 h-4 text-gray-600" />
                          </div>
                        )}
                      </div>
                    )}
                    <div className={`flex flex-col ${isOwn ? 'items-end' : 'items-start'}`}>
                      {!isOwn && (
                        <span className="text-xs text-gray-500 font-medium mb-1 px-1">
                          {senderName}
                        </span>
                      )}
                      <div
                        className={`max-w-xs lg:max-w-md px-4 py-2 rounded-2xl shadow-sm ${
                          isOwn
                            ? 'bg-blue-600 text-white rounded-br-none'
                            : 'bg-white border border-gray-200 text-gray-900 rounded-bl-none'
                        }`}
                      >
                        <p className="break-words whitespace-pre-wrap">{message.content}</p>
                        <div className="flex items-center gap-1 justify-end mt-1">
                          <Clock className={`w-3 h-3 ${isOwn ? 'text-blue-100' : 'text-gray-400'}`} />
                          <span className={`text-xs ${isOwn ? 'text-blue-100' : 'text-gray-500'}`}>
                            {new Date(message.created_at).toLocaleTimeString([], {
                              hour: '2-digit',
                              minute: '2-digit',
                            })}
                          </span>
                          {isOwn && (
                            message.read ? (
                              <CheckCheck className="w-3 h-3 text-blue-100" title="Read" />
                            ) : (
                              <Check className="w-3 h-3 text-blue-100" title="Sent" />
                            )
                          )}
                        </div>
                      </div>
                    </div>
                    {isOwn && (
                      <div className="flex-shrink-0">
                        {senderAvatar ? (
                          <img
                            src={senderAvatar}
                            alt="You"
                            className="w-8 h-8 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
                            <User className="w-4 h-4 text-blue-600" />
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
              <div ref={messagesEndRef} className="h-4" />
            </div>

            <div className="p-3 md:p-4 border-t bg-white shadow-lg flex-shrink-0">
              <div className="flex items-end gap-2">
                <div className="flex-1 relative">
                  <textarea
                    value={newMessage}
                    onChange={(e) => {
                      setNewMessage(e.target.value);
                      handleTyping();
                    }}
                    onKeyDown={handleKeyDown}
                    placeholder={`Message ${getOtherUser(selectedConversation)?.full_name || 'user'}...`}
                    rows={1}
                    className="w-full px-3 md:px-4 py-2 md:py-3 border-2 border-gray-300 rounded-2xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none max-h-24 transition-all text-sm md:text-base"
                    style={{ minHeight: '44px' }}
                  />
                </div>
                <button
                  onClick={sendMessage}
                  disabled={!newMessage.trim() || sending}
                  className="bg-blue-600 text-white p-3 rounded-full hover:bg-blue-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl flex-shrink-0"
                  title={newMessage.trim() ? 'Send message (Enter)' : 'Type a message to send'}
                >
                  {sending ? (
                    <Loader className="w-5 h-5 animate-spin" />
                  ) : (
                    <Send className="w-5 h-5" />
                  )}
                </button>
              </div>
              <p className="text-xs text-gray-500 mt-1.5 text-center hidden sm:block">
                Press Enter to send, Shift+Enter for new line
              </p>
            </div>
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-gray-500 p-8 text-center">
            <MessageCircle className="w-24 h-24 mb-4 text-gray-300" />
            <h3 className="text-xl font-semibold mb-2">Select a conversation</h3>
            <p>Choose a conversation from the list to start chatting</p>
          </div>
        )}
      </div>

      {showCustomOrderModal && selectedConversation && (
        <CustomOrderModal
          recipientProfile={getOtherUser(selectedConversation)!}
          onClose={() => setShowCustomOrderModal(false)}
          onOrderCreated={() => {
            setShowCustomOrderModal(false);
            loadConversations();
          }}
        />
      )}
    </div>
  );
}
