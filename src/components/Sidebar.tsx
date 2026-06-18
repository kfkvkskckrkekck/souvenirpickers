// import { Package, ShoppingBag, Heart, MessageSquare, DollarSign, BarChart3, Users, Radio, TrendingUp, CircleUser as UserCircle, Gift, Lightbulb, ClipboardList, Bell, MapPin, Shield, Settings, UserCog, Activity, CreditCard } from 'lucide-react';
// import { useAuth } from '../contexts/AuthContext';

// type SidebarProps = {
//   currentView: string;
//   onViewChange: (view: string) => void;
//   unreadMessageCount: number;
//   showMobile?: boolean;
//   onClose?: () => void;
// };

// export function Sidebar({ currentView, onViewChange, unreadMessageCount, showMobile, onClose }: SidebarProps) {
//   const { profile } = useAuth();

//   const pickerMenuItems = [
//     { id: 'section-business', label: 'Business', type: 'divider' },
//     { id: 'listings', label: 'My Listings', icon: Package },
//     { id: 'collectors', label: 'Browse Collectors', icon: UserCircle },
//     { id: 'desires', label: 'Client Desires', icon: Heart },
//     { id: 'orders', label: 'Orders', icon: ShoppingBag },
//     { id: 'custom-orders', label: 'Custom Orders', icon: ClipboardList },
//     { id: 'earnings', label: 'Earnings', icon: DollarSign },

//     { id: 'section-growth', label: 'Growth & Marketing', type: 'divider' },
//     { id: 'recommendations', label: 'Recommendations', icon: Lightbulb },
//     { id: 'analytics', label: 'Analytics', icon: BarChart3 },
//     { id: 'revenue-boosters', label: 'Revenue Boosters', icon: TrendingUp },
//     { id: 'referrals', label: 'Referrals', icon: Gift },

//     { id: 'section-community', label: 'Community', type: 'divider' },
//     { id: 'messages', label: 'Messages', icon: MessageSquare, badge: unreadMessageCount },
//     { id: 'live-streams', label: 'Live Streams (Coming Soon)', icon: Radio },
//     { id: 'social-feed', label: 'Social Feed', icon: Users },

//     { id: 'section-account', label: 'Account & Billing', type: 'divider' },
//     { id: 'subscription', label: 'Subscription', icon: CreditCard },
//     { id: 'account-recovery', label: 'Account Recovery', icon: Shield },

//     { id: 'section-settings', label: 'Settings', type: 'divider' },
//     { id: 'profile', label: 'Profile Settings', icon: Settings },
//     { id: 'notifications', label: 'Notification Settings', icon: Bell },
//   ];

//   const collectorMenuItems = [
//     { id: 'section-discovery', label: 'Discovery', type: 'divider' },
//     { id: 'desires', label: 'My Desires', icon: Lightbulb },
//     { id: 'pickers', label: 'Browse Pickers', icon: UserCircle },
//     { id: 'listings', label: 'Browse Listings', icon: Package },
//     { id: 'recommendations', label: 'Recommendations', icon: TrendingUp },

//     { id: 'section-activity', label: 'My Activity', type: 'divider' },
//     { id: 'cart', label: 'Shopping Cart', icon: ShoppingBag },
//     { id: 'collections', label: 'My Collections', icon: Heart },
//     { id: 'orders', label: 'My Orders', icon: Package },
//     { id: 'custom-orders', label: 'Custom Orders', icon: ClipboardList },
//     { id: 'referrals', label: 'Referrals', icon: Gift },

//     { id: 'section-community', label: 'Community', type: 'divider' },
//     { id: 'messages', label: 'Messages', icon: MessageSquare, badge: unreadMessageCount },
//     { id: 'live-streams', label: 'Live Streams (Coming Soon)', icon: Radio },
//     { id: 'social-feed', label: 'Social Feed', icon: Users },

//     { id: 'section-account', label: 'Account', type: 'divider' },
//     { id: 'subscription', label: 'Account Info', icon: UserCircle },
//     { id: 'account-recovery', label: 'Account Recovery', icon: Shield },

//     { id: 'section-settings', label: 'Settings', type: 'divider' },
//     { id: 'profile', label: 'Profile Settings', icon: Settings },
//     { id: 'notifications', label: 'Notification Settings', icon: Bell },
//   ];

