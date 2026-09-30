// import { useState, useEffect, lazy, Suspense } from 'react';
// import { ShoppingBag } from 'lucide-react';
// import { AuthProvider, useAuth } from './contexts/AuthContext';
// import { NotificationProvider } from './contexts/NotificationContext';
// import { ToastProvider } from './contexts/ToastContext';
// import { AuthForm } from './components/AuthForm';
// import { Header } from './components/Header';
// import { Sidebar } from './components/Sidebar';
// import { Footer } from './components/Footer';
// import CookieBanner from './components/CookieBanner';

// const HomeView = lazy(() => import('./components/HomeView').then(module => ({ default: module.HomeView })));
// const ProfileView = lazy(() => import('./components/ProfileView').then(module => ({ default: module.ProfileView })));
// const RequestsView = lazy(() => import('./components/RequestsView').then(module => ({ default: module.RequestsView })));
// const ListingsView = lazy(() => import('./components/ListingsView').then(module => ({ default: module.ListingsView })));
// const PickersView = lazy(() => import('./components/PickersView').then(module => ({ default: module.PickersView })));
// const CollectorsView = lazy(() => import('./components/CollectorsView').then(module => ({ default: module.CollectorsView })));
// const DesiresView = lazy(() => import('./components/DesiresView').then(module => ({ default: module.DesiresView })));
// const SubscriptionView = lazy(() => import('./components/SubscriptionView').then(module => ({ default: module.SubscriptionView })));
// const RealTimeChat = lazy(() => import('./components/RealTimeChat').then(module => ({ default: module.RealTimeChat })));
// const OrdersView = lazy(() => import('./components/OrdersView').then(module => ({ default: module.OrdersView })));
// const AnalyticsDashboard = lazy(() => import('./components/AnalyticsDashboard').then(module => ({ default: module.AnalyticsDashboard })));
// const NotificationSettings = lazy(() => import('./components/NotificationSettings').then(module => ({ default: module.NotificationSettings })));
// const NotificationsView = lazy(() => import('./components/NotificationsView').then(module => ({ default: module.NotificationsView })));
// const RecommendationsView = lazy(() => import('./components/RecommendationsView').then(module => ({ default: module.RecommendationsView })));
// const ReferralProgram = lazy(() => import('./components/ReferralProgram').then(module => ({ default: module.ReferralProgram })));
// const CartView = lazy(() => import('./components/CartView').then(module => ({ default: module.CartView })));
// const FAQView = lazy(() => import('./components/FAQView').then(module => ({ default: module.FAQView })));
// const SocialFeedView = lazy(() => import('./components/SocialFeedView'));
// const LiveStreamingView = lazy(() => import('./components/LiveStreamingView'));
// const CustomOrdersView = lazy(() => import('./components/CustomOrdersView').then(module => ({ default: module.CustomOrdersView })));
// const RevenueBoosters = lazy(() => import('./components/RevenueBoosters').then(module => ({ default: module.RevenueBoosters })));
// const EarningsView = lazy(() => import('./components/EarningsView'));
// const SupportView = lazy(() => import('./components/SupportView').then(module => ({ default: module.SupportView })));
// const MatchedPickersView = lazy(() => import('./components/MatchedPickersView'));
// const CollectionsView = lazy(() => import('./components/CollectionsView'));
// const LocationAlertsView = lazy(() => import('./components/LocationAlertsView'));
// const IdentityVerificationView = lazy(() => import('./components/IdentityVerificationView'));
// const TrustScoreView = lazy(() => import('./components/TrustScoreView'));
// const DisputesView = lazy(() => import('./components/DisputesView'));
// const SafetyReportingView = lazy(() => import('./components/SafetyReportingView'));
// const DiscoverView = lazy(() => import('./components/DiscoverView').then(module => ({ default: module.DiscoverView })));
// const WishlistView = lazy(() => import('./components/WishlistView').then(module => ({ default: module.WishlistView })));
// const ResetPasswordView = lazy(() => import('./components/ResetPasswordView').then(module => ({ default: module.ResetPasswordView })));
// const AccountRecoverySettings = lazy(() => import('./components/AccountRecoverySettings').then(module => ({ default: module.AccountRecoverySettings })));
// const AdminPasswordResets = lazy(() => import('./components/AdminPasswordResets').then(module => ({ default: module.AdminPasswordResets })));
// const AdminAnalyticsDashboard = lazy(() => import('./components/AdminAnalyticsDashboard').then(module => ({ default: module.AdminAnalyticsDashboard })));
// const PrivacyPolicyView = lazy(() => import('./components/PrivacyPolicyView').then(module => ({ default: module.PrivacyPolicyView })));
// const TermsOfServiceView = lazy(() => import('./components/TermsOfServiceView').then(module => ({ default: module.TermsOfServiceView })));
// const CookiePolicyView = lazy(() => import('./components/CookiePolicyView'));

