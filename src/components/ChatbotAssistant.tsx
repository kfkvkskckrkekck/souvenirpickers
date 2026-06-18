import { useState, useEffect, useRef } from 'react';
import { MessageCircle, X, Send, Bot, User as UserIcon, Minimize2, Maximize2 } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

type Message = {
  id: string;
  text: string;
  sender: 'user' | 'bot';
  timestamp: Date;
};

type ChatbotAssistantProps = {
  onViewChange?: (view: string) => void;
};

const botResponses: Record<string, string> = {
  'how does it work': 'SouvenirPickers connects collectors with local pickers worldwide. Collectors post requests for souvenirs, pickers respond with offers, and once an order is placed, payment is held in escrow until delivery is confirmed.',
  'how to order': 'To order a souvenir: 1) Browse our listings or post a desire for what you want, 2) Connect with a picker and agree on details, 3) Complete payment (held securely in escrow), 4) Receive your authentic souvenir!',
  'how to become picker': 'To become a picker: 1) Sign up for a picker account, 2) Complete your profile with location and specialties, 3) Add portfolio photos/videos, 4) Start accepting requests or create listings. There\'s a 60-day free trial, then $5/month.',
  'pricing': 'Souvenir prices vary based on item, location, and shipping. Most items range from $10-$100 plus shipping. You set your budget when posting requests. Pickers pay $5/month subscription after a 60-day free trial.',
  'payment methods': 'We accept all major credit and debit cards (Visa, Mastercard, American Express, Discover) through our secure Stripe integration. All transactions are encrypted and PCI-DSS compliant.',
  'shipping time': 'Delivery times vary by location. Most orders are sourced within 3-7 days, and shipping typically takes 7-21 days depending on origin. Pickers provide estimated timelines when accepting requests.',
  'refund': 'Refunds are handled case-by-case. If an item doesn\'t match description, arrives damaged, or never arrives, open a dispute within 7 days of delivery. Our support team will review and facilitate a resolution.',
  'escrow': 'Our escrow system protects both parties. When you place an order, payment is held securely. The picker receives payment only after you confirm delivery or automatically after 7 days.',
  'earnings': 'Active pickers typically earn $500-$5,000+ per month. You set your own prices and keep 90% of each sale (a 10% platform commission applies). Plus the $5 monthly subscription. There\'s no cap on earnings.',
  'countries': 'SouvenirPickers operates in 150+ countries worldwide. We have pickers in major cities and remote locations globally.',
  'support': 'For support, use the Messages section to contact our team, or email support@souvenirpickers.com. We typically respond within 24 hours.',
  'account': 'You can manage your account by clicking "Profile Settings" in the sidebar under Settings. There you can update your information, preferences, and settings.',
  'tracking': 'Yes! Pickers provide tracking numbers for all shipments. View tracking updates in your order details. You\'ll receive notifications when your item ships and is delivered.',
  'safety': 'Safety features include: verified pickers, secure escrow payments, encrypted transactions, order tracking, dispute resolution, and customer reviews.',
  'fees': 'No hidden fees for collectors - you pay the agreed price plus any taxes. Pickers pay $5/month after a 60-day free trial plus a 10% commission on all sales.',
  'commission': 'Pickers pay a 10% platform commission on all sales. This covers payment processing, buyer protection, escrow services, and platform maintenance. You keep 90% of each sale.',
  'subscription': 'Pickers need a subscription ($5/month after 60-day free trial) to access the platform and receive requests. Collectors don\'t need a subscription.',
  'custom request': 'Yes! Post your custom request in the "Desires" section. Describe what you want, specify the location, set your budget, and pickers in that area will respond.',
  'authenticity': 'We ensure authenticity through verified pickers, customer reviews, photo/video verification, and our dispute resolution process. All pickers are vetted.',
  'cancel order': 'To cancel an order, contact the picker immediately through Messages. If they haven\'t sourced the item yet, cancellation may be possible. Otherwise, use the dispute process.',
  'mobile app': 'Currently available as a responsive web app that works on all devices. A dedicated mobile app is in development.',
};

