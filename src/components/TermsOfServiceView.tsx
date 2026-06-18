import { FileText, AlertTriangle, Scale, Shield, Ban } from 'lucide-react';

export function TermsOfServiceView() {
  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="flex items-center gap-3 mb-6">
          <FileText className="w-8 h-8 text-blue-600" />
          <h1 className="text-3xl font-bold text-gray-900">Terms of Service</h1>
        </div>

        <p className="text-sm text-gray-500 mb-8">Last updated: March 2026</p>

        <div className="space-y-8">
          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Agreement to Terms</h2>
            <p className="text-gray-700 leading-relaxed">
              By accessing and using SouvenirPickers, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using this platform.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Platform Overview</h2>
            <p className="text-gray-700 leading-relaxed">
              SouvenirPickers is a marketplace platform that connects collectors with local pickers worldwide. We facilitate transactions between users but are not directly involved in the actual transaction between buyers and sellers.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">User Accounts</h2>
            <div className="space-y-3 text-gray-700">
              <p className="leading-relaxed">When you create an account, you agree to:</p>
              <ul className="list-disc list-inside ml-4 space-y-2">
                <li>Provide accurate, current, and complete information</li>
                <li>Maintain the security of your account credentials</li>
                <li>Accept responsibility for all activities under your account</li>
                <li>Notify us immediately of any unauthorized access</li>
                <li>Be at least 18 years of age</li>
              </ul>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Subscription Terms</h2>
            <div className="space-y-3 text-gray-700">
              <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-4 mb-4">
                <h3 className="font-bold text-blue-900 mb-2 flex items-center gap-2">
                  <span className="text-lg">Limited Launch Offer - First 500 Pickers</span>
                </h3>
                <p className="text-blue-800 mb-2">
                  The first 500 pickers to join the platform will receive permanent early adopter status:
                </p>
                <ul className="list-disc list-inside ml-4 space-y-1 text-blue-900">
                  <li><strong>No subscription fee ever</strong></li>
                  <li>Only 10% platform commission on completed sales</li>
                  <li>Lifetime early adopter benefits</li>
                  <li>Priority support access</li>
                </ul>
              </div>

              <h3 className="font-semibold text-gray-900">For Pickers (After First 500):</h3>
              <ul className="list-disc list-inside ml-4 space-y-2 mb-4">
                <li>30-day free trial period for new picker accounts</li>
                <li>€10.00 monthly subscription fee after trial period</li>
                <li>10% platform commission on all completed sales</li>
                <li>Automatic monthly billing unless cancelled</li>
                <li>Cancellation available at any time</li>
              </ul>

              <h3 className="font-semibold text-gray-900">For Collectors:</h3>
              <ul className="list-disc list-inside ml-4 space-y-2">
                <li>Free access to all platform features</li>
                <li>No subscription fees or monthly charges</li>
                <li>Payment required only for items purchased</li>
              </ul>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Ban className="w-6 h-6 text-red-600" />
              Prohibited Activities
            </h2>
            <p className="text-gray-700 leading-relaxed mb-3">Users are strictly prohibited from:</p>
            <ul className="list-disc list-inside ml-4 space-y-2 text-gray-700">
              <li>Posting false, misleading, or fraudulent listings</li>
              <li>Selling counterfeit, stolen, or illegal items</li>
              <li>Harassing, threatening, or abusing other users</li>
              <li>Attempting to circumvent platform fees</li>
              <li>Using automated systems or bots</li>
              <li>Violating intellectual property rights</li>
              <li>Engaging in price manipulation or collusion</li>
              <li>Creating multiple accounts to abuse the system</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Payment Terms</h2>
            <div className="space-y-3 text-gray-700">
              <p className="leading-relaxed">All payments are processed through Stripe:</p>
              <ul className="list-disc list-inside ml-4 space-y-2">
                <li>Collectors pay upfront when placing orders</li>
                <li>Funds are held in escrow until order completion</li>
                <li>Pickers receive payment after successful delivery confirmation</li>
                <li>Platform commission (10%) is deducted automatically</li>
                <li>Subscription fees are non-refundable except as required by law</li>
              </ul>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Order Fulfillment</h2>
            <div className="space-y-3 text-gray-700">
              <p className="leading-relaxed">Pickers agree to:</p>
              <ul className="list-disc list-inside ml-4 space-y-2 mb-4">
                <li>Accurately represent items in listings</li>
                <li>Fulfill orders within agreed timeframes</li>
                <li>Provide tracking information when available</li>
                <li>Package items securely to prevent damage</li>
                <li>Respond to collector inquiries promptly</li>
              </ul>

              <p className="leading-relaxed">Collectors agree to:</p>
              <ul className="list-disc list-inside ml-4 space-y-2">
                <li>Confirm delivery within 3 days of receipt</li>
                <li>Inspect items upon arrival and report issues promptly</li>
                <li>Provide accurate shipping addresses</li>
                <li>Communicate clearly with pickers</li>
              </ul>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Disputes and Refunds</h2>
            <p className="text-gray-700 leading-relaxed">
              If issues arise with an order, users should first attempt to resolve the matter directly. If resolution is not possible, either party may open a dispute through our platform. We will review disputes on a case-by-case basis and may issue refunds, partial refunds, or other remedies as deemed appropriate.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <AlertTriangle className="w-6 h-6 text-yellow-600" />
              Disclaimers
            </h2>
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 space-y-2 text-sm">
              <p className="text-gray-700 leading-relaxed">
                <strong>AS-IS BASIS:</strong> The platform is provided "as is" without warranties of any kind, either express or implied.
              </p>
              <p className="text-gray-700 leading-relaxed">
                <strong>USER CONTENT:</strong> We are not responsible for the accuracy, quality, or legality of items listed by pickers.
              </p>
              <p className="text-gray-700 leading-relaxed">
                <strong>USER INTERACTIONS:</strong> We are not liable for disputes, damages, or losses resulting from interactions between users.
              </p>
              <p className="text-gray-700 leading-relaxed">
                <strong>THIRD-PARTY SERVICES:</strong> We are not responsible for the performance of third-party services like shipping carriers.
              </p>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Scale className="w-6 h-6 text-blue-600" />
              Limitation of Liability
            </h2>
            <p className="text-gray-700 leading-relaxed">
              To the maximum extent permitted by law, SouvenirPickers shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Intellectual Property</h2>
            <p className="text-gray-700 leading-relaxed">
              The platform and its original content, features, and functionality are owned by SouvenirPickers and are protected by international copyright, trademark, and other intellectual property laws. Users retain ownership of content they post but grant us a license to use, display, and distribute that content on the platform.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Shield className="w-6 h-6 text-blue-600" />
              Account Termination
            </h2>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to suspend or terminate your account at any time for violations of these terms, fraudulent activity, or any conduct we deem harmful to the platform or other users. You may also terminate your account at any time through your account settings.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Governing Law</h2>
            <p className="text-gray-700 leading-relaxed">
              These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which SouvenirPickers operates, without regard to its conflict of law provisions.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Changes to Terms</h2>
            <p className="text-gray-700 leading-relaxed">
              We reserve the right to modify these terms at any time. We will notify users of any material changes by posting the new Terms of Service on this page and updating the "Last updated" date. Your continued use of the platform after such changes constitutes acceptance of the new terms.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Contact Information</h2>
            <p className="text-gray-700 leading-relaxed">
              For questions about these Terms of Service, please contact us through our support system or email us at legal@souvenirpickers.com.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