// function AppContent() {
//   const { user, loading, profile } = useAuth();
//   const [currentView, setCurrentView] = useState('home');
//   const [viewHistory, setViewHistory] = useState<string[]>(['home']);
//   const [messagePickerId, setMessagePickerId] = useState<string | null>(null);
//   const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
//   const [unreadMessageCount, setUnreadMessageCount] = useState(0);
//   const [showMobileMenu, setShowMobileMenu] = useState(false);
//   const [isPasswordReset, setIsPasswordReset] = useState(false);

//   const isPicker = profile?.user_type === 'picker';
//   const isCollector = profile?.user_type === 'client';

//   const pickerOnlyViews = ['analytics', 'earnings', 'revenue-boosters', 'collectors'];
//   const collectorOnlyViews = ['discover', 'wishlist', 'pickers', 'matched-pickers', 'collections', 'location-alerts', 'cart'];
//   const sharedViews = ['home', 'profile', 'listings', 'orders', 'order-tracking', 'custom-orders', 'messages', 'notifications',
//                        'referrals', 'faq', 'support', 'social-feed', 'live-streams', 'verification',
//                        'trust-score', 'disputes', 'safety', 'account-recovery', 'subscription', 'requests',
//                        'privacy', 'terms', 'cookie-policy', 'desires'];

//   const hasAccess =
//     sharedViews.includes(currentView) ||
//     (isPicker && pickerOnlyViews.includes(currentView)) ||
//     (isCollector && collectorOnlyViews.includes(currentView)) ||
//     (profile?.is_admin && (currentView === 'admin-resets' || currentView === 'admin-analytics'));

//   // Check for password reset flow
//   useEffect(() => {
//     const checkPasswordReset = () => {
//       const hashParams = new URLSearchParams(window.location.hash.substring(1));
//       const urlParams = new URLSearchParams(window.location.search);
//       const type = hashParams.get('type') || urlParams.get('type');

//       // Only show password reset view if explicitly recovery type
//       // Do NOT show for signup, magiclink, or other auth types
//       const isRecovery = type === 'recovery' || window.location.pathname === '/reset-password';

//       setIsPasswordReset(isRecovery);
//     };

//     checkPasswordReset();

//     window.addEventListener('hashchange', checkPasswordReset);
//     return () => window.removeEventListener('hashchange', checkPasswordReset);
//   }, []);

//   // Hide loading screen when app is ready
//   useEffect(() => {
//     const loader = document.getElementById('loading-screen');
//     if (loader && !loading) {
//       loader.style.display = 'none';
//     }
//   }, [loading]);

//   // Redirect to home if user doesn't have access to current view
//   useEffect(() => {
//     if (user && profile && !hasAccess) {

//       setCurrentView('home');
//     }
//   }, [currentView, profile?.user_type, hasAccess, user, profile]);

//   // Scroll to top when view changes
//   useEffect(() => {
//     window.scrollTo({ top: 0, behavior: 'smooth' });
//   }, [currentView]);

//   // Clear messagePickerId when leaving messages view
//   useEffect(() => {
//     if (currentView !== 'messages' && messagePickerId) {
//       setMessagePickerId(null);
//     }
//   }, [currentView, messagePickerId]);

//   // Handler to change view and optionally set picker ID for messaging or order ID for orders
//   const handleViewChange = (view: string, pickerId?: string, orderId?: string) => {
//     setViewHistory(prev => [...prev, view]);
//     setCurrentView(view);
//     if (pickerId && view === 'messages') {
//       setMessagePickerId(pickerId);
//     }
//     if (orderId && view === 'orders') {
//       setSelectedOrderId(orderId);
//     } else if (view === 'orders' && !orderId) {
//       setSelectedOrderId(null);
//     }
//   };

