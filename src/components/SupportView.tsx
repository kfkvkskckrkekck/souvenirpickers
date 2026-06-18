import { useState } from 'react';
import { Mail, Send, CheckCircle, X, Check } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useNotification } from '../contexts/NotificationContext';

export function SupportView() {
  const { user, profile } = useAuth();
  const { showNotification } = useNotification();
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [category, setCategory] = useState('other');
  const [loading, setLoading] = useState(false);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [error, setError] = useState('');
  const [emailCopied, setEmailCopied] = useState(false);

  const handleEmailClick = async (e: React.MouseEvent) => {
    e.preventDefault();
    const email = 'support@souvenirpickers.com';

    try {
      await navigator.clipboard.writeText(email);
      setEmailCopied(true);
      showNotification('success', 'Email address copied to clipboard!');
      setTimeout(() => setEmailCopied(false), 3000);
    } catch (err) {
      window.location.href = `mailto:${email}`;
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !message.trim() || !subject.trim()) return;

    setLoading(true);
    setError('');

    try {
      const { error } = await supabase.from('support_tickets').insert({
        user_id: user.id,
        subject: subject.trim(),
        description: message.trim(),
        category,
        status: 'open',
      });

      if (error) {
        console.error('Support ticket error:', error);
        throw error;
      }

      setShowSuccessModal(true);
      setSubject('');
      setMessage('');
      setCategory('other');
    } catch (err: any) {
      console.error('Error submitting ticket:', err);
      setError(err.message || 'Failed to submit support ticket. Please try again.');
      setTimeout(() => setError(''), 5000);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Support Center</h1>
        <p className="text-gray-600">Get help with your SouvenirPickers experience</p>
      </div>

      <div className="mb-8">
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-xl p-6 border border-blue-200 max-w-2xl">
          <div className="bg-blue-600 w-12 h-12 rounded-lg flex items-center justify-center mb-4">
            <Mail className="w-6 h-6 text-white" />
          </div>
          <h3 className="text-lg font-semibold text-gray-900 mb-2">Email Support</h3>
          <p className="text-gray-600 text-sm mb-4">Get a response within 24 hours</p>
          <button
            onClick={handleEmailClick}
            className="inline-flex items-center gap-2 text-blue-600 font-medium hover:text-blue-700 hover:underline transition-all cursor-pointer"
          >
            {emailCopied ? (
              <>
                <Check className="w-4 h-4" />
                <span>Copied!</span>
              </>
            ) : (
              <>
                <Mail className="w-4 h-4" />
                support@souvenirpickers.com
              </>
            )}
          </button>
          <p className="text-xs text-gray-500 mt-2">Click to copy or open email client</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Submit a Support Ticket</h2>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 flex items-start gap-3">
            <div className="flex-shrink-0">
              <svg className="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd"/>
              </svg>
            </div>
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Category
              </label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="technical">Technical Issue</option>
                <option value="payment">Billing & Payments</option>
                <option value="order">Orders & Deliveries</option>
                <option value="account">Account & Profile</option>
                <option value="other">Other / General Inquiry</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Subject
              </label>
              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="Brief description of your issue"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Message
              </label>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Please provide as much detail as possible..."
                rows={6}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                required
              />
            </div>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <p className="text-sm text-blue-800">
                <strong>Tip:</strong> Include screenshots, order numbers, or any relevant details
                to help us resolve your issue faster.
              </p>
            </div>

            <button
              type="submit"
              disabled={loading || !subject.trim() || !message.trim()}
              className="w-full bg-blue-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <Send className="w-5 h-5" />
              {loading ? 'Submitting...' : 'Submit Ticket'}
            </button>
          </form>
      </div>

      <div className="mt-8 bg-gradient-to-r from-gray-50 to-gray-100 rounded-xl p-6 border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-3">Quick Links</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <a
            href="#"
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            View FAQ
          </a>
          <a
            href="#"
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            Community Guidelines
          </a>
          <a
            href="#"
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            Terms of Service
          </a>
          <a
            href="#"
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            Privacy Policy
          </a>
        </div>
      </div>

      {showSuccessModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl w-full max-w-md">
            <div className="p-6">
              <div className="flex flex-col items-center text-center">
                <div className="bg-green-100 w-16 h-16 rounded-full flex items-center justify-center mb-4">
                  <CheckCircle className="w-10 h-10 text-green-600" />
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-2">Ticket Submitted!</h3>
                <p className="text-gray-600 mb-6">
                  We've received your support request and will get back to you within 24 hours at the email address associated with your account.
                </p>
                <button
                  onClick={() => setShowSuccessModal(false)}
                  className="w-full bg-blue-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
                >
                  Got it
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
