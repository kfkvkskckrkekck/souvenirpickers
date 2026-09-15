import { useState, useEffect } from 'react';
import { Globe, LogOut, User, CreditCard, Bell, Settings, ShoppingBag, Package, RefreshCw, Users, Radio, FileText, TrendingUp, Shield, HelpCircle, ChevronDown, Search, MapPin, Star, Menu, X, ArrowLeft, MessageCircle, CheckCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { getSubscriptionStatus } from '../lib/subscription';
import { supabase } from '../lib/supabase';

type HeaderProps = {
  currentView: string;
  onViewChange: (view: string) => void;
  onGoBack?: () => void;
  onUnreadMessageCountChange?: (count: number) => void;
  showMobileMenu?: boolean;
  onMobileMenuChange?: (show: boolean) => void;
};

export function Header({ currentView, onViewChange, onGoBack, onUnreadMessageCountChange, showMobileMenu, onMobileMenuChange }: HeaderProps) {
  const { profile, signOut, user, refreshProfile } = useAuth();
  const [unreadCount, setUnreadCount] = useState(0);
  const [unreadMessageCount, setUnreadMessageCount] = useState(0);
  const [cartItemCount, setCartItemCount] = useState(0);
  const [switching, setSwitching] = useState(false);
  const [showTrustDropdown, setShowTrustDropdown] = useState(false);
  const [showHelpDropdown, setShowHelpDropdown] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [searchLoading, setSearchLoading] = useState(false);
  const [isProfileComplete, setIsProfileComplete] = useState(false);

  useEffect(() => {
    if (user && profile) {
      // Force reload all counts when profile changes
      loadUnreadCount();
      loadUnreadMessageCount();
      checkProfileCompletion();

      const notificationsCleanup = subscribeToNotifications();
      const messagesCleanup = subscribeToMessages();
      let cartCleanup: (() => void) | undefined;

      if (profile?.user_type === 'client') {
        loadCartCount();
        cartCleanup = subscribeToCart();
      } else {
        // Reset cart count when not a client
        setCartItemCount(0);
      }

      return () => {
        if (notificationsCleanup) notificationsCleanup();
        if (messagesCleanup) messagesCleanup();
        if (cartCleanup) cartCleanup();
      };
    }
  }, [user?.id, profile?.user_type, profile?.id]);

  const checkProfileCompletion = async () => {
    if (!user || !profile) {
      setIsProfileComplete(false);
      return;
    }

    try {
      if (profile.user_type === 'picker') {
        const { data: pickerProfile } = await supabase
          .from('picker_profiles')
          .select('full_name, bio, avatar_url, current_location, regions, specialties')
          .eq('user_id', user.id)
          .maybeSingle();

        const { data: payoutInfo } = await supabase
          .from('picker_payout_info')
          .select('id')
          .eq('picker_id', user.id)
          .maybeSingle();

        const hasBasicInfo = pickerProfile?.full_name && pickerProfile?.bio && pickerProfile?.avatar_url;
        const hasPickerInfo = pickerProfile?.current_location &&
                            pickerProfile?.regions?.length > 0 &&
                            pickerProfile?.specialties?.length > 0;
        const hasPayoutInfo = !!payoutInfo;

        setIsProfileComplete(!!(hasBasicInfo && hasPickerInfo && hasPayoutInfo));
      } else {
        const hasBasicInfo = profile.full_name && profile.bio && profile.avatar_url;
        const hasDeliveryAddress = profile.default_delivery_address &&
                                   profile.default_delivery_address.trim().split('\n').filter(Boolean).length >= 5;

        setIsProfileComplete(!!(hasBasicInfo && hasDeliveryAddress));
      }
    } catch (error) {
      setIsProfileComplete(false);
    }
  };

  // Refresh unread count when navigating away from messages
  useEffect(() => {
    if (currentView !== 'messages') {
      loadUnreadMessageCount();
    }
  }, [currentView]);

  // Refresh unread count when navigating away from notifications
  useEffect(() => {
    if (currentView !== 'notifications') {
      loadUnreadCount();
    }
  }, [currentView]);

  useEffect(() => {
    const searchDebounce = setTimeout(() => {
      if (searchQuery.trim().length >= 2) {
        performSearch();
      } else {
        setSearchResults([]);
        setShowSearchResults(false);
      }
    }, 300);

    return () => clearTimeout(searchDebounce);
  }, [searchQuery]);

  const performSearch = async () => {
    setSearchLoading(true);
    try {
      const results: any[] = [];

      // Search listings
      const { data: listings } = await supabase
        .from('listings')
        .select('*, profiles(full_name, avatar_url)')
        .or(`title.ilike.%${searchQuery}%,description.ilike.%${searchQuery}%,location.ilike.%${searchQuery}%`)
        .eq('status', 'active')
        .limit(5);

      if (listings) {
        results.push(...listings.map(l => ({ ...l, type: 'listing' })));
      }

      // Search pickers (only if user is a client)
      if (profile?.user_type === 'client') {
        const { data: pickers } = await supabase
          .from('profiles')
          .select('*, picker_profiles(*)')
          .eq('user_type', 'picker')
          .neq('id', user?.id || '') // Exclude current user's picker profile
          .or(`full_name.ilike.%${searchQuery}%,bio.ilike.%${searchQuery}%`)
          .limit(5);

        if (pickers) {
          results.push(...pickers.map(p => ({ ...p, type: 'picker' })));
        }
      }

      setSearchResults(results);
      setShowSearchResults(true);
    } catch (error) {
    } finally {
      setSearchLoading(false);
    }
  };

  const loadUnreadCount = async () => {
    if (!user) {
      console.log('⚠️ No user, skipping unread notification count');
      return;
    }

    try {
      console.log('🔔 Loading unread notification count for user:', user.id);

      const { count, error } = await supabase
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('read', false)
        .not('type', 'in', '(new_message,message)');

      if (error) throw error;
      const newCount = count || 0;
      setUnreadCount(newCount);
      console.log(`🔔 Unread notifications: ${newCount}`);
    } catch (error) {
      console.error('❌ Error loading unread notification count:', error);
    }
  };

  const loadUnreadMessageCount = async () => {
    if (!user) {
      console.log('⚠️ No user, skipping unread message count');
      return;
    }

    try {
      console.log('🔍 Loading unread message count for user:', user.id);

      // Get all conversations where user is a participant
      const { data: conversations, error: convError } = await supabase
        .from('conversations')
        .select('id')
        .or(`client_id.eq.${user.id},picker_id.eq.${user.id}`);

      if (convError) throw convError;

      console.log('💬 Found conversations:', conversations?.length || 0);

      if (!conversations || conversations.length === 0) {
        setUnreadMessageCount(0);
        if (onUnreadMessageCountChange) onUnreadMessageCountChange(0);
        console.log('📬 Unread messages: 0 (no conversations)');
        return;
      }

      const conversationIds = conversations.map(c => c.id);

      // Count unread messages in these conversations that weren't sent by the user
      const { count, error } = await supabase
        .from('conversation_messages')
        .select('*', { count: 'exact', head: true })
        .in('conversation_id', conversationIds)
        .neq('sender_id', user.id)
        .eq('read', false);

      if (error) throw error;
      const newCount = count || 0;
      setUnreadMessageCount(newCount);
      if (onUnreadMessageCountChange) onUnreadMessageCountChange(newCount);
      console.log(`📬 Unread messages: ${newCount}`);
    } catch (error) {
      console.error('❌ Error loading unread message count:', error);
    }
  };

  const loadCartCount = async () => {
    if (!user) return;

    try {
      const { count, error } = await supabase
        .from('cart_items')
        .select('*', { count: 'exact', head: true })
        .eq('client_id', user.id);

      if (error) throw error;
      setCartItemCount(count || 0);
    } catch (error) {
    }
  };

  const subscribeToCart = () => {
    if (!user) return;

    const channel = supabase
      .channel('cart_header')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'cart_items',
          filter: `client_id=eq.${user.id}`,
        },
        () => {
          loadCartCount();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const subscribeToNotifications = () => {
    if (!user) return;

    const channel = supabase
      .channel('notifications_header')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`,
        },
        () => {
          loadUnreadCount();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const subscribeToMessages = () => {
    if (!user) return;

    // Subscribe to message events and notification events for new messages
    const channel = supabase
      .channel('messages_header')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'conversation_messages',
        },
        (payload) => {
          console.log('📩 New message received:', payload);
          // Immediately update unread count
          setTimeout(() => {
            loadUnreadMessageCount();
          }, 200);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'conversation_messages',
        },
        (payload) => {
          console.log('📝 Message updated:', payload);
          loadUnreadMessageCount();
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
        },
        (payload: any) => {
          // Only react to notifications for this user
          if (payload.new.user_id === user.id && payload.new.type === 'new_message') {
            console.log('🔔 New message notification received for current user:', payload);
            // Immediately update unread count when notification is created
            loadUnreadMessageCount();
          }
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('✅ Subscribed to message updates and notifications');
        }
      });

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const handleQuickSwitch = async () => {
    if (!user || switching) {
      return;
    }

    const currentType = profile?.user_type;
    const newType = currentType === 'picker' ? 'client' : 'picker';

    setSwitching(true);

    try {
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ user_type: newType })
        .eq('id', user.id);

      if (updateError) {
        throw updateError;
      }

      if (newType === 'picker') {
        const { data: existingPicker } = await supabase
          .from('picker_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

        if (!existingPicker) {
          console.log('Creating picker profile...');
          const { data: newPicker, error: pickerError } = await supabase
            .from('picker_profiles')
            .insert({ user_id: user.id })
            .select()
            .single();

          if (pickerError) {
            console.error('Failed to create picker profile:', pickerError);
            throw pickerError;
          }

          console.log('Picker profile created:', newPicker.id);

          // Wait a moment for the database to fully commit
          await new Promise(resolve => setTimeout(resolve, 500));
        }
      }

      await refreshProfile();

      // Wait for the profile state to update
      await new Promise(resolve => setTimeout(resolve, 300));

      onViewChange('home');
    } catch (error) {
      console.error('Mode switch error:', error);
      alert(`Failed to switch mode: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setSwitching(false);
    }
  };

  return (
    <header className="bg-white border-b border-gray-200 sticky top-0 z-50 w-full">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 gap-2 sm:gap-4">
          <div className="flex items-center flex-shrink-0 gap-2">
            {currentView !== 'home' && (
              <button
                onClick={() => onGoBack ? onGoBack() : onViewChange('home')}
                className="p-2 rounded-lg hover:bg-gray-100 text-gray-700 transition-colors"
                title="Go Back"
              >
                <ArrowLeft className="w-5 h-5" />
              </button>
            )}
            <button
              onClick={() => onMobileMenuChange?.(!showMobileMenu)}
              className="lg:hidden p-2 rounded-lg hover:bg-gray-100 text-gray-700 transition-colors"
            >
              {showMobileMenu ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
            <button
              onClick={() => onViewChange('home')}
              className="flex items-center gap-1 sm:gap-2 text-lg sm:text-xl font-bold text-gray-900 hover:text-blue-600 transition-colors"
            >
              <Globe className="w-6 h-6 sm:w-7 sm:h-7" />
              <span className="hidden sm:inline">SouvenirPickers</span>
              <span className="sm:hidden">SP</span>
            </button>

          </div>

          <div className="flex-1 max-w-2xl mx-2 sm:mx-4 lg:mx-8 relative">
            <div className="relative">
              <input
                type="text"
                placeholder={profile?.user_type === 'picker' ? 'Search...' : 'Search...'}
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => searchResults.length > 0 && setShowSearchResults(true)}
                onBlur={() => setTimeout(() => setShowSearchResults(false), 200)}
                className="w-full pl-3 sm:pl-4 pr-10 sm:pr-12 py-2 sm:py-2.5 rounded-full border-2 border-gray-200 focus:border-blue-500 focus:outline-none text-xs sm:text-sm transition-colors"
              />
              <button className="absolute right-1 sm:right-2 top-1/2 transform -translate-y-1/2 bg-blue-500 hover:bg-blue-600 text-white rounded-full p-1.5 sm:p-2 transition-colors">
                <Search className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
              </button>
              {searchLoading && (
                <div className="absolute right-12 sm:right-14 top-1/2 transform -translate-y-1/2">
                  <div className="w-3.5 h-3.5 sm:w-4 sm:h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                </div>
              )}
            </div>

            {showSearchResults && searchResults.length > 0 && (
              <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-xl border border-gray-200 max-h-96 overflow-y-auto z-50">
                {searchResults.map((result, idx) => (
                  <button
                    key={idx}
                    onClick={() => {
                      if (result.type === 'listing') {
                        onViewChange('listings');
                      } else if (result.type === 'picker') {
                        onViewChange('pickers');
                      }
                      setSearchQuery('');
                      setShowSearchResults(false);
                    }}
                    className="w-full px-4 py-3 hover:bg-gray-50 transition-colors flex items-center gap-3 border-b border-gray-100 last:border-0"
                  >
                    {result.type === 'listing' ? (
                      <>
                        <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-green-500 rounded-lg flex items-center justify-center flex-shrink-0">
                          <Package className="w-6 h-6 text-white" />
                        </div>
                        <div className="flex-1 text-left">
                          <div className="font-semibold text-gray-900">{result.title}</div>
                          <div className="text-sm text-gray-600 flex items-center gap-1">
                            <MapPin className="w-3 h-3" />
                            {result.location}
                          </div>
                        </div>
                        <div className="text-right">
                          <div className="font-bold text-blue-600">€{result.price}</div>
                          {result.profiles?.full_name && (
                            <div className="text-xs text-gray-500">{result.profiles.full_name}</div>
                          )}
                        </div>
                      </>
                    ) : (
                      <>
                        <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-blue-500 rounded-full flex items-center justify-center flex-shrink-0 text-white font-bold">
                          {result.full_name?.charAt(0).toUpperCase() || 'P'}
                        </div>
                        <div className="flex-1 text-left">
                          <div className="font-semibold text-gray-900">{result.full_name}</div>
                          <div className="text-sm text-gray-600 flex items-center gap-1">
                            <Star className="w-3 h-3 text-yellow-500 fill-yellow-500" />
                            {result.picker_profiles?.[0]?.rating?.toFixed(1) || 'New'}
                            {result.picker_profiles?.[0]?.location && (
                              <span className="ml-2 flex items-center gap-1">
                                <MapPin className="w-3 h-3" />
                                {result.picker_profiles[0].location}
                              </span>
                            )}
                          </div>
                        </div>
                      </>
                    )}
                  </button>
                ))}
              </div>
            )}

            {showSearchResults && searchResults.length === 0 && searchQuery.length >= 2 && !searchLoading && (
              <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-xl border border-gray-200 p-8 text-center z-50">
                <Search className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                <p className="text-gray-500 font-medium">No results found for "{searchQuery}"</p>
                <p className="text-sm text-gray-400 mt-1">Try searching for something else</p>
              </div>
            )}
          </div>

          <div className="flex items-center gap-1 sm:gap-3">
            {/* Mode Toggle */}
            {profile?.user_type && (
              <button
                onClick={handleQuickSwitch}
                disabled={switching}
                title={`Switch to ${profile.user_type === 'picker' ? 'Collector' : 'Picker'} mode`}
                className="flex items-center gap-1 rounded-full border border-gray-200 bg-gray-100 p-1 transition-all duration-200 hover:shadow-md disabled:opacity-50"
              >
                <span
                  className={`flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold transition-all duration-200 ${
                    profile.user_type === 'picker'
                      ? 'bg-green-500 text-white shadow-sm'
                      : 'text-gray-400'
                  }`}
                >
                  <Package className="w-3.5 h-3.5" />
                  <span className="hidden sm:inline">Picker</span>
                </span>
                <span
                  className={`flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold transition-all duration-200 ${
                    profile.user_type === 'client'
                      ? 'bg-blue-500 text-white shadow-sm'
                      : 'text-gray-400'
                  }`}
                >
                  <ShoppingBag className="w-3.5 h-3.5" />
                  <span className="hidden sm:inline">Collector</span>
                </span>
                {switching && (
                  <RefreshCw className="w-3.5 h-3.5 text-gray-400 animate-spin mx-1" />
                )}
              </button>
            )}
            {profile?.user_type === 'client' && (
              <button
                onClick={() => {
                  onViewChange('cart');
                }}
                className={`relative p-2 rounded-lg transition-colors ${
                  currentView === 'cart'
                    ? 'bg-blue-50 text-blue-600'
                    : 'hover:bg-gray-100 text-gray-700'
                }`}
                title="Shopping Cart"
              >
                <ShoppingBag className="w-5 h-5" />
                {cartItemCount > 0 && (
                  <span className="absolute -top-1 -right-1 bg-green-500 text-white text-xs font-bold w-5 h-5 rounded-full flex items-center justify-center">
                    {cartItemCount > 9 ? '9+' : cartItemCount}
                  </span>
                )}
              </button>
            )}
            <button
              onClick={() => onViewChange('messages')}
              className={`relative p-2 rounded-lg transition-colors ${
                currentView === 'messages'
                  ? 'bg-blue-50 text-blue-600'
                  : 'hover:bg-gray-100 text-gray-700'
              }`}
              title={`Messages${unreadMessageCount > 0 ? ` (${unreadMessageCount} unread)` : ''}`}
            >
              <MessageCircle className="w-5 h-5" />
              {unreadMessageCount > 0 && (
                <span className="absolute -top-1 -right-1 flex items-center justify-center">
                  <span className="absolute bg-red-500 rounded-full w-[22px] h-[22px] animate-ping"></span>
                  <span className="relative bg-red-500 text-white text-xs font-bold min-w-[22px] h-[22px] px-1.5 rounded-full flex items-center justify-center shadow-lg ring-2 ring-white animate-pulse z-10">
                    {unreadMessageCount > 99 ? '99+' : unreadMessageCount}
                  </span>
                </span>
              )}
            </button>
            <button
              onClick={() => onViewChange('notifications')}
              className={`relative p-2 rounded-lg transition-colors ${
                currentView === 'notifications'
                  ? 'bg-blue-50 text-blue-600'
                  : 'hover:bg-gray-100 text-gray-700'
              }`}
              title={`Notifications${unreadCount > 0 ? ` (${unreadCount} unread)` : ''}`}
            >
              <Bell className="w-5 h-5" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 flex items-center justify-center">
                  <span className="absolute bg-red-500 rounded-full w-[22px] h-[22px] animate-ping"></span>
                  <span className="relative bg-red-500 text-white text-xs font-bold min-w-[22px] h-[22px] px-1.5 rounded-full flex items-center justify-center shadow-lg ring-2 ring-white animate-pulse z-10">
                    {unreadCount > 99 ? '99+' : unreadCount}
                  </span>
                </span>
              )}
            </button>
            <div className="relative">
              <button
                onClick={() => setShowUserMenu(!showUserMenu)}
                className="p-2 rounded-lg transition-colors hover:bg-gray-100 text-gray-700 relative"
                title="User Menu"
              >
                <User className="w-5 h-5" />
                {isProfileComplete && (
                  <span className="absolute -top-0.5 -right-0.5 w-3.5 h-3.5 bg-green-500 border-2 border-white rounded-full flex items-center justify-center">
                    <CheckCircle className="w-2.5 h-2.5 text-white fill-current" />
                  </span>
                )}
              </button>

              {showUserMenu && (
                <>
                  <div
                    className="fixed inset-0 z-40"
                    onClick={() => setShowUserMenu(false)}
                  />
                  <div className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-50">
                    <button
                      onClick={() => {
                        setShowUserMenu(false);
                        onViewChange('profile');
                      }}
                      className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors flex items-center justify-between gap-2"
                    >
                      <div className="flex items-center gap-2">
                        <User className="w-4 h-4" />
                        My Profile
                      </div>
                      {isProfileComplete && (
                        <div className="flex items-center gap-1 bg-green-50 text-green-700 px-2 py-0.5 rounded-full border border-green-200">
                          <CheckCircle className="w-3 h-3 fill-green-500 text-white" />
                          <span className="text-xs font-semibold">Complete</span>
                        </div>
                      )}
                    </button>

                    {profile?.user_type === 'picker' && (
                      <button
                        onClick={() => {
                          setShowUserMenu(false);
                          onViewChange('subscription');
                        }}
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors flex items-center gap-2"
                      >
                        <CreditCard className="w-4 h-4" />
                        Subscription
                      </button>
                    )}

                    <button
                      onClick={() => {
                        setShowUserMenu(false);
                        onViewChange('support');
                      }}
                      className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors flex items-center gap-2"
                    >
                      <HelpCircle className="w-4 h-4" />
                      Help
                    </button>

                    <div className="border-t border-gray-200 my-1" />

                    <button
                      onClick={() => {
                        setShowUserMenu(false);
                        signOut();
                      }}
                      className="w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 transition-colors flex items-center gap-2"
                    >
                      <LogOut className="w-4 h-4" />
                      Sign Out
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