//   // Handler to go back to previous view
//   const handleGoBack = () => {
//     if (viewHistory.length > 1) {
//       const newHistory = [...viewHistory];
//       newHistory.pop(); // Remove current view
//       const previousView = newHistory[newHistory.length - 1] || 'home';
//       setViewHistory(newHistory);
//       setCurrentView(previousView);
//     } else {
//       setCurrentView('home');
//     }
//   };

//   // Check password reset FIRST, before anything else
//   if (isPasswordReset) {
//     return (
//       <Suspense fallback={
//         <div className="min-h-screen bg-gray-100 flex items-center justify-center">
//           <div className="text-gray-500">Loading reset form...</div>
//         </div>
//       }>
//         <ResetPasswordView />
//       </Suspense>
//     );
//   }

//   if (loading) {
//     return (
//       <div className="min-h-screen bg-gray-100 flex items-center justify-center">
//         <div className="text-center">
//           <div className="text-gray-500 text-lg mb-2">Loading...</div>
//           <div className="text-gray-400 text-sm">Initializing SouvenirPickers</div>
//         </div>
//       </div>
//     );
//   }

//   if (!user) {
//     return <AuthForm />;
//   }

//   if (!profile) {
//     return (
//       <div className="min-h-screen bg-gray-100 flex items-center justify-center">
//         <div className="text-center">
//           <div className="text-gray-500 text-lg mb-2">Loading profile...</div>
//           <div className="text-gray-400 text-sm">Please wait</div>
//         </div>
//       </div>
//     );
//   }

//   return (
//     <div className={`bg-gray-50 flex flex-col ${currentView === 'messages' ? 'h-screen overflow-hidden' : 'min-h-screen'}`}>
//       <Header
//         currentView={currentView}
//         onViewChange={handleViewChange}
//         onGoBack={handleGoBack}
//         onUnreadMessageCountChange={setUnreadMessageCount}
//         showMobileMenu={showMobileMenu}
//         onMobileMenuChange={setShowMobileMenu}
//       />
//       <Sidebar
//         currentView={currentView}
//         onViewChange={handleViewChange}
//         unreadMessageCount={unreadMessageCount}
//         showMobile={showMobileMenu}
//         onClose={() => setShowMobileMenu(false)}
//       />