//   // Add admin panel for admin users
//   const adminMenuItems = profile?.is_admin ? [
//     { id: 'section-admin', label: 'Admin Panel', type: 'divider' },
//     { id: 'admin-analytics', label: 'Admin Analytics', icon: Activity },
//     { id: 'admin-resets', label: 'Password Resets', icon: UserCog },
//   ] : [];

//   const baseMenuItems = profile?.user_type === 'picker' ? pickerMenuItems : collectorMenuItems;
//   const menuItems = [...baseMenuItems, ...adminMenuItems];

//   return (
//     <>
//       {showMobile && (
//         <div
//           className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-30 top-16"
//           onClick={onClose}
//         />
//       )}
//       <aside className={`fixed left-0 top-16 h-[calc(100vh-4rem)] w-64 bg-white border-r border-gray-200 overflow-y-auto transition-transform duration-300 z-40 ${
//         showMobile ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
//       }`}>
//       <nav className="p-4 space-y-1">
//         {menuItems.map((item) => {
//           if (item.type === 'divider') {
//             return (
//               <div key={item.id} className="pt-4 pb-2">
//                 <p className="text-xs font-bold text-gray-600 uppercase tracking-wider px-4">
//                   {item.label}
//                 </p>
//               </div>
//             );
//           }

//           const Icon = item.icon;
//           const isActive = currentView === item.id;

//           return (
//             <button
//               key={item.id}
//               onClick={() => {
//                 onViewChange(item.id);
//                 onClose?.();
//               }}
//               className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
//                 isActive
//                   ? 'bg-blue-50 text-blue-600'
//                   : 'text-gray-700 hover:bg-gray-100'
//               }`}
//             >
//               <Icon className="w-5 h-5 flex-shrink-0" />
//               <span className="flex-1 text-left">{item.label}</span>
//               {item.badge !== undefined && item.badge > 0 && (
//                 <span className="relative flex items-center justify-center">
//                   <span className="bg-red-500 text-white text-xs font-bold min-w-[24px] h-6 px-2 rounded-full flex items-center justify-center shadow-lg ring-2 ring-white animate-pulse z-10">
//                     {item.badge > 99 ? '99+' : item.badge}
//                   </span>
//                   <span className="absolute bg-red-500 rounded-full w-6 h-6 animate-ping opacity-75"></span>
//                 </span>
//               )}
//             </button>
//           );
//         })}
//       </nav>
//     </aside>
//     </>
//   );
// }


import { Package, ShoppingBag, Heart, MessageSquare, DollarSign, BarChart3, Users, Radio, TrendingUp, CircleUser as UserCircle, Gift, Lightbulb, ClipboardList, Bell, MapPin, Shield, Settings, UserCog, Activity, CreditCard } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

type SidebarProps = {
  currentView: string;
  onViewChange: (view: string) => void;
  unreadMessageCount: number;
  showMobile?: boolean;
  onClose?: () => void;
};

