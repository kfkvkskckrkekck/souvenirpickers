import { Globe, Mail, Shield, FileText, Bell } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

type FooterProps = {
  onViewChange: (view: string) => void;
};

export function Footer({ onViewChange }: FooterProps) {
  const { user, profile } = useAuth();
  const currentYear = new Date().getFullYear();
  const isPicker = profile?.user_type === 'picker';

  return (
    <footer className="bg-gray-900 text-gray-300 border-t border-gray-800 w-full">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 lg:gap-8">
          <div className="col-span-1 sm:col-span-2">
            <div className="flex items-center gap-2 mb-3">
              <Globe className="w-5 h-5 sm:w-6 sm:h-6 text-blue-500 flex-shrink-0" />
              <span className="text-lg sm:text-xl font-bold text-white">SouvenirPickers</span>
            </div>
            <p className="text-xs sm:text-sm text-gray-400 mb-3 max-w-md">
              Connect collectors with local pickers worldwide. Discover authentic souvenirs from anywhere on the planet.
            </p>
            <p className="text-xs text-gray-500">
              &copy; {currentYear} SouvenirPickers. All rights reserved.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Company</h3>
            <ul className="space-y-1.5 sm:space-y-2 text-xs sm:text-sm">
              <li>
                <button
                  onClick={() => onViewChange('faq')}
                  className="hover:text-white transition-colors text-left"
                >
                  FAQ
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('support')}
                  className="hover:text-white transition-colors text-left"
                >
                  Support
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('terms')}
                  className="hover:text-white transition-colors text-left"
                >
                  Terms of Service
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('privacy')}
                  className="hover:text-white transition-colors text-left"
                >
                  Privacy Policy
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('cookie-policy')}
                  className="hover:text-white transition-colors text-left"
                >
                  Cookie Policy
                </button>
              </li>
              {isPicker && (
                <li>
                  <button
                    onClick={() => onViewChange('subscription')}
                    className="hover:text-white transition-colors text-left"
                  >
                    Subscription
                  </button>
                </li>
              )}
            </ul>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Trust & Safety</h3>
            <ul className="space-y-1.5 sm:space-y-2 text-xs sm:text-sm">
              <li>
                <button
                  onClick={() => onViewChange('verification')}
                  className="hover:text-white transition-colors flex items-center gap-1.5 text-left"
                >
                  <Shield className="w-3 h-3 sm:w-4 sm:h-4 flex-shrink-0" />
                  Verification
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('trust-score')}
                  className="hover:text-white transition-colors text-left"
                >
                  Trust Score
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('disputes')}
                  className="hover:text-white transition-colors flex items-center gap-1.5 text-left"
                >
                  <FileText className="w-3 h-3 sm:w-4 sm:h-4 flex-shrink-0" />
                  Disputes
                </button>
              </li>
              <li>
                <button
                  onClick={() => onViewChange('safety')}
                  className="hover:text-white transition-colors text-left"
                >
                  Report Issue
                </button>
              </li>
            </ul>
          </div>
        </div>

        {user && (
          <div className="mt-6 sm:mt-8 pt-4 sm:pt-6 border-t border-gray-800">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4">
              <div className="flex items-center gap-2 text-xs sm:text-sm">
                <Mail className="w-3.5 h-3.5 sm:w-4 sm:h-4 flex-shrink-0" />
                <span className="text-gray-400">Manage your communication preferences</span>
              </div>
              <button
                onClick={() => onViewChange('notifications')}
                className="flex items-center gap-2 px-3 sm:px-4 py-1.5 sm:py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors text-xs sm:text-sm font-medium whitespace-nowrap"
              >
                <Bell className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                Notification Settings
              </button>
            </div>
          </div>
        )}

        <div className="mt-4 sm:mt-6 pt-4 sm:pt-6 border-t border-gray-800">
          <div className="mb-4 sm:mb-6">
            <h3 className="text-white font-semibold mb-2 sm:mb-3 text-sm sm:text-base text-center">🌍 Available Worldwide</h3>
            <p className="text-xs text-gray-400 text-center mb-3">
              SouvenirPickers operates globally with payment support in 25+ countries
            </p>
            <div className="flex flex-wrap justify-center gap-2 text-[10px] sm:text-xs text-gray-400">
              <span className="px-2 py-1 bg-gray-800 rounded">🇺🇸 United States</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇬🇧 United Kingdom</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇨🇦 Canada</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇦🇺 Australia</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇩🇪 Germany</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇫🇷 France</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇮🇹 Italy</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇪🇸 Spain</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇳🇱 Netherlands</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇧🇪 Belgium</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇨🇭 Switzerland</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇦🇹 Austria</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇮🇪 Ireland</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇵🇹 Portugal</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇬🇷 Greece</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇵🇱 Poland</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇨🇿 Czech Republic</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇷🇴 Romania</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇭🇺 Hungary</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇸🇪 Sweden</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇩🇰 Denmark</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇫🇮 Finland</span>
              <span className="px-2 py-1 bg-gray-800 rounded">🇳🇴 Norway</span>
              <span className="px-2 py-1 bg-gray-800 rounded text-gray-300">+ More</span>
            </div>
          </div>

          <div className="text-center text-xs text-gray-500">
            <p className="mb-1.5 sm:mb-2">
              By using SouvenirPickers, you agree to our{' '}
              <button onClick={() => onViewChange('terms')} className="text-blue-500 hover:text-blue-400 underline">Terms of Service</button>,{' '}
              <button onClick={() => onViewChange('privacy')} className="text-blue-500 hover:text-blue-400 underline">Privacy Policy</button>, and{' '}
              <button onClick={() => onViewChange('cookie-policy')} className="text-blue-500 hover:text-blue-400 underline">Cookie Policy</button>.
            </p>
            <p className="text-[10px] sm:text-xs">
              SouvenirPickers is a marketplace connecting collectors with local pickers. We are not responsible for the actions of individual users.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