//       <div className={`lg:ml-64 pt-0 flex-1 min-h-0 ${currentView === 'messages' ? 'overflow-hidden flex flex-col' : ''}`}>
//         <Suspense fallback={
//           <div className="flex items-center justify-center min-h-[400px]">
//             <div className="text-center">
//               <div className="text-gray-500 text-lg mb-2">Loading...</div>
//               <div className="text-gray-400 text-sm">Please wait</div>
//             </div>
//           </div>
//         }>
//           {currentView === 'home' && <HomeView onViewChange={handleViewChange} />}
//           {currentView === 'profile' && <ProfileView />}
//           {currentView === 'requests' && <RequestsView />}
//           {currentView === 'listings' && (
//             <ListingsView
//               key={currentView}
//               onContactPicker={(pickerId) => {
//                 handleViewChange('messages', pickerId);
//               }}
//               onViewChange={handleViewChange}
//             />
//           )}
//           {currentView === 'pickers' && isCollector && (
//             <PickersView
//               onViewChange={handleViewChange}
//               onContactPicker={(pickerId) => {
//                 handleViewChange('messages', pickerId);
//               }}
//             />
//           )}
//           {currentView === 'collectors' && isPicker && <CollectorsView onViewChange={handleViewChange} />}
//           {currentView === 'desires' && <DesiresView onViewChange={handleViewChange} />}
//           {currentView === 'messages' && <RealTimeChat initialPickerId={messagePickerId} />}
//           {currentView === 'orders' && <OrdersView onViewChange={handleViewChange} initialOrderId={selectedOrderId} />}
//           {currentView === 'cart' && (
//             isCollector ? (
//               <CartView />
//             ) : (
//               <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
//                 <div className="text-center bg-yellow-50 border border-yellow-200 rounded-lg p-8">
//                   <ShoppingBag className="w-16 h-16 mx-auto text-yellow-600 mb-4" />
//                   <h2 className="text-2xl font-bold text-gray-900 mb-2">Shopping Cart Only Available in Collector Mode</h2>
//                   <p className="text-gray-600 mb-6">Switch to Collector mode to view your shopping cart and place orders.</p>
//                   <button
//                     onClick={() => handleViewChange('home')}
//                     className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors"
//                   >
//                     Go to Home
//                   </button>
//                 </div>
//               </div>
//             )
//           )}
//           {currentView === 'subscription' && <SubscriptionView />}
//           {currentView === 'notifications' && <NotificationsView onViewChange={handleViewChange} />}
//           {currentView === 'analytics' && isPicker && <AnalyticsDashboard onViewChange={handleViewChange} />}
//           {currentView === 'recommendations' && <RecommendationsView onViewChange={handleViewChange} />}
//           {currentView === 'referrals' && <ReferralProgram />}
//           {currentView === 'faq' && <FAQView onViewChange={handleViewChange} />}
//           {currentView === 'support' && <SupportView />}
//           {currentView === 'social-feed' && <SocialFeedView />}
//           {currentView === 'live-streams' && <LiveStreamingView />}
//           {currentView === 'custom-orders' && <CustomOrdersView />}
//           {currentView === 'revenue-boosters' && isPicker && <RevenueBoosters onViewChange={handleViewChange} />}
//           {currentView === 'earnings' && isPicker && <EarningsView />}
//           {currentView === 'matched-pickers' && isCollector && <MatchedPickersView onViewChange={handleViewChange} />}
//           {currentView === 'collections' && isCollector && <CollectionsView />}
//           {currentView === 'location-alerts' && isCollector && <LocationAlertsView />}
//           {currentView === 'verification' && <IdentityVerificationView />}
//           {currentView === 'trust-score' && <TrustScoreView />}
//           {currentView === 'disputes' && <DisputesView />}
//           {currentView === 'safety' && <SafetyReportingView />}
//           {currentView === 'discover' && isCollector && <DiscoverView onViewChange={handleViewChange} />}
//           {currentView === 'wishlist' && isCollector && <WishlistView onViewChange={handleViewChange} />}
//           {currentView === 'account-recovery' && <AccountRecoverySettings />}
//           {currentView === 'admin-analytics' && profile?.is_admin && <AdminAnalyticsDashboard />}
//           {currentView === 'admin-resets' && profile?.is_admin && <AdminPasswordResets />}
//           {currentView === 'privacy' && <PrivacyPolicyView />}
//           {currentView === 'terms' && <TermsOfServiceView />}
//           {currentView === 'cookie-policy' && <CookiePolicyView />}
//         </Suspense>
//       </div>

//       {/* {currentView !== 'messages' && (
//         <div className="lg:ml-64">
//           <Footer onViewChange={handleViewChange} />
//         </div>
//       )} */}
// <Footer/>
//       <CookieBanner />
//     </div>
//   );
// }

// function App() {
//   return (
//     <AuthProvider>
//       <NotificationProvider>
//         <ToastProvider>
//           <AppContent />
//         </ToastProvider>
//       </NotificationProvider>
//     </AuthProvider>
//   );
// }

// export default App;

// // Log when app is mounted


import { useState, useEffect, lazy, Suspense } from 'react';
import { ShoppingBag } from 'lucide-react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { NotificationProvider } from './contexts/NotificationContext';
import { ToastProvider } from './contexts/ToastContext';
import { AuthForm } from './components/AuthForm';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { Footer } from './components/Footer';
import CookieBanner from './components/CookieBanner';

