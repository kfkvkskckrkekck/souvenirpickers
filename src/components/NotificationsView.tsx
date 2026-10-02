import { useState, useEffect, type ReactNode } from 'react';
import { Bell, Check, Trash2, ExternalLink, Package, DollarSign, Truck, ShieldCheck, CreditCard, BarChart2, ArrowRight } from 'lucide-react';
import { supabase, Notification } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import SouvenirLoader from './SouvenirLoader';

type NotificationsViewProps = {
  onViewChange?: (view: string, pickerId?: string, orderId?: string) => void;
};

export function NotificationsView({ onViewChange }: NotificationsViewProps) {
  const { user, profile } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'unread'>('all');

  useEffect(() => {
    if (user) {
      loadNotifications();
      subscribeToNotifications();
    }
  }, [user]);

  const loadNotifications = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .not('type', 'in', '(new_message,message)')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setNotifications(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const subscribeToNotifications = () => {
    if (!user) return;

    const channel = supabase
      .channel('notifications')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`,
        },
        () => {
          loadNotifications();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const markAsRead = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ read: true })
        .eq('id', notificationId);

      if (error) throw error;
      loadNotifications();
    } catch (error) {

    }
  };

  const markAllAsRead = async () => {
    if (!user) return;

    try {
      const { error } = await supabase
        .from('notifications')
        .update({ read: true })
        .eq('user_id', user.id)
        .eq('read', false);

      if (error) throw error;
      loadNotifications();
    } catch (error) {

    }
  };

  const deleteNotification = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);

      if (error) throw error;
      loadNotifications();
    } catch (error) {

    }
  };

  // Filter notifications based on relevance to user type
  const getRelevantNotifications = () => {
    return notifications.filter((n) => {
      // Exclude message notifications (handled in MessagesView)
      const excludedTypes = ['new_message', 'message'];

      if (excludedTypes.includes(n.type)) return false;

      // Show all other notifications
      return true;
    });
  };

  const relevantNotifications = getRelevantNotifications();

  const filteredNotifications = relevantNotifications.filter((n) =>
    filter === 'unread' ? !n.read : true
  );

  const unreadCount = relevantNotifications.filter((n) => !n.read).length;

  const getOrderId = (notification: Notification): string | undefined => {
    return notification.metadata?.order_id;
  };

  const handleNotificationAction = (notification: Notification, targetView?: string) => {
    markAsRead(notification.id);
    if (!onViewChange) return;

    const view = targetView || getActionView(notification);
    if (view) {
      const orderId = getOrderId(notification);
      onViewChange(view, undefined, orderId);
    }
  };

  const getActionView = (notification: Notification): string | null => {
    const action = notification.metadata?.action || notification.metadata?.action_url;
    const type = notification.type;

    // Map metadata action hints to views
    if (action) {
      if (action === 'confirm_delivery' || action === 'track_shipment') return 'orders';
      if (action === 'prepare_item' || action === 'view_cancelled_order') return 'orders';
      if (action === '/orders' || String(action).includes('order')) return 'orders';
      if (action === 'view_payout' || action === '/earnings') return 'earnings';
    }

    // Map by notification type
    const orderTypes = [
      'order', 'new_order', 'order_placed', 'order_confirmation', 'new_order_picker',
      'payment_required', 'order_status_update',
    ];
    if (orderTypes.includes(type)) return 'orders';
    if (type === 'payment' || type === 'payout_sent' || type === 'payout_failed') return 'earnings';
    if (type === 'custom_order') return 'custom-orders';
    if (type === 'subscription' || type === 'trial_ending') return 'subscription';
    if (type === 'review') return 'orders';

    return null;
  };

  const getNotificationVisual = (type: string): { icon: ReactNode; bg: string; color: string } => {
    const failTypes = ['payout_failed'];
    const moneyTypes = ['payment', 'payout_completed', 'payout_sent', 'payout_initiated'];
    const subTypes = ['subscription', 'trial_ending'];
    const orderTypes = [
      'order', 'new_order', 'new_order_picker', 'order_placed', 'order_confirmation',
      'order_status_update', 'order_shipped', 'delivery_confirmed', 'delivery_confirmed_collector',
      'custom_order', 'payment_required',
    ];

    if (failTypes.includes(type)) return { icon: <CreditCard className="w-5 h-5" />, bg: 'bg-red-50', color: 'text-red-600' };
    if (moneyTypes.includes(type)) return { icon: <DollarSign className="w-5 h-5" />, bg: 'bg-emerald-50', color: 'text-emerald-600' };
    if (subTypes.includes(type)) return { icon: <CreditCard className="w-5 h-5" />, bg: 'bg-amber-50', color: 'text-amber-600' };
    if (orderTypes.includes(type)) return { icon: <Package className="w-5 h-5" />, bg: 'bg-blue-50', color: 'text-blue-600' };
    return { icon: <Bell className="w-5 h-5" />, bg: 'bg-gray-100', color: 'text-gray-500' };
  };

  const getActionButton = (notification: Notification): ReactNode => {
    const action = notification.metadata?.action;
    const actionText = notification.metadata?.action_text;
    const type = notification.type;

    // Build button config from action metadata or notification type
    type ButtonConfig = { label: string; color: string; icon: ReactNode; view: string };
    let config: ButtonConfig | null = null;

    // Metadata-driven actions (highest priority)
    if (action === 'prepare_item') {
      config = { label: 'View Order', color: 'bg-blue-600 hover:bg-blue-700', icon: <Package className="w-3.5 h-3.5" />, view: 'orders' };
    } else if (action === 'track_shipment') {
      config = { label: 'Track Shipment', color: 'bg-blue-600 hover:bg-blue-700', icon: <Truck className="w-3.5 h-3.5" />, view: 'orders' };
    } else if (action === 'confirm_delivery') {
      config = { label: 'Confirm Delivery', color: 'bg-green-600 hover:bg-green-700', icon: <ShieldCheck className="w-3.5 h-3.5" />, view: 'orders' };
    } else if (action === 'view_payout' || (notification.metadata?.action_url === '/earnings')) {
      config = { label: 'View Earnings', color: 'bg-emerald-600 hover:bg-emerald-700', icon: <BarChart2 className="w-3.5 h-3.5" />, view: 'earnings' };
    } else if (action === 'view_cancelled_order') {
      config = { label: 'View Order', color: 'bg-gray-600 hover:bg-gray-700', icon: <Package className="w-3.5 h-3.5" />, view: 'orders' };
    } else if (actionText) {
      // Generic action_text from DB
      const isPayAction = String(actionText).toLowerCase().includes('pay');
      const isConfirmAction = String(actionText).toLowerCase().includes('confirm');
      const isShipAction = String(actionText).toLowerCase().includes('ship');
      const view = notification.metadata?.action_url?.replace('/', '') || 'orders';
      config = {
        label: actionText,
        color: isPayAction ? 'bg-green-600 hover:bg-green-700' : isConfirmAction ? 'bg-green-600 hover:bg-green-700' : isShipAction ? 'bg-blue-600 hover:bg-blue-700' : 'bg-blue-600 hover:bg-blue-700',
        icon: isPayAction ? <DollarSign className="w-3.5 h-3.5" /> : isConfirmAction ? <ShieldCheck className="w-3.5 h-3.5" /> : <Package className="w-3.5 h-3.5" />,
        view,
      };
    }

    // Type-based fallback mapping
    if (!config) {
      const typeMap: Record<string, ButtonConfig> = {
        new_order:               { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        new_order_picker:        { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        order_placed:            { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        order_confirmation:      { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        order_status_update:     { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        order:                   { label: 'View Order',          color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'orders' },
        payment_required:        { label: 'Pay Now',             color: 'bg-green-600 hover:bg-green-700',   icon: <DollarSign className="w-3.5 h-3.5" />,  view: 'orders' },
        payment:                 { label: 'View Earnings',       color: 'bg-emerald-600 hover:bg-emerald-700', icon: <BarChart2 className="w-3.5 h-3.5" />, view: 'earnings' },
        custom_order:            { label: 'View Custom Order',   color: 'bg-blue-600 hover:bg-blue-700',     icon: <Package className="w-3.5 h-3.5" />,    view: 'custom-orders' },
        subscription:            { label: 'Manage Subscription', color: 'bg-blue-600 hover:bg-blue-700',     icon: <CreditCard className="w-3.5 h-3.5" />, view: 'subscription' },
        trial_ending:            { label: 'Upgrade Now',         color: 'bg-amber-500 hover:bg-amber-600',   icon: <CreditCard className="w-3.5 h-3.5" />, view: 'subscription' },
        payout_sent:             { label: 'View Earnings',       color: 'bg-emerald-600 hover:bg-emerald-700', icon: <BarChart2 className="w-3.5 h-3.5" />, view: 'earnings' },
        payout_failed:           { label: 'Update Payout Info',  color: 'bg-red-600 hover:bg-red-700',       icon: <CreditCard className="w-3.5 h-3.5" />, view: 'payout-setup' },
      };
      config = typeMap[type] ?? null;
    }

    if (!config) return null;

    return (
      <button
        onClick={() => handleNotificationAction(notification, config!.view)}
        className={`group/btn inline-flex items-center gap-1.5 px-3 py-1.5 ${config.color} text-white rounded-xl transition-colors text-xs font-semibold shadow-sm`}
      >
        {config.icon}
        {config.label}
        <ArrowRight className="w-3 h-3 group-hover/btn:translate-x-0.5 transition-transform" />
      </button>
    );
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading notifications..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
              <Bell className="w-5 h-5 text-blue-600" />
            </div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900 tracking-tight">Notifications</h2>
              {unreadCount > 0 && (
                <span className="bg-red-500 text-white text-xs font-bold px-2 py-0.5 rounded-full">
                  {unreadCount}
                </span>
              )}
            </div>
          </div>
          {unreadCount > 0 && (
            <button
              onClick={markAllAsRead}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 text-sm font-semibold text-blue-600 hover:bg-blue-50 rounded-xl transition-colors"
            >
              <Check className="w-4 h-4" />
              Mark all as read
            </button>
          )}
        </div>

        <div className="inline-flex gap-1 p-1 bg-gray-100 rounded-xl mb-6">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition-colors ${
              filter === 'all'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            All ({relevantNotifications.length})
          </button>
          <button
            onClick={() => setFilter('unread')}
            className={`px-4 py-1.5 rounded-lg text-sm font-semibold transition-colors ${
              filter === 'unread'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            Unread ({unreadCount})
          </button>
        </div>

        {filteredNotifications.length === 0 ? (
          <div className="text-center py-16">
            <div className="w-16 h-16 rounded-2xl bg-gray-50 flex items-center justify-center mx-auto mb-4">
              <Bell className="w-8 h-8 text-gray-300" />
            </div>
            <p className="text-gray-700 font-semibold">
              {filter === 'unread' ? 'No unread notifications' : 'No notifications yet'}
            </p>
            <p className="text-sm text-gray-400 mt-1">
              {filter === 'unread' ? "You're all caught up" : "We'll let you know when something happens"}
            </p>
          </div>
        ) : (
          <div className="space-y-2.5">
            {filteredNotifications.map((notification) => {
              const visual = getNotificationVisual(notification.type);
              return (
                <div
                  key={notification.id}
                  className={`flex items-start gap-4 p-4 rounded-2xl border transition-all ${
                    notification.read
                      ? 'bg-white border-gray-100 hover:border-gray-200'
                      : 'bg-blue-50/50 border-blue-100 hover:border-blue-200'
                  }`}
                >
                  <div className={`w-10 h-10 rounded-xl ${visual.bg} flex items-center justify-center flex-shrink-0`}>
                    <span className={visual.color}>{visual.icon}</span>
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-0.5">
                      <h3 className="font-semibold text-gray-900 truncate">
                        {notification.title}
                      </h3>
                      {!notification.read && (
                        <span className="w-1.5 h-1.5 bg-blue-600 rounded-full flex-shrink-0"></span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600 mb-2.5 leading-relaxed">{notification.message}</p>
                    <div className="flex items-center flex-wrap gap-3">
                      <p className="text-xs text-gray-400">
                        {new Date(notification.created_at).toLocaleString()}
                      </p>
                      {getActionButton(notification)}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 flex-shrink-0">
                    {notification.link && (
                      <a
                        href={notification.link}
                        className="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="View details"
                      >
                        <ExternalLink className="w-4 h-4" />
                      </a>
                    )}
                    {!notification.read && (
                      <button
                        onClick={() => markAsRead(notification.id)}
                        className="p-2 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                        title="Mark as read"
                      >
                        <Check className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => deleteNotification(notification.id)}
                      className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
