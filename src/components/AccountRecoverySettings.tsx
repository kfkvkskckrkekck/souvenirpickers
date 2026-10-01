import { useState, useEffect } from 'react';
import { Shield, Mail, Phone, CheckCircle, AlertCircle, Key, ExternalLink } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';

export function AccountRecoverySettings() {
  const { user, profile } = useAuth();
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  const [backupEmail, setBackupEmail] = useState('');
  const [preferredMethod, setPreferredMethod] = useState('email');
  const [linkedProviders, setLinkedProviders] = useState<string[]>([]);
  const [lastLoginMethod, setLastLoginMethod] = useState('');

  useEffect(() => {
    loadRecoverySettings();
    loadLinkedProviders();
  }, [profile]);

  const loadRecoverySettings = async () => {
    if (!profile) return;

    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('phone_number, backup_email, preferred_recovery_method, last_login_method, linked_auth_providers')
        .eq('id', profile.id)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        setPhoneNumber(data.phone_number || '');
        setBackupEmail(data.backup_email || '');
        setPreferredMethod(data.preferred_recovery_method || 'email');
        setLastLoginMethod(data.last_login_method || 'password');
        setLinkedProviders(data.linked_auth_providers || []);
      }
    } catch (err: any) {

    }
  };

  const loadLinkedProviders = async () => {
    try {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser?.app_metadata?.providers) {
        setLinkedProviders(authUser.app_metadata.providers);
      }
    } catch (err) {

    }
  };

  const handleUpdateRecoverySettings = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setMessage('');

    try {
      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          phone_number: phoneNumber || null,
          backup_email: backupEmail || null,
          preferred_recovery_method: preferredMethod,
        })
        .eq('id', profile?.id);

      if (updateError) throw updateError;

      setMessage('Recovery settings updated successfully!');
      setTimeout(() => setMessage(''), 5000);
    } catch (err: any) {

      setError(err.message || 'Failed to update recovery settings');
    } finally {
      setLoading(false);
    }
  };

  const handleLinkProvider = async (provider: 'google' | 'facebook') => {
    try {
      setLoading(true);
      const { error } = await supabase.auth.linkIdentity({
        provider,
      });

      if (error) throw error;

      setMessage(`${provider} account linked successfully!`);
      await loadLinkedProviders();
    } catch (err: any) {

      setError(err.message || `Failed to link ${provider} account`);
    } finally {
      setLoading(false);
    }
  };

  const getProviderIcon = (provider: string) => {
    switch (provider) {
      case 'google':
        return (
          <svg className="w-5 h-5" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
        );
      case 'facebook':
        return (
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="#1877F2">
            <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
          </svg>
        );
      default:
        return <Key className="w-5 h-5" />;
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="flex items-center gap-3 mb-8">
          <div className="w-12 h-12 bg-gradient-to-br from-blue-600 to-blue-700 rounded-xl flex items-center justify-center">
            <Shield className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Account Recovery Settings</h1>
            <p className="text-gray-600">Set up backup recovery options now to protect your account in the future</p>
          </div>
        </div>

        {message && (
          <div className="mb-6 bg-green-50 border-2 border-green-300 text-green-700 p-4 rounded-xl flex items-center gap-3">
            <CheckCircle className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{message}</p>
          </div>
        )}

        {error && (
          <div className="mb-6 bg-red-50 border-2 border-red-300 text-red-700 p-4 rounded-xl flex items-center gap-3">
            <AlertCircle className="w-5 h-5 flex-shrink-0" />
            <p className="font-medium">{error}</p>
          </div>
        )}

        <div className="space-y-8">
          <div>
            <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <Mail className="w-5 h-5 text-blue-600" />
              Current Login Method
            </h2>
            <div className="bg-gray-50 rounded-xl p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-700">Primary Email</p>
                  <p className="text-lg font-semibold text-gray-900">{user?.email}</p>
                </div>
                <div className="flex items-center gap-2 px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
                  <CheckCircle className="w-4 h-4" />
                  Verified
                </div>
              </div>
              <p className="text-sm text-gray-600 mt-2">
                Last login method: <span className="font-semibold capitalize">{lastLoginMethod}</span>
              </p>
            </div>
          </div>

          <form onSubmit={handleUpdateRecoverySettings} className="space-y-6">
            <div>
              <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Phone className="w-5 h-5 text-orange-600" />
                Phone Number (Optional)
              </h2>
              <div className="space-y-3">
                <input
                  type="tel"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  placeholder="+1 (555) 123-4567"
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-100 focus:border-blue-500 transition-all"
                />
                <p className="text-sm text-gray-600">
                  Add a phone number for SMS-based account recovery. Use international format (e.g., +1 for US).
                </p>
              </div>
            </div>

            <div>
              <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                <Mail className="w-5 h-5 text-green-600" />
                Backup Email (Optional)
              </h2>
              <div className="space-y-3">
                <input
                  type="email"
                  value={backupEmail}
                  onChange={(e) => setBackupEmail(e.target.value)}
                  placeholder="backup@example.com"
                  className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-100 focus:border-blue-500 transition-all"
                />
                <p className="text-sm text-gray-600">
                  Add a backup email address for account recovery. Must be different from your primary email.
                </p>
              </div>
            </div>

            <div>
              <h2 className="text-xl font-bold text-gray-900 mb-4">Preferred Recovery Method</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <button
                  type="button"
                  onClick={() => setPreferredMethod('email')}
                  className={`p-4 rounded-xl border-2 transition-all ${
                    preferredMethod === 'email'
                      ? 'border-blue-600 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <Mail className="w-6 h-6 mx-auto mb-2 text-blue-600" />
                  <div className="font-medium">Email</div>
                  <div className="text-xs text-gray-600">Password reset via email</div>
                </button>

                <button
                  type="button"
                  onClick={() => setPreferredMethod('magic_link')}
                  className={`p-4 rounded-xl border-2 transition-all ${
                    preferredMethod === 'magic_link'
                      ? 'border-blue-600 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <Key className="w-6 h-6 mx-auto mb-2 text-blue-600" />
                  <div className="font-medium">Magic Link</div>
                  <div className="text-xs text-gray-600">One-click email login</div>
                </button>

                <button
                  type="button"
                  onClick={() => setPreferredMethod('phone')}
                  className={`p-4 rounded-xl border-2 transition-all ${
                    preferredMethod === 'phone'
                      ? 'border-blue-600 bg-blue-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                  disabled={!phoneNumber}
                >
                  <Phone className="w-6 h-6 mx-auto mb-2 text-orange-600" />
                  <div className="font-medium">Phone/SMS</div>
                  <div className="text-xs text-gray-600">
                    {phoneNumber ? 'SMS verification' : 'Add phone first'}
                  </div>
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-blue-600 to-blue-700 text-white py-4 rounded-xl font-bold text-lg hover:from-blue-700 hover:to-blue-800 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
            >
              {loading ? 'Saving...' : 'Save Recovery Settings'}
            </button>
          </form>

          <div className="border-t-2 border-gray-100 pt-8">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Linked Accounts</h2>
            <div className="space-y-3">
              <div className="bg-gray-50 rounded-xl p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Key className="w-5 h-5 text-gray-600" />
                    <div>
                      <p className="font-medium text-gray-900">Email & Password</p>
                      <p className="text-sm text-gray-600">Traditional login method</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
                    <CheckCircle className="w-4 h-4" />
                    Active
                  </div>
                </div>
              </div>

              {['google', 'facebook'].map((provider) => {
                const isLinked = linkedProviders.includes(provider);
                return (
                  <div key={provider} className="bg-gray-50 rounded-xl p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        {getProviderIcon(provider)}
                        <div>
                          <p className="font-medium text-gray-900 capitalize">{provider}</p>
                          <p className="text-sm text-gray-600">
                            {isLinked ? 'Linked to your account' : 'Not connected'}
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => !isLinked && handleLinkProvider(provider as 'google' | 'facebook')}
                        disabled={loading || isLinked}
                        className={`px-4 py-2 rounded-lg font-medium transition-all ${
                          isLinked
                            ? 'bg-green-100 text-green-700 cursor-default'
                            : 'bg-blue-600 text-white hover:bg-blue-700'
                        }`}
                      >
                        {isLinked ? (
                          <span className="flex items-center gap-2">
                            <CheckCircle className="w-4 h-4" />
                            Linked
                          </span>
                        ) : (
                          <span className="flex items-center gap-2">
                            <ExternalLink className="w-4 h-4" />
                            Link Account
                          </span>
                        )}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="bg-gradient-to-br from-orange-50 to-yellow-50 border-2 border-orange-300 rounded-xl p-6">
            <h3 className="font-bold text-orange-900 mb-3 flex items-center gap-2 text-lg">
              <AlertCircle className="w-6 h-6" />
              Why Set Up Recovery Options Now?
            </h3>
            <p className="text-orange-800 mb-4 font-medium">
              These settings help you regain access if you forget your password or lose access to your primary email. Set them up now while you're logged in!
            </p>
            <ul className="text-sm text-orange-900 space-y-2 list-disc list-inside">
              <li><strong>Add a backup email</strong> - Receive recovery links even if your primary email is compromised</li>
              <li><strong>Add your phone number</strong> - Get SMS recovery codes when needed</li>
              <li><strong>Choose your preferred recovery method</strong> - Customize how you want to recover your account</li>
            </ul>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-xl p-6">
            <h3 className="font-bold text-blue-900 mb-2 flex items-center gap-2">
              <Shield className="w-5 h-5" />
              Security Tips
            </h3>
            <ul className="text-sm text-blue-800 space-y-2 list-disc list-inside">
              <li>Add multiple recovery methods to ensure you can always access your account</li>
              <li>Keep your backup email and phone number up to date</li>
              <li>Use a strong, unique password for your account</li>
              <li>Save your recovery options before you need them</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
