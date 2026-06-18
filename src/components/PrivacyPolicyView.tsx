import { Shield, Eye, Lock, Database, Users, Mail } from 'lucide-react';

export function PrivacyPolicyView() {
  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="flex items-center gap-3 mb-6">
          <Shield className="w-8 h-8 text-blue-600" />
          <h1 className="text-3xl font-bold text-gray-900">Privacy Policy</h1>
        </div>

        <p className="text-sm text-gray-500 mb-8">Last updated: December 2024</p>

        <div className="space-y-8">
          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Eye className="w-6 h-6 text-blue-600" />
              Introduction
            </h2>
            <p className="text-gray-700 leading-relaxed">
              At SouvenirPickers, we take your privacy seriously. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our marketplace platform. Please read this privacy policy carefully. If you do not agree with the terms of this privacy policy, please do not access the site.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Database className="w-6 h-6 text-blue-600" />
              Information We Collect
            </h2>
            <div className="space-y-4 text-gray-700">
              <div>
                <h3 className="font-semibold text-gray-900 mb-2">Personal Information</h3>
                <p className="leading-relaxed">
                  We collect information that you provide directly to us, including:
                </p>
                <ul className="list-disc list-inside ml-4 mt-2 space-y-1">
                  <li>Name and contact information (email, phone number)</li>
                  <li>Account credentials (username and password)</li>
                  <li>Profile information (bio, location, profile picture)</li>
                  <li>Payment information (processed securely through Stripe)</li>
                  <li>Communication records (messages, reviews, support tickets)</li>
                </ul>
              </div>

              <div>
                <h3 className="font-semibold text-gray-900 mb-2">Usage Information</h3>
                <p className="leading-relaxed">
                  We automatically collect certain information when you use our platform:
                </p>
                <ul className="list-disc list-inside ml-4 mt-2 space-y-1">
                  <li>Device information (browser type, operating system)</li>
                  <li>Log data (IP address, access times, pages viewed)</li>
                  <li>Location data (if you enable location services)</li>
                  <li>Cookies and similar technologies</li>
                </ul>
              </div>
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Lock className="w-6 h-6 text-blue-600" />
              How We Use Your Information
            </h2>
            <p className="text-gray-700 leading-relaxed mb-3">
              We use the information we collect to:
            </p>
            <ul className="list-disc list-inside ml-4 space-y-2 text-gray-700">
              <li>Provide, maintain, and improve our services</li>
              <li>Process transactions and send related information</li>
              <li>Send you technical notices and support messages</li>
              <li>Respond to your comments and questions</li>
              <li>Monitor and analyze trends, usage, and activities</li>
              <li>Detect, prevent, and address fraud and security issues</li>
              <li>Personalize your experience on the platform</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Users className="w-6 h-6 text-blue-600" />
              Information Sharing
            </h2>
            <p className="text-gray-700 leading-relaxed mb-3">
              We may share your information in the following circumstances:
            </p>
            <ul className="list-disc list-inside ml-4 space-y-2 text-gray-700">
              <li><strong>With other users:</strong> Your public profile information is visible to other users</li>
              <li><strong>Service providers:</strong> We share information with third-party service providers (e.g., payment processing, hosting)</li>
              <li><strong>Legal requirements:</strong> We may disclose information if required by law or to protect our rights</li>
              <li><strong>Business transfers:</strong> Information may be transferred if we are involved in a merger or acquisition</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Data Security</h2>
            <p className="text-gray-700 leading-relaxed">
              We implement appropriate technical and organizational security measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure. While we strive to protect your information, we cannot guarantee its absolute security.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Your Rights</h2>
            <p className="text-gray-700 leading-relaxed mb-3">
              You have the right to:
            </p>
            <ul className="list-disc list-inside ml-4 space-y-2 text-gray-700">
              <li>Access and update your personal information</li>
              <li>Request deletion of your account and data</li>
              <li>Opt-out of marketing communications</li>
              <li>Control cookie preferences</li>
              <li>Request a copy of your data</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Third-Party Services</h2>
            <p className="text-gray-700 leading-relaxed">
              Our platform uses third-party services including Stripe for payment processing and Supabase for data storage. These services have their own privacy policies and we encourage you to review them.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">International Data Transfers</h2>
            <p className="text-gray-700 leading-relaxed">
              Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information in accordance with this privacy policy.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Children's Privacy</h2>
            <p className="text-gray-700 leading-relaxed">
              Our services are not intended for users under the age of 18. We do not knowingly collect personal information from children. If you believe we have collected information from a child, please contact us immediately.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">Changes to This Policy</h2>
            <p className="text-gray-700 leading-relaxed">
              We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy on this page and updating the "Last updated" date.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Mail className="w-6 h-6 text-blue-600" />
              Contact Us
            </h2>
            <p className="text-gray-700 leading-relaxed">
              If you have questions about this privacy policy or our data practices, please contact us through our support system or email us at privacy@souvenirpickers.com.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
