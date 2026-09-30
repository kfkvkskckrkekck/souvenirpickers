import { useState, useEffect, useRef } from 'react';
import { MessageCircle, Send, ArrowLeft, FileText, Bell, BellOff } from 'lucide-react';
import { supabase, Conversation, ConversationMessage, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { getOrCreateConversation } from '../lib/conversations';
import { CustomOrderModal } from './CustomOrderModal';
import { requestNotificationPermission, isNotificationPermissionGranted, showMessageNotification } from '../lib/browserNotifications';
import { notifyNewMessage } from '../lib/notifications';

type ConversationWithProfiles = Conversation & {
  client?: Profile;
  picker?: Profile;
};

type ConversationWithMessages = ConversationWithProfiles & {
  messages?: ConversationMessage[];
  lastMessage?: ConversationMessage;
  unreadCount?: number;
};

type MessagesViewProps = {
  initialPickerId?: string | null;
};

export function MessagesView({ initialPickerId }: MessagesViewProps) {
  const { profile, user } = useAuth();
  const [conversations, setConversations] = useState<ConversationWithMessages[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<ConversationWithMessages | null>(null);
  const [messages, setMessages] = useState<ConversationMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [showCustomOrderModal, setShowCustomOrderModal] = useState(false);
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (profile) {
      loadConversations();
      checkNotificationPermission();

      // Subscribe to all message notifications for this user
      const cleanupGlobalMessages = subscribeToAllMessages();
      return () => {
        if (cleanupGlobalMessages) cleanupGlobalMessages();
      };
    }
  }, [profile]);

  const checkNotificationPermission = () => {
    const hasPermission = isNotificationPermissionGranted();
    setNotificationsEnabled(hasPermission);
  };

  const handleEnableNotifications = async () => {
    const granted = await requestNotificationPermission();
    setNotificationsEnabled(granted);
    if (granted) {
      console.log('✅ Browser notifications enabled');
    } else {
      console.log('❌ Browser notifications denied');
    }
  };

  useEffect(() => {
    if (initialPickerId && profile?.user_type === 'client') {
      handleInitialPicker(initialPickerId);
    }
  }, [initialPickerId, profile]);

  const handleInitialPicker = async (pickerId: string) => {
    if (!profile || profile.user_type !== 'client') return;

    try {
      const conversationId = await getOrCreateConversation(profile.id, pickerId);

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
      }
    } catch (error) {

    }
  };

  useEffect(() => {
    if (selectedConversation) {
      loadMessages(selectedConversation.id);
      markMessagesAsRead(selectedConversation.id);

      const messagesCleanup = subscribeToMessages();

      return () => {
        if (messagesCleanup) messagesCleanup();
      };
    }
  }, [selectedConversation]);

  const subscribeToAllMessages = () => {
    if (!profile) return;

    const channel = supabase
      .channel(`all_messages_${profile.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'conversation_messages',
        },
        async (payload) => {
          const newMessage = payload.new as ConversationMessage;

          // Only handle messages not from the current user
          if (newMessage.sender_id === profile.id) return;

          // Skip if this is the currently selected conversation (handled separately)
          if (selectedConversation && newMessage.conversation_id === selectedConversation.id) return;

          console.log('📬 New message in another conversation:', newMessage);

          // Get conversation details
          const { data: conversation } = await supabase
            .from('conversations')
            .select(`
              *,
              client:profiles!conversations_client_id_fkey(*),
              picker:profiles!conversations_picker_id_fkey(*)
            `)
            .eq('id', newMessage.conversation_id)
            .single();

          if (conversation) {
            const otherUser = profile.id === conversation.client_id ? conversation.picker : conversation.client;

            // Show browser notification
            if (notificationsEnabled && otherUser) {
              showMessageNotification(
                otherUser.full_name || 'Someone',
                newMessage.content.substring(0, 100),
                newMessage.conversation_id,
                () => {
                  window.focus();
                  // Could navigate to the conversation here
                }
              );
            }

            // Refresh conversations list to update unread counts
            await loadConversations();
          }
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('✅ Subscribed to all message notifications');
        }
      });

    return () => {
      console.log('🔌 Unsubscribing from all message notifications');
      channel.unsubscribe();
    };
  };

  const subscribeToMessages = () => {
    if (!profile || !selectedConversation) return;

    const channel = supabase
      .channel(`messages_${selectedConversation.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'conversation_messages',
          filter: `conversation_id=eq.${selectedConversation.id}`
        },
        async (payload) => {
          const newMessage = payload.new as ConversationMessage;
          console.log('💬 New message received in conversation:', newMessage);

          setMessages(prev => [...prev, newMessage]);

          // Mark as read if it's from the other user
          if (newMessage.sender_id !== profile.id && !newMessage.read) {
            console.log('📖 Auto-marking new message as read');
            const { error } = await supabase
              .from('conversation_messages')
              .update({ read: true })
              .eq('id', newMessage.id);

            if (error) {
              console.error('Error marking new message as read:', error);
            } else {
              console.log('✅ New message marked as read');

              // Show browser notification if enabled
              const otherUser = getOtherUser(selectedConversation);
              if (otherUser && notificationsEnabled && document.hidden) {
                showMessageNotification(
                  otherUser.full_name || 'Someone',
                  newMessage.content.substring(0, 100),
                  selectedConversation.id,
                  () => {
                    window.focus();
                  }
                );
              }
            }
          }

          // Refresh conversations list
          await loadConversations();
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('✅ Subscribed to conversation messages');
        }
      });

    return () => {
      console.log('🔌 Unsubscribing from conversation messages');
      channel.unsubscribe();
    };
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
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

      const conversationsWithDetails = await Promise.all(
        (data || []).map(async (conv) => {
          const { data: lastMsg } = await supabase
            .from('conversation_messages')
            .select('*')
            .eq('conversation_id', conv.id)
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

          const { count } = await supabase
            .from('conversation_messages')
            .select('*', { count: 'exact', head: true })
            .eq('conversation_id', conv.id)
            .eq('read', false)
            .neq('sender_id', profile!.id);

          return {
            ...conv,
            lastMessage: lastMsg || undefined,
            unreadCount: count || 0,
          };
        })
      );

      setConversations(conversationsWithDetails);
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
    if (!profile) return;

    try {
      const { data: unreadMessages, error: fetchError } = await supabase
        .from('conversation_messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .neq('sender_id', profile.id)
        .eq('read', false);

      if (fetchError) {
        console.error('Error fetching unread messages:', fetchError);
        return;
      }

      if (unreadMessages && unreadMessages.length > 0) {
        console.log(`📖 Marking ${unreadMessages.length} messages as read in conversation ${conversationId}`);

        // Update all unread messages at once
        const { error: updateError } = await supabase
          .from('conversation_messages')
          .update({ read: true })
          .eq('conversation_id', conversationId)
          .neq('sender_id', profile.id)
          .eq('read', false);

        if (updateError) {
          console.error('Error marking messages as read:', updateError);
        } else {
          console.log('✅ All messages marked as read');
        }
      }

      // Reload conversations to update unread counts
      await loadConversations();
    } catch (error) {
      console.error('Error in markMessagesAsRead:', error);
    }
  };

  const sendMessage = async () => {
    if (!newMessage.trim() || !selectedConversation || !profile) return;

    setSending(true);
    const messageContent = newMessage.trim();
    try {
      const { error: messageError } = await supabase
        .from('conversation_messages')
        .insert({
          conversation_id: selectedConversation.id,
          sender_id: profile.id,
          content: messageContent,
          read: false,
        });

      if (messageError) throw messageError;
      console.log('📨 Message sent successfully');

      await supabase
        .from('conversations')
        .update({ updated_at: new Date().toISOString() })
        .eq('id', selectedConversation.id);

      await supabase
        .from('conversation_messages')
        .update({ read: true })
        .eq('conversation_id', selectedConversation.id)
        .neq('sender_id', profile.id)
        .eq('read', false);

      const otherUser = getOtherUser(selectedConversation);
      if (otherUser) {
        // Create in-app notification
        await supabase.from('notifications').insert({
          user_id: otherUser.id,
          type: 'new_message',
          title: 'New Message',
          message: `${profile.full_name || 'Someone'} sent you a message`,
          link: '/messages',
        });

        // Send email notification
        if (otherUser.email) {
          console.log('📧 Sending email notification to recipient');
          await notifyNewMessage(
            otherUser.email,
            otherUser.full_name || 'User',
            profile.full_name || 'Someone',
            messageContent.substring(0, 100)
          );
        }
      }

      setNewMessage('');
      await loadConversations();
    } catch (error) {
      console.error('Error sending message:', error);
    } finally {
      setSending(false);
    }
  };

  const getOtherUser = (conversation: ConversationWithProfiles): Profile | undefined => {
    if (!profile) return undefined;
    return profile.id === conversation.client_id ? conversation.picker : conversation.client;
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4" style={{ height: '90vh' }}>
        <div className="flex items-center justify-center h-64">
          <div className="text-gray-500">Loading messages...</div>
        </div>
      </div>
    );
  }

  const otherUser = selectedConversation ? getOtherUser(selectedConversation) : null;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4" style={{ height: '90vh' }}>
      <div className="flex h-full bg-white rounded-2xl shadow-lg overflow-hidden border border-gray-200">

        {/* Left panel — conversation list */}
        <div className={`flex flex-col w-full sm:w-80 lg:w-96 flex-shrink-0 border-r border-gray-200 ${selectedConversation ? 'hidden sm:flex' : 'flex'}`}>
          {/* Panel header */}
          <div className="flex-shrink-0 px-5 py-4 border-b border-gray-100 bg-gray-50">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-lg font-bold text-gray-900">Messages</h1>
                <p className="text-xs text-gray-500 mt-0.5">
                  {conversations.length} conversation{conversations.length !== 1 ? 's' : ''}
                </p>
              </div>
              {!notificationsEnabled && (
                <button
                  onClick={handleEnableNotifications}
                  title="Enable notifications"
                  className="p-2 rounded-lg bg-amber-100 text-amber-700 hover:bg-amber-200 transition-colors"
                >
                  <BellOff className="w-4 h-4" />
                </button>
              )}
              {notificationsEnabled && (
                <span className="p-2 rounded-lg bg-green-100 text-green-600" title="Notifications on">
                  <Bell className="w-4 h-4" />
                </span>
              )}
            </div>
          </div>

          {/* Scrollable conversation list */}
          <div className="flex-1 overflow-y-auto min-h-0">
            {conversations.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-full px-6 text-center">
                <MessageCircle className="w-12 h-12 text-gray-300 mb-3" />
                <p className="text-gray-500 font-medium">No conversations yet</p>
                <p className="text-gray-400 text-sm mt-1">
                  {profile?.user_type === 'client'
                    ? 'Contact a picker to start chatting'
                    : 'Clients will reach out to you'}
                </p>
              </div>
            ) : (
              <div className="divide-y divide-gray-100">
                {conversations.map((conversation) => {
                  const convOtherUser = getOtherUser(conversation);
                  const hasUnread = (conversation.unreadCount ?? 0) > 0;
                  const isActive = selectedConversation?.id === conversation.id;
                  return (
                    <button
                      key={conversation.id}
                      onClick={() => setSelectedConversation(conversation)}
                      className={`w-full px-4 py-3.5 text-left transition-colors border-l-4 ${
                        isActive
                          ? 'bg-blue-50 border-blue-600'
                          : hasUnread
                          ? 'bg-blue-50/40 border-blue-400 hover:bg-blue-50'
                          : 'border-transparent hover:bg-gray-50 hover:border-gray-300'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 text-white font-bold text-sm ${
                          isActive ? 'bg-blue-600' : 'bg-gradient-to-br from-blue-400 to-blue-600'
                        }`}>
                          {convOtherUser?.full_name?.charAt(0).toUpperCase() || '?'}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between gap-2">
                            <span className={`font-semibold text-sm truncate ${hasUnread ? 'text-gray-900' : 'text-gray-800'}`}>
                              {convOtherUser?.full_name || 'Unknown User'}
                            </span>
                            <span className="text-xs text-gray-400 flex-shrink-0">
                              {new Date(conversation.updated_at).toLocaleDateString([], { month: 'short', day: 'numeric' })}
                            </span>
                          </div>
                          <div className="flex items-center justify-between gap-2 mt-0.5">
                            <p className={`text-xs truncate ${hasUnread ? 'text-gray-700 font-medium' : 'text-gray-500'}`}>
                              {conversation.lastMessage?.content || 'No messages yet'}
                            </p>
                            {hasUnread && (
                              <span className="flex-shrink-0 bg-blue-600 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
                                {(conversation.unreadCount ?? 0) > 9 ? '9+' : conversation.unreadCount}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right panel — chat */}
        <div className={`flex flex-col flex-1 min-w-0 ${selectedConversation ? 'flex' : 'hidden sm:flex'}`}>
          {!selectedConversation ? (
            <div className="flex flex-col items-center justify-center h-full text-center px-8">
              <MessageCircle className="w-16 h-16 text-gray-200 mb-4" />
              <p className="text-gray-400 font-medium">Select a conversation</p>
              <p className="text-gray-300 text-sm mt-1">Choose from the list on the left</p>
            </div>
          ) : (
            <>
              {/* Chat header */}
              <div className="flex-shrink-0 px-4 py-3 border-b border-gray-200 bg-gray-50">
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setSelectedConversation(null)}
                    className="sm:hidden p-1.5 hover:bg-gray-200 rounded-lg transition-colors"
                  >
                    <ArrowLeft className="w-4 h-4" />
                  </button>
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white font-bold text-sm flex-shrink-0">
                    {otherUser?.full_name?.charAt(0).toUpperCase() || '?'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <h2 className="font-bold text-gray-900 text-sm truncate">
                      {otherUser?.full_name || 'Unknown User'}
                    </h2>
                    <p className="text-xs text-gray-500">
                      {otherUser?.user_type === 'picker' ? 'Picker' : 'Client'}
                    </p>
                  </div>
                  <button
                    onClick={() => {
                      if (profile?.user_type === 'picker') {
                        setShowCustomOrderModal(true);
                      } else {
                        alert('Only pickers can create custom orders.');
                      }
                    }}
                    className="flex items-center gap-1.5 bg-green-600 hover:bg-green-700 text-white px-3 py-1.5 rounded-lg transition-colors text-xs font-semibold flex-shrink-0"
                  >
                    <FileText className="w-3.5 h-3.5" />
                    <span className="hidden sm:inline">Custom Order</span>
                  </button>
                </div>
              </div>

              {/* Messages scroll area */}
              <div className="flex-1 overflow-y-auto min-h-0 px-4 py-4 space-y-3 bg-white">
                {messages.length === 0 && (
                  <div className="flex flex-col items-center justify-center h-full text-center">
                    <MessageCircle className="w-10 h-10 text-gray-200 mb-2" />
                    <p className="text-gray-400 text-sm">No messages yet. Say hello!</p>
                  </div>
                )}
                {messages.map((message) => {
                  const isOwn = message.sender_id === profile?.id;
                  return (
                    <div key={message.id} className={`flex ${isOwn ? 'justify-end' : 'justify-start'}`}>
                      <div className={`max-w-[75%] px-4 py-2.5 rounded-2xl shadow-sm ${
                        isOwn ? 'bg-blue-600 text-white rounded-br-sm' : 'bg-gray-100 text-gray-900 rounded-bl-sm'
                      }`}>
                        <p className="whitespace-pre-wrap break-words text-sm leading-relaxed">{message.content}</p>
                        <p className={`text-xs mt-1 text-right ${isOwn ? 'text-blue-200' : 'text-gray-400'}`}>
                          {new Date(message.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </p>
                      </div>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* Message input */}
              <div className="flex-shrink-0 px-4 py-3 border-t border-gray-200 bg-white">
                <form
                  onSubmit={(e) => { e.preventDefault(); sendMessage(); }}
                  className="flex gap-2 items-center"
                >
                  <input
                    type="text"
                    value={newMessage}
                    onChange={(e) => setNewMessage(e.target.value)}
                    placeholder="Type a message..."
                    className="flex-1 px-4 py-2.5 border border-gray-200 rounded-full bg-gray-50 focus:bg-white focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm transition-colors"
                    disabled={sending}
                  />
                  <button
                    type="submit"
                    disabled={!newMessage.trim() || sending}
                    className="w-10 h-10 bg-blue-600 text-white rounded-full font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center flex-shrink-0"
                  >
                    <Send className="w-4 h-4" />
                  </button>
                </form>
              </div>
            </>
          )}
        </div>
      </div>

      {showCustomOrderModal && otherUser && (
        <CustomOrderModal
          recipientProfile={otherUser}
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