const quickActions = [
  { label: 'How does it work?', keywords: 'how does it work' },
  { label: 'How to order?', keywords: 'how to order' },
  { label: 'Become a picker', keywords: 'how to become picker' },
  { label: 'Pricing info', keywords: 'pricing' },
  { label: 'Shipping times', keywords: 'shipping time' },
  { label: 'Contact support', keywords: 'support' },
];

export function ChatbotAssistant({ onViewChange }: ChatbotAssistantProps) {
  const { profile } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [isMinimized, setIsMinimized] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      text: 'Hi! I\'m your SouvenirPickers assistant. How can I help you today?',
      sender: 'bot',
      timestamp: new Date(),
    },
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const findBestResponse = (userMessage: string): string => {
    const lowerMessage = userMessage.toLowerCase();

    for (const [keywords, response] of Object.entries(botResponses)) {
      if (lowerMessage.includes(keywords)) {
        return response;
      }
    }

    if (lowerMessage.includes('hello') || lowerMessage.includes('hi') || lowerMessage.includes('hey')) {
      return 'Hello! Welcome to SouvenirPickers. I can help you with information about ordering souvenirs, becoming a picker, payments, shipping, and more. What would you like to know?';
    }

    if (lowerMessage.includes('thank')) {
      return 'You\'re welcome! Is there anything else I can help you with?';
    }

    if (lowerMessage.includes('listing') || lowerMessage.includes('browse')) {
      return 'You can browse available souvenirs by clicking "Browse Listings" in the navigation menu. You\'ll find authentic items from around the world!';
    }

    if (lowerMessage.includes('message') || lowerMessage.includes('contact')) {
      return 'To message pickers or support, click the "Messages" button in the navigation. You can have real-time conversations there.';
    }

    if (lowerMessage.includes('profile') || lowerMessage.includes('account settings')) {
      return 'Click "Profile Settings" in the sidebar under Settings to manage your account settings, preferences, and personal information.';
    }

    return 'I\'m not sure about that specific question. You can:\n• Check our FAQ section for detailed answers\n• Contact our support team via Messages\n• Browse our Help section\n\nWhat else can I help you with?';
  };

  const handleSendMessage = () => {
    if (!inputValue.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: inputValue,
      sender: 'user',
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInputValue('');
    setIsTyping(true);

    setTimeout(() => {
      const botResponse = findBestResponse(inputValue);
      const botMessage: Message = {
        id: (Date.now() + 1).toString(),
        text: botResponse,
        sender: 'bot',
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, botMessage]);
      setIsTyping(false);
    }, 1000);
  };

  const handleQuickAction = (keywords: string) => {
    const userMessage: Message = {
      id: Date.now().toString(),
      text: keywords.charAt(0).toUpperCase() + keywords.slice(1),
      sender: 'user',
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setIsTyping(true);

    setTimeout(() => {
      const botResponse = findBestResponse(keywords);
      const botMessage: Message = {
        id: (Date.now() + 1).toString(),
        text: botResponse,
        sender: 'bot',
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, botMessage]);
      setIsTyping(false);
    }, 1000);
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-6 right-6 bg-gradient-to-r from-blue-600 to-blue-700 text-white p-4 rounded-full shadow-2xl hover:shadow-blue-500/50 transition-all duration-300 transform hover:scale-110 z-50 group"
        aria-label="Open chat assistant"
      >
        <MessageCircle className="w-7 h-7" />
        <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold w-6 h-6 rounded-full flex items-center justify-center animate-pulse">
          ?
        </span>
        <div className="absolute bottom-full right-0 mb-2 bg-gray-900 text-white text-sm px-4 py-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none">
          Need help? Chat with us!
          <div className="absolute top-full right-4 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
        </div>
      </button>
    );
  }

  return (
    <div
      className={`fixed bottom-6 right-6 bg-white rounded-2xl shadow-2xl z-50 flex flex-col transition-all duration-300 ${
        isMinimized ? 'w-80 h-16' : 'w-96 h-[600px]'
      }`}
    >
      <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white p-4 rounded-t-2xl flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-white bg-opacity-20 p-2 rounded-full">
            <Bot className="w-6 h-6" />
          </div>
          <div>
            <h3 className="font-bold text-lg">SouvenirPickers Assistant</h3>
            <p className="text-blue-100 text-xs">Always here to help</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsMinimized(!isMinimized)}
            className="p-1 hover:bg-white hover:bg-opacity-20 rounded-lg transition-colors"
            aria-label={isMinimized ? 'Maximize' : 'Minimize'}
          >
            {isMinimized ? <Maximize2 className="w-5 h-5" /> : <Minimize2 className="w-5 h-5" />}
          </button>
          <button
            onClick={() => setIsOpen(false)}
            className="p-1 hover:bg-white hover:bg-opacity-20 rounded-lg transition-colors"
            aria-label="Close chat"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
      </div>

      {!isMinimized && (
        <>
          <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-gray-50">
            {messages.map((message) => (
              <div
                key={message.id}
                className={`flex gap-3 ${message.sender === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                {message.sender === 'bot' && (
                  <div className="bg-blue-600 text-white p-2 rounded-full h-8 w-8 flex items-center justify-center flex-shrink-0">
                    <Bot className="w-4 h-4" />
                  </div>
                )}
                <div
                  className={`max-w-[75%] rounded-2xl px-4 py-3 ${
                    message.sender === 'user'
                      ? 'bg-blue-600 text-white rounded-br-sm'
                      : 'bg-white text-gray-800 shadow-md rounded-bl-sm'
                  }`}
                >
                  <p className="text-sm leading-relaxed whitespace-pre-line">{message.text}</p>
                  <p
                    className={`text-xs mt-1 ${
                      message.sender === 'user' ? 'text-blue-100' : 'text-gray-400'
                    }`}
                  >
                    {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
                {message.sender === 'user' && (
                  <div className="bg-gray-700 text-white p-2 rounded-full h-8 w-8 flex items-center justify-center flex-shrink-0">
                    <UserIcon className="w-4 h-4" />
                  </div>
                )}
              </div>
            ))}

            {isTyping && (
              <div className="flex gap-3 justify-start">
                <div className="bg-blue-600 text-white p-2 rounded-full h-8 w-8 flex items-center justify-center flex-shrink-0">
                  <Bot className="w-4 h-4" />
                </div>
                <div className="bg-white rounded-2xl rounded-bl-sm px-4 py-3 shadow-md">
                  <div className="flex gap-1">
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.2s' }}></div>
                  </div>
                </div>
              </div>
            )}

            {messages.length === 1 && (
              <div className="space-y-2">
                <p className="text-sm text-gray-600 font-medium px-2">Quick actions:</p>
                <div className="grid grid-cols-2 gap-2">
                  {quickActions.map((action) => (
                    <button
                      key={action.keywords}
                      onClick={() => handleQuickAction(action.keywords)}
                      className="bg-white text-blue-600 text-sm px-3 py-2 rounded-lg border border-blue-200 hover:bg-blue-50 transition-colors text-left font-medium shadow-sm"
                    >
                      {action.label}
                    </button>
                  ))}
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          <div className="p-4 bg-white border-t border-gray-200 rounded-b-2xl">
            <div className="flex gap-2">
              <input
                type="text"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                placeholder="Type your message..."
                className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-600 focus:border-transparent"
              />
              <button
                onClick={handleSendMessage}
                disabled={!inputValue.trim()}
                className="bg-gradient-to-r from-blue-600 to-blue-700 text-white p-2 rounded-lg hover:from-blue-700 hover:to-blue-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-md"
                aria-label="Send message"
              >
                <Send className="w-5 h-5" />
              </button>
            </div>
            {onViewChange && (
              <div className="mt-3 flex gap-2">
                <button
                  onClick={() => onViewChange('faq')}
                  className="text-xs text-blue-600 hover:underline"
                >
                  View FAQ
                </button>
                <span className="text-gray-300">•</span>
                <button
                  onClick={() => onViewChange('messages')}
                  className="text-xs text-blue-600 hover:underline"
                >
                  Contact Support
                </button>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
