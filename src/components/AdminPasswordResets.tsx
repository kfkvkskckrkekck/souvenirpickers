import { useState } from 'react';
import { Mail, AlertCircle, CheckCircle, Shield } from 'lucide-react';
import { supabase } from '../lib/supabase';

export function AdminPasswordResets() {
  const [email, setEmail] = useState('');
  const [sending, setSending] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const sendPasswordReset = async () => {
    if (!email.trim()) {
      setErrorMessage('Please enter an email address');
      return;
    }

    setSending(true);
    setSuccessMessage('');
    setErrorMessage('');

    try {
      // Use custom SMTP edge function for support@pickersjourney.com emails
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-password-reset`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: email.trim(),
            redirectTo: `${window.location.origin}#type=recovery`,
          }),
        }
      );

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to send reset email');
      }

      setSuccessMessage(`Password reset email sent successfully to ${email}`);
      setEmail('');
    } catch (error: any) {
      setErrorMessage(error.message || 'Failed to send password reset email');
    } finally {
      setSending(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !sending) {
      sendPasswordReset();
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6 lg:p-8">
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-4">
          <Shield className="w-8 h-8 text-blue-600" />
          <h1 className="text-3xl font-bold text-gray-900">Password Reset Management</h1>
        </div>
        <p className="text-gray-600">
          Send password reset links to users who need to recover their accounts
        </p>
      </div>

      {successMessage && (
        <div className="mb-6 bg-green-50 border border-green-200 rounded-lg p-4 flex items-start gap-3">
          <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
          <p className="text-green-800">{successMessage}</p>
        </div>
      )}

      {errorMessage && (
        <div className="mb-6 bg-red-50 border border-red-200 rounded-lg p-4 flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
          <p className="text-red-800">{errorMessage}</p>
        </div>
      )}

      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="mb-6">
          <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
            User Email Address
          </label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="user@example.com"
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-lg"
            disabled={sending}
          />
          <p className="mt-2 text-sm text-gray-500">
            Enter the email address of the user who needs a password reset
          </p>
        </div>

        <button
          onClick={sendPasswordReset}
          disabled={sending || !email.trim()}
          className="w-full px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 font-semibold text-lg transition-colors"
        >
          {sending ? (
            'Sending Reset Link...'
          ) : (
            <>
              <Mail className="w-5 h-5" />
              Send Password Reset Link
            </>
          )}
        </button>

        <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 className="font-semibold text-blue-900 mb-2">How it works:</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• User will receive an email with a password reset link</li>
            <li>• Link is valid for 1 hour</li>
            <li>• User can set a new password through the link</li>
            <li>• They can then log in with their new password</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
