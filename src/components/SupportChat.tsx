import { useState, useEffect, useRef } from 'react';
import { Send, User, Clock, Loader, MessageCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type SupportMessage = {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  created_at: string;
  is_support: boolean;
};

export function SupportChat() {
  const { user, profile } = useAuth();
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (user) {
      initializeSupportChat();
    }
  }, [user]);

  useEffect(() => {
    if (conversationId) {
      loadMessages();
      subscribeToMessages();
    }
  }, [conversationId]);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const initializeSupportChat = async () => {
    if (!user) return;

    try {
      const { data: existingConversation, error: fetchError } = await supabase
        .from('support_conversations')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'open')
        .maybeSingle();

      if (fetchError && fetchError.code !== 'PGRST116') {
        console.error('Error fetching support conversation:', fetchError);
      }

      if (existingConversation) {
        setConversationId(existingConversation.id);
      } else {
        const { data: newConversation, error: createError } = await supabase
          .from('support_conversations')
          .insert({
            user_id: user.id,
            status: 'open',
          })
          .select('id')
          .single();

        if (createError) {
          console.error('Error creating support conversation:', createError);
        } else if (newConversation) {
          setConversationId(newConversation.id);

          await supabase.from('support_messages').insert({
            support_conversation_id: newConversation.id,
            sender_id: 'system',
            content: `Hello ${profile?.full_name || 'there'}! Welcome to SouvenirPickers support. How can we help you today?`,
            is_support: true,
          });
        }
      }
    } catch (error) {
      console.error('Error initializing support chat:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async () => {
    if (!conversationId) return;

    try {
      const { data, error } = await supabase
        .from('support_messages')
        .select('*')
        .eq('support_conversation_id', conversationId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (error) {
      console.error('Error loading messages:', error);
    }
  };

  const subscribeToMessages = () => {
    if (!conversationId) return;

    const channel = supabase
      .channel(`support_messages_${conversationId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `support_conversation_id=eq.${conversationId}`,
        },
        (payload) => {
          setMessages((prev) => {
            const exists = prev.some((msg) => msg.id === payload.new.id);
            if (exists) return prev;
            return [...prev, payload.new as SupportMessage];
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const sendMessage = async () => {
    if (!newMessage.trim() || !conversationId || sending || !user) return;

    setSending(true);
    const messageContent = newMessage.trim();
    const tempId = `temp-${Date.now()}`;

    const optimisticMessage: SupportMessage = {
      id: tempId,
      conversation_id: conversationId,
      sender_id: user.id,
      content: messageContent,
      created_at: new Date().toISOString(),
      is_support: false,
    };

    setMessages((prev) => [...prev, optimisticMessage]);
    setNewMessage('');

    try {
      const { data, error } = await supabase
        .from('support_messages')
        .insert({
          support_conversation_id: conversationId,
          sender_id: user.id,
          content: messageContent,
          is_support: false,
        })
        .select()
        .single();

      if (error) throw error;

      if (data) {
        setMessages((prev) =>
          prev.map((msg) => (msg.id === tempId ? data as SupportMessage : msg))
        );
      }
    } catch (error) {
      console.error('Error sending message:', error);
      setMessages((prev) => prev.filter((msg) => msg.id !== tempId));
      setNewMessage(messageContent);
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

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <Loader className="w-8 h-8 animate-spin text-green-600" />
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full bg-white">
      <div className="flex-1 overflow-y-auto p-6 space-y-4 bg-gradient-to-b from-gray-50 to-white">
        {messages.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-500">
            <MessageCircle className="w-16 h-16 mb-4 text-gray-300" />
            <p className="text-lg font-medium">Start a conversation</p>
            <p className="text-sm">Our support team will respond shortly</p>
          </div>
        ) : (
          messages.map((message) => {
            const isOwn = message.sender_id === user?.id;
            const isSystem = message.sender_id === 'system';
            const senderName = isSystem ? 'Support Team' : isOwn ? 'You' : 'Support Team';

            return (
              <div
                key={message.id}
                className={`flex gap-2 ${isOwn ? 'justify-end' : 'justify-start'}`}
              >
                {!isOwn && (
                  <div className="flex-shrink-0">
                    <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                      <CheckCircle className="w-5 h-5 text-green-600" />
                    </div>
                  </div>
                )}
                <div className={`flex flex-col ${isOwn ? 'items-end' : 'items-start'}`}>
                  <span className="text-xs text-gray-500 font-medium mb-1 px-1">
                    {senderName}
                  </span>
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
                    </div>
                  </div>
                </div>
                {isOwn && (
                  <div className="flex-shrink-0">
                    <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center">
                      <User className="w-4 h-4 text-blue-600" />
                    </div>
                  </div>
                )}
              </div>
            );
          })
        )}
        <div ref={messagesEndRef} className="h-4" />
      </div>

      <div className="p-4 border-t bg-white shadow-lg">
        <div className="flex items-end gap-3">
          <div className="flex-1 relative">
            <textarea
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Type your message..."
              rows={1}
              className="w-full px-4 py-3 border-2 border-gray-300 rounded-2xl focus:ring-2 focus:ring-green-500 focus:border-green-500 resize-none max-h-32 transition-all"
              style={{ minHeight: '48px' }}
            />
            {newMessage.length > 0 && (
              <span className="absolute bottom-2 right-3 text-xs text-gray-400">
                {newMessage.length}/1000
              </span>
            )}
          </div>
          <button
            onClick={sendMessage}
            disabled={!newMessage.trim() || sending}
            className="bg-green-600 text-white p-3.5 rounded-full hover:bg-green-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl transform hover:scale-105 active:scale-95"
            title={newMessage.trim() ? 'Send message (Enter)' : 'Type a message to send'}
          >
            {sending ? (
              <Loader className="w-5 h-5 animate-spin" />
            ) : (
              <Send className="w-5 h-5" />
            )}
          </button>
        </div>
        <p className="text-xs text-gray-500 mt-2 text-center">
          Press Enter to send, Shift+Enter for new line
        </p>
      </div>
    </div>
  );
}