export function Sidebar({ currentView, onViewChange, unreadMessageCount, showMobile, onClose }: SidebarProps) {
  const { profile } = useAuth();

  const pickerMenuItems = [
    { id: 'section-business', label: 'Business', type: 'divider' },
    { id: 'listings', label: 'My Listings', icon: Package },
    { id: 'collectors', label: 'Browse Collectors', icon: UserCircle },
    { id: 'desires', label: 'Client Desires', icon: Heart },
    { id: 'orders', label: 'Orders', icon: ShoppingBag },
    { id: 'custom-orders', label: 'Custom Orders', icon: ClipboardList },
    { id: 'earnings', label: 'Earnings', icon: DollarSign },

    { id: 'section-growth', label: 'Growth & Marketing', type: 'divider' },
    { id: 'recommendations', label: 'Recommendations', icon: Lightbulb },
    { id: 'analytics', label: 'Analytics', icon: BarChart3 },
    { id: 'revenue-boosters', label: 'Revenue Boosters', icon: TrendingUp },
    { id: 'referrals', label: 'Referrals', icon: Gift },

    { id: 'section-community', label: 'Community', type: 'divider' },
    { id: 'messages', label: 'Messages', icon: MessageSquare, badge: unreadMessageCount },
    { id: 'live-streams', label: 'Live Streams (Coming Soon)', icon: Radio },
    { id: 'social-feed', label: 'Social Feed', icon: Users },

    { id: 'section-account', label: 'Account & Billing', type: 'divider' },
    { id: 'subscription', label: 'Subscription', icon: CreditCard },
    { id: 'account-recovery', label: 'Account Recovery', icon: Shield },

    { id: 'section-settings', label: 'Settings', type: 'divider' },
    { id: 'profile', label: 'Profile Settings', icon: Settings },
    { id: 'notifications', label: 'Notification Settings', icon: Bell },
  ];

  const collectorMenuItems = [
    { id: 'section-discovery', label: 'Discovery', type: 'divider' },
    { id: 'desires', label: 'My Desires', icon: Lightbulb },
    { id: 'pickers', label: 'Browse Pickers', icon: UserCircle },
    { id: 'listings', label: 'Browse Listings', icon: Package },
    { id: 'recommendations', label: 'Recommendations', icon: TrendingUp },

    { id: 'section-activity', label: 'My Activity', type: 'divider' },
    { id: 'cart', label: 'Shopping Cart', icon: ShoppingBag },
    { id: 'collections', label: 'My Collections', icon: Heart },
    { id: 'orders', label: 'My Orders', icon: Package },
    { id: 'custom-orders', label: 'Custom Orders', icon: ClipboardList },
    { id: 'referrals', label: 'Referrals', icon: Gift },

    { id: 'section-community', label: 'Community', type: 'divider' },
    { id: 'messages', label: 'Messages', icon: MessageSquare, badge: unreadMessageCount },
    { id: 'live-streams', label: 'Live Streams (Coming Soon)', icon: Radio },
    { id: 'social-feed', label: 'Social Feed', icon: Users },

    { id: 'section-account', label: 'Account', type: 'divider' },
    { id: 'subscription', label: 'Account Info', icon: UserCircle },
    { id: 'account-recovery', label: 'Account Recovery', icon: Shield },

    { id: 'section-settings', label: 'Settings', type: 'divider' },
    { id: 'profile', label: 'Profile Settings', icon: Settings },
    { id: 'notifications', label: 'Notification Settings', icon: Bell },
  ];

  const adminMenuItems = profile?.is_admin ? [
    { id: 'section-admin', label: 'Admin Panel', type: 'divider' },
    { id: 'admin-analytics', label: 'Admin Analytics', icon: Activity },
    { id: 'admin-resets', label: 'Password Resets', icon: UserCog },
  ] : [];

  const baseMenuItems = profile?.user_type === 'picker' ? pickerMenuItems : collectorMenuItems;
  const menuItems = [...baseMenuItems, ...adminMenuItems];

  return (
    <>
      {showMobile && (
        <div
          className="lg:hidden fixed inset-0 bg-black bg-opacity-50 z-30 top-16"
          onClick={onClose}
        />
      )}
      {/* <aside className={`w-64 shrink-0 bg-white border-r border-gray-200 overflow-y-auto transition-transform duration-300 z-40 ${
        showMobile ? 'block' : 'hidden lg:block'
      }`}> */}
      <aside className={`w-64 shrink-0 bg-white border-r border-gray-200 overflow-y-auto transition-all duration-300 z-40 self-stretch ${
  showMobile ? 'block' : 'hidden lg:block'
}`}>
        <nav className="p-4 space-y-1">
          {menuItems.map((item) => {
            if (item.type === 'divider') {
              return (
                <div key={item.id} className="pt-4 pb-2">
                  <p className="text-xs font-bold text-gray-600 uppercase tracking-wider px-4">
                    {item.label}
                  </p>
                </div>
              );
            }

            const Icon = item.icon;
            const isActive = currentView === item.id;

            return (
              <button
                key={item.id}
                onClick={() => {
                  onViewChange(item.id);
                  onClose?.();
                }}
                className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg font-medium transition-all ${
                  isActive
                    ? 'bg-blue-50 text-blue-600'
                    : 'text-gray-700 hover:bg-gray-100'
                }`}
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                <span className="flex-1 text-left">{item.label}</span>
                {item.badge !== undefined && item.badge > 0 && (
                  <span className="relative flex items-center justify-center">
                    <span className="bg-red-500 text-white text-xs font-bold min-w-[24px] h-6 px-2 rounded-full flex items-center justify-center shadow-lg ring-2 ring-white animate-pulse z-10">
                      {item.badge > 99 ? '99+' : item.badge}
                    </span>
                    <span className="absolute bg-red-500 rounded-full w-6 h-6 animate-ping opacity-75"></span>
                  </span>
                )}
              </button>
            );
          })}
        </nav>
      </aside>
    </>
  );
}