const HomeView = lazy(() => import('./components/HomeView').then(module => ({ default: module.HomeView })));
const ProfileView = lazy(() => import('./components/ProfileView').then(module => ({ default: module.ProfileView })));
const RequestsView = lazy(() => import('./components/RequestsView').then(module => ({ default: module.RequestsView })));
const ListingsView = lazy(() => import('./components/ListingsView').then(module => ({ default: module.ListingsView })));
const PickersView = lazy(() => import('./components/PickersView').then(module => ({ default: module.PickersView })));
const CollectorsView = lazy(() => import('./components/CollectorsView').then(module => ({ default: module.CollectorsView })));
const DesiresView = lazy(() => import('./components/DesiresView').then(module => ({ default: module.DesiresView })));
const SubscriptionView = lazy(() => import('./components/SubscriptionView').then(module => ({ default: module.SubscriptionView })));
const RealTimeChat = lazy(() => import('./components/RealTimeChat').then(module => ({ default: module.RealTimeChat })));
const OrdersView = lazy(() => import('./components/OrdersView').then(module => ({ default: module.OrdersView })));
const OrderTrackingView = lazy(() => import('./components/OrderTrackingView').then(module => ({ default: module.OrderTrackingView })));
const AnalyticsDashboard = lazy(() => import('./components/AnalyticsDashboard').then(module => ({ default: module.AnalyticsDashboard })));
const NotificationSettings = lazy(() => import('./components/NotificationSettings').then(module => ({ default: module.NotificationSettings })));
const NotificationsView = lazy(() => import('./components/NotificationsView').then(module => ({ default: module.NotificationsView })));
const RecommendationsView = lazy(() => import('./components/RecommendationsView').then(module => ({ default: module.RecommendationsView })));
const ReferralProgram = lazy(() => import('./components/ReferralProgram').then(module => ({ default: module.ReferralProgram })));
const CartView = lazy(() => import('./components/CartView').then(module => ({ default: module.CartView })));
const FAQView = lazy(() => import('./components/FAQView').then(module => ({ default: module.FAQView })));
const SocialFeedView = lazy(() => import('./components/SocialFeedView'));
const LiveStreamingView = lazy(() => import('./components/LiveStreamingView'));
const CustomOrdersView = lazy(() => import('./components/CustomOrdersView').then(module => ({ default: module.CustomOrdersView })));
const RevenueBoosters = lazy(() => import('./components/RevenueBoosters').then(module => ({ default: module.RevenueBoosters })));
const EarningsView = lazy(() => import('./components/EarningsView'));
const SupportView = lazy(() => import('./components/SupportView').then(module => ({ default: module.SupportView })));
const MatchedPickersView = lazy(() => import('./components/MatchedPickersView'));
const CollectionsView = lazy(() => import('./components/CollectionsView'));
const LocationAlertsView = lazy(() => import('./components/LocationAlertsView'));
const IdentityVerificationView = lazy(() => import('./components/IdentityVerificationView'));
const TrustScoreView = lazy(() => import('./components/TrustScoreView'));
const DisputesView = lazy(() => import('./components/DisputesView'));
const SafetyReportingView = lazy(() => import('./components/SafetyReportingView'));
const DiscoverView = lazy(() => import('./components/DiscoverView').then(module => ({ default: module.DiscoverView })));
const WishlistView = lazy(() => import('./components/WishlistView').then(module => ({ default: module.WishlistView })));
const ResetPasswordView = lazy(() => import('./components/ResetPasswordView').then(module => ({ default: module.ResetPasswordView })));
const AccountRecoverySettings = lazy(() => import('./components/AccountRecoverySettings').then(module => ({ default: module.AccountRecoverySettings })));
const AdminPasswordResets = lazy(() => import('./components/AdminPasswordResets').then(module => ({ default: module.AdminPasswordResets })));
const AdminAnalyticsDashboard = lazy(() => import('./components/AdminAnalyticsDashboard').then(module => ({ default: module.AdminAnalyticsDashboard })));
const PrivacyPolicyView = lazy(() => import('./components/PrivacyPolicyView').then(module => ({ default: module.PrivacyPolicyView })));
const TermsOfServiceView = lazy(() => import('./components/TermsOfServiceView').then(module => ({ default: module.TermsOfServiceView })));
const CookiePolicyView = lazy(() => import('./components/CookiePolicyView'));

