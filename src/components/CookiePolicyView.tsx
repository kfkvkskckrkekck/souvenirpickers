import React from 'react';
import { Cookie, Shield, Settings, BarChart3, Globe, Calendar } from 'lucide-react';

export default function CookiePolicyView() {
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto bg-white rounded-xl shadow-sm p-8">
        <div className="flex items-center gap-3 mb-6">
          <Cookie className="w-8 h-8 text-blue-600" />
          <h1 className="text-3xl font-bold text-gray-900">Cookie Policy</h1>
        </div>

        <p className="text-sm text-gray-500 mb-8">
          <Calendar className="w-4 h-4 inline mr-1" />
          Last Updated: March 16, 2026
        </p>

        <div className="prose max-w-none">
          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">What Are Cookies?</h2>
            <p className="text-gray-700 mb-4">
              Cookies are small text files that are placed on your device when you visit our website. They help us provide you with a better experience by remembering your preferences and understanding how you use our service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">How We Use Cookies</h2>
            <p className="text-gray-700 mb-4">
              We use cookies for the following purposes:
            </p>
          </section>

          <div className="space-y-6 mb-8">
            <div className="border border-gray-200 rounded-lg p-6">
              <div className="flex items-start gap-3 mb-3">
                <Shield className="w-6 h-6 text-green-600 flex-shrink-0 mt-1" />
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Essential Cookies</h3>
                  <p className="text-gray-700 mb-3">
                    These cookies are necessary for the website to function properly. They enable core functionality such as security, authentication, and accessibility.
                  </p>
                  <div className="bg-gray-50 rounded p-3">
                    <p className="text-sm font-medium text-gray-700 mb-2">Examples:</p>
                    <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
                      <li>Authentication tokens to keep you logged in</li>
                      <li>Security cookies to protect against fraud</li>
                      <li>Session cookies to maintain your browsing state</li>
                    </ul>
                  </div>
                  <p className="text-sm text-gray-500 mt-3">
                    <strong>Duration:</strong> Session or up to 30 days
                  </p>
                </div>
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-6">
              <div className="flex items-start gap-3 mb-3">
                <Settings className="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" />
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Functional Cookies</h3>
                  <p className="text-gray-700 mb-3">
                    These cookies allow us to remember your preferences and provide enhanced, personalized features.
                  </p>
                  <div className="bg-gray-50 rounded p-3">
                    <p className="text-sm font-medium text-gray-700 mb-2">Examples:</p>
                    <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
                      <li>Language and region preferences</li>
                      <li>Display preferences (theme, layout)</li>
                      <li>Recently viewed items</li>
                    </ul>
                  </div>
                  <p className="text-sm text-gray-500 mt-3">
                    <strong>Duration:</strong> Up to 1 year
                  </p>
                </div>
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-6">
              <div className="flex items-start gap-3 mb-3">
                <BarChart3 className="w-6 h-6 text-purple-600 flex-shrink-0 mt-1" />
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Analytics Cookies</h3>
                  <p className="text-gray-700 mb-3">
                    These cookies help us understand how visitors interact with our website by collecting and reporting information anonymously.
                  </p>
                  <div className="bg-gray-50 rounded p-3">
                    <p className="text-sm font-medium text-gray-700 mb-2">Examples:</p>
                    <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
                      <li>Page views and navigation patterns</li>
                      <li>Time spent on pages</li>
                      <li>Error messages encountered</li>
                    </ul>
                  </div>
                  <p className="text-sm text-gray-500 mt-3">
                    <strong>Duration:</strong> Up to 2 years
                  </p>
                </div>
              </div>
            </div>

            <div className="border border-gray-200 rounded-lg p-6">
              <div className="flex items-start gap-3 mb-3">
                <Globe className="w-6 h-6 text-orange-600 flex-shrink-0 mt-1" />
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-2">Third-Party Cookies</h3>
                  <p className="text-gray-700 mb-3">
                    We use trusted third-party services that may set their own cookies to provide functionality.
                  </p>
                  <div className="bg-gray-50 rounded p-3">
                    <p className="text-sm font-medium text-gray-700 mb-2">Third-party services we use:</p>
                    <ul className="text-sm text-gray-600 space-y-1 list-disc list-inside">
                      <li>Stripe for payment processing</li>
                      <li>Supabase for authentication and data storage</li>
                      <li>Content delivery networks (CDNs)</li>
                    </ul>
                  </div>
                  <p className="text-sm text-gray-500 mt-3">
                    <strong>Duration:</strong> Varies by provider
                  </p>
                </div>
              </div>
            </div>
          </div>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Managing Your Cookie Preferences</h2>
            <p className="text-gray-700 mb-4">
              You have the right to decide whether to accept or reject cookies. You can manage your cookie preferences through:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 mb-4">
              <li>The cookie banner that appears when you first visit our website</li>
              <li>Your browser settings - most browsers allow you to refuse cookies or delete existing ones</li>
              <li>Opting out of third-party cookies through the respective service providers</li>
            </ul>
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <p className="text-sm text-yellow-800">
                <strong>Note:</strong> If you disable essential cookies, some features of our website may not function properly, and your experience may be impaired.
              </p>
            </div>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Browser-Specific Instructions</h2>
            <p className="text-gray-700 mb-4">
              To manage cookies in your browser, please visit the links below:
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2">
              <li><a href="https://support.google.com/chrome/answer/95647" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-700 underline">Google Chrome</a></li>
              <li><a href="https://support.mozilla.org/en-US/kb/enhanced-tracking-protection-firefox-desktop" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-700 underline">Mozilla Firefox</a></li>
              <li><a href="https://support.apple.com/guide/safari/manage-cookies-sfri11471/mac" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-700 underline">Safari</a></li>
              <li><a href="https://support.microsoft.com/en-us/microsoft-edge/delete-cookies-in-microsoft-edge-63947406-40ac-c3b8-57b9-2a946a29ae09" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-700 underline">Microsoft Edge</a></li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Updates to This Policy</h2>
            <p className="text-gray-700">
              We may update this Cookie Policy from time to time to reflect changes in our practices or for other operational, legal, or regulatory reasons. We encourage you to review this policy periodically to stay informed about how we use cookies.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">Contact Us</h2>
            <p className="text-gray-700 mb-4">
              If you have any questions about our use of cookies or this Cookie Policy, please contact us:
            </p>
            <div className="bg-gray-50 rounded-lg p-4">
              <p className="text-gray-700">
                <strong>Email:</strong> <a href="mailto:support@souvenirpickers.com" className="text-blue-600 hover:text-blue-700 underline">support@souvenirpickers.com</a>
              </p>
            </div>
          </section>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
            <h3 className="text-lg font-semibold text-blue-900 mb-2">Your Privacy Matters</h3>
            <p className="text-blue-800 mb-3">
              We are committed to protecting your privacy and being transparent about our data practices. For more information about how we collect, use, and protect your personal data, please see our:
            </p>
            <div className="flex gap-3">
              <a href="/privacy" className="text-blue-600 hover:text-blue-700 underline font-medium">Privacy Policy</a>
              <span className="text-blue-400">•</span>
              <a href="/terms" className="text-blue-600 hover:text-blue-700 underline font-medium">Terms of Service</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