function AppContent() {
  const { user, loading, profile } = useAuth();
  const [currentView, setCurrentView] = useState('home');
  const [viewHistory, setViewHistory] = useState<string[]>(['home']);
  const [messagePickerId, setMessagePickerId] = useState<string | null>(null);
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null);
  const [unreadMessageCount, setUnreadMessageCount] = useState(0);
  const [showMobileMenu, setShowMobileMenu] = useState(false);
  const [isPasswordReset, setIsPasswordReset] = useState(false);

  const isPicker = profile?.user_type === 'picker';
  const isCollector = profile?.user_type === 'client';

  const pickerOnlyViews = ['analytics', 'earnings', 'revenue-boosters', 'collectors'];
  const collectorOnlyViews = ['discover', 'wishlist', 'pickers', 'matched-pickers', 'collections', 'location-alerts', 'cart'];
  const sharedViews = ['home', 'profile', 'listings', 'orders', 'order-tracking', 'custom-orders', 'messages', 'notifications',
                       'referrals', 'faq', 'support', 'social-feed', 'live-streams', 'verification',
                       'trust-score', 'disputes', 'safety', 'account-recovery', 'subscription', 'requests',
                       'privacy', 'terms', 'cookie-policy', 'desires'];

  const hasAccess =
    sharedViews.includes(currentView) ||
    (isPicker && pickerOnlyViews.includes(currentView)) ||
    (isCollector && collectorOnlyViews.includes(currentView)) ||
    (profile?.is_admin && (currentView === 'admin-resets' || currentView === 'admin-analytics'));

  useEffect(() => {
    const checkPasswordReset = () => {
      const hashParams = new URLSearchParams(window.location.hash.substring(1));
      const urlParams = new URLSearchParams(window.location.search);
      const type = hashParams.get('type') || urlParams.get('type');
      const isRecovery = type === 'recovery' || window.location.pathname === '/reset-password';
      setIsPasswordReset(isRecovery);
    };

    checkPasswordReset();
    window.addEventListener('hashchange', checkPasswordReset);
    return () => window.removeEventListener('hashchange', checkPasswordReset);
  }, []);

  useEffect(() => {
    const loader = document.getElementById('loading-screen');
    if (loader && !loading) {
      loader.style.display = 'none';
    }
  }, [loading]);

  useEffect(() => {
    if (user && profile && !hasAccess) {
      setCurrentView('home');
    }
  }, [currentView, profile?.user_type, hasAccess, user, profile]);

  useEffect(() => {
    document.getElementById('main-scroll-area')?.scrollTo({ top: 0, behavior: 'smooth' });
  }, [currentView]);

  useEffect(() => {
    if (currentView !== 'messages' && messagePickerId) {
      setMessagePickerId(null);
    }
  }, [currentView, messagePickerId]);

  const handleViewChange = (view: string, pickerId?: string, orderId?: string) => {
    setViewHistory(prev => [...prev, view]);
    setCurrentView(view);
    if (pickerId && view === 'messages') {
      setMessagePickerId(pickerId);
    }
    if (orderId && (view === 'orders' || view === 'order-tracking')) {
      setSelectedOrderId(orderId);
    } else if (view === 'orders' || view === 'order-tracking') {
      setSelectedOrderId(null);
    }
  };

  const handleGoBack = () => {
    if (viewHistory.length > 1) {
      const newHistory = [...viewHistory];
      newHistory.pop();
      const previousView = newHistory[newHistory.length - 1] || 'home';
      setViewHistory(newHistory);
      setCurrentView(previousView);
    } else {
      setCurrentView('home');
    }
  };

  if (isPasswordReset) {
    return (
      <Suspense fallback={
        <div className="min-h-screen bg-gray-100 flex items-center justify-center">
          <div className="text-gray-500">Loading reset form...</div>
        </div>
      }>
        <ResetPasswordView />
      </Suspense>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="text-gray-500 text-lg mb-2">Loading...</div>
          <div className="text-gray-400 text-sm">Initializing SouvenirPickers</div>
        </div>
      </div>
    );
  }

  if (!user) {
    return <AuthForm />;
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="text-gray-500 text-lg mb-2">Loading profile...</div>
          <div className="text-gray-400 text-sm">Please wait</div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-gray-50 flex flex-col h-screen overflow-hidden">
      <Header
        currentView={currentView}
        onViewChange={handleViewChange}
        onGoBack={handleGoBack}
        onUnreadMessageCountChange={setUnreadMessageCount}
        showMobileMenu={showMobileMenu}
        onMobileMenuChange={setShowMobileMenu}
      />

      {/* Flex row: sidebar + content side by side */}
      <div className="flex flex-1 min-h-0">
        <Sidebar
          currentView={currentView}
          onViewChange={handleViewChange}
          unreadMessageCount={unreadMessageCount}
          showMobile={showMobileMenu}
          onClose={() => setShowMobileMenu(false)}
        />

        <div id="main-scroll-area" className="flex-1 min-w-0 flex flex-col overflow-y-auto [&>*:first-child]:w-full">
          <Suspense fallback={
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 w-full">
              <div className="flex items-center justify-center min-h-[400px]">
                <div className="text-center">
                  <div className="text-gray-500 text-lg mb-2">Loading...</div>
                  <div className="text-gray-400 text-sm">Please wait</div>
                </div>
              </div>
            </div>
          }>
            {currentView === 'home' && <HomeView onViewChange={handleViewChange} />}
            {currentView === 'profile' && <ProfileView />}
            {currentView === 'requests' && <RequestsView />}
            {currentView === 'listings' && (
              <ListingsView
                key={currentView}
                onContactPicker={(pickerId) => {
                  handleViewChange('messages', pickerId);
                }}
                onViewChange={handleViewChange}
              />
            )}
            {currentView === 'pickers' && isCollector && (
              <PickersView
                onViewChange={handleViewChange}
                onContactPicker={(pickerId) => {
                  handleViewChange('messages', pickerId);
                }}
              />
            )}
            {currentView === 'collectors' && isPicker && <CollectorsView onViewChange={handleViewChange} />}
            {currentView === 'desires' && <DesiresView onViewChange={handleViewChange} />}
            {currentView === 'messages' && <RealTimeChat initialPickerId={messagePickerId} />}
            {currentView === 'orders' && <OrdersView onViewChange={handleViewChange} initialOrderId={selectedOrderId} />}
            {currentView === 'order-tracking' && <OrderTrackingView orderId={selectedOrderId} />}
            {currentView === 'cart' && (
              isCollector ? (
                <CartView />
              ) : (
                <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
                  <div className="text-center bg-yellow-50 border border-yellow-200 rounded-lg p-8">
                    <ShoppingBag className="w-16 h-16 mx-auto text-yellow-600 mb-4" />
                    <h2 className="text-2xl font-bold text-gray-900 mb-2">Shopping Cart Only Available in Collector Mode</h2>
                    <p className="text-gray-600 mb-6">Switch to Collector mode to view your shopping cart and place orders.</p>
                    <button
                      onClick={() => handleViewChange('home')}
                      className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors"
                    >
                      Go to Home
                    </button>
                  </div>
                </div>
              )
            )}
            {currentView === 'subscription' && <SubscriptionView />}
            {currentView === 'notifications' && <NotificationsView onViewChange={handleViewChange} />}
            {currentView === 'analytics' && isPicker && <AnalyticsDashboard onViewChange={handleViewChange} />}
            {currentView === 'recommendations' && <RecommendationsView onViewChange={handleViewChange} />}
            {currentView === 'referrals' && <ReferralProgram />}
            {currentView === 'faq' && <FAQView onViewChange={handleViewChange} />}
            {currentView === 'support' && <SupportView />}
            {currentView === 'social-feed' && <SocialFeedView />}
            {currentView === 'live-streams' && <LiveStreamingView />}
            {currentView === 'custom-orders' && <CustomOrdersView />}
            {currentView === 'revenue-boosters' && isPicker && <RevenueBoosters onViewChange={handleViewChange} />}
            {currentView === 'earnings' && isPicker && <EarningsView />}
            {currentView === 'matched-pickers' && isCollector && <MatchedPickersView onViewChange={handleViewChange} />}
            {currentView === 'collections' && isCollector && <CollectionsView />}
            {currentView === 'location-alerts' && isCollector && <LocationAlertsView />}
            {currentView === 'verification' && <IdentityVerificationView />}
            {currentView === 'trust-score' && <TrustScoreView />}
            {currentView === 'disputes' && <DisputesView />}
            {currentView === 'safety' && <SafetyReportingView />}
            {currentView === 'discover' && isCollector && <DiscoverView onViewChange={handleViewChange} />}
            {currentView === 'wishlist' && isCollector && <WishlistView onViewChange={handleViewChange} />}
            {currentView === 'account-recovery' && <AccountRecoverySettings />}
            {currentView === 'admin-analytics' && profile?.is_admin && <AdminAnalyticsDashboard />}
            {currentView === 'admin-resets' && profile?.is_admin && <AdminPasswordResets />}
            {currentView === 'privacy' && <PrivacyPolicyView />}
            {currentView === 'terms' && <TermsOfServiceView />}
            {currentView === 'cookie-policy' && <CookiePolicyView />}
          </Suspense>

          {currentView === 'home' && <Footer />}
        </div>
      </div>

      <CookieBanner />
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <NotificationProvider>
        <ToastProvider>
          <AppContent />
        </ToastProvider>
      </NotificationProvider>
    </AuthProvider>
  );
}

export default App;
