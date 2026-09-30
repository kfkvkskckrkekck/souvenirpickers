import { useState, useEffect } from 'react';
import { Bell, Mail, Smartphone, MessageSquare, Save } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import { supabase } from '../lib/supabase';

type NotificationPreferences = {
  email_new_message: boolean;
  email_order_status: boolean;
  email_payment_received: boolean;
  email_review_received: boolean;
  email_marketing: boolean;
  push_new_message: boolean;
  push_order_status: boolean;
  push_payment_received: boolean;
  sms_order_shipped: boolean;
  sms_order_delivered: boolean;
};

export function NotificationSettings() {
  const { user, profile } = useAuth();
  const toast = useToast();
  const isPicker = profile?.user_type === 'picker';
  const isCollector = profile?.user_type === 'client';
  const [preferences, setPreferences] = useState<NotificationPreferences>({
    email_new_message: true,
    email_order_status: true,
    email_payment_received: true,
    email_review_received: true,
    email_marketing: false,
    push_new_message: true,
    push_order_status: true,
    push_payment_received: true,
    sms_order_shipped: false,
    sms_order_delivered: false,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    loadPreferences();
  }, [user]);

  const loadPreferences = async () => {
    try {
      const { data, error } = await supabase
        .from('notification_preferences')
        .select('*')
        .eq('user_id', user?.id)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        setPreferences({
          email_new_message: data.email_new_message,
          email_order_status: data.email_order_status,
          email_payment_received: data.email_payment_received,
          email_review_received: data.email_review_received,
          email_marketing: data.email_marketing,
          push_new_message: data.push_new_message,
          push_order_status: data.push_order_status,
          push_payment_received: data.push_payment_received,
          sms_order_shipped: data.sms_order_shipped,
          sms_order_delivered: data.sms_order_delivered,
        });
      }
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!user) {
      toast.error('You must be logged in to save preferences');
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      console.log('Saving notification preferences for user:', user.id);

      const { error } = await supabase
        .from('notification_preferences')
        .upsert({
          user_id: user.id,
          ...preferences,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'user_id'
        });

      if (error) {
        console.error('Error saving preferences:', error);
        throw error;
      }

      console.log('Preferences saved successfully');
      toast.success('Notification preferences saved successfully!');
      setMessage('Notification preferences saved successfully!');
      setTimeout(() => setMessage(''), 3000);
    } catch (error: any) {
      console.error('Failed to save preferences:', error);
      const errorMsg = error.message || 'Failed to save preferences. Please try again.';
      toast.error(errorMsg);
      setMessage('Failed to save preferences: ' + errorMsg);
    } finally {
      setSaving(false);
    }
  };

  const updatePreference = (key: keyof NotificationPreferences, value: boolean) => {
    setPreferences({ ...preferences, [key]: value });
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto p-6">
        <div className="flex items-center justify-center h-64">
          <div className="text-gray-500">Loading preferences...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-6">
      <div className="bg-white rounded-2xl shadow-lg p-8">
        <div className="flex items-center gap-3 mb-6">
          <Bell className="w-8 h-8 text-blue-600" />
          <h2 className="text-3xl font-bold text-gray-900">Notification Settings</h2>
        </div>

        <p className="text-gray-600 mb-4">
          Manage how you want to receive updates and notifications
        </p>

        {isPicker && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
            <p className="text-sm text-blue-900">
              <strong>For Pickers:</strong> Stay updated on new orders, custom requests, payment confirmations, and messages from collectors.
            </p>
          </div>
        )}

        {isCollector && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
            <p className="text-sm text-green-900">
              <strong>For Collectors:</strong> Get notified about order status updates, new listings from favorite pickers, and messages.
            </p>
          </div>
        )}

        <div className="space-y-8">
          <div>
            <div className="flex items-center gap-2 mb-4">
              <Mail className="w-6 h-6 text-gray-700" />
              <h3 className="text-xl font-bold text-gray-900">Email Notifications</h3>
            </div>
            <div className="space-y-3 pl-8">
              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_new_message}
                  onChange={(e) => updatePreference('email_new_message', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">New Messages</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Get notified when collectors send you messages'}
                    {isCollector && 'Get notified when pickers respond to your inquiries'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_order_status}
                  onChange={(e) => updatePreference('email_order_status', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Order Status Updates</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Get notified about new orders and fulfillment updates'}
                    {isCollector && 'Track your order progress from purchase to delivery'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_payment_received}
                  onChange={(e) => updatePreference('email_payment_received', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Payment Confirmations</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Receive notifications when payments are released to you'}
                    {isCollector && 'Get receipts when you make purchases'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_review_received}
                  onChange={(e) => updatePreference('email_review_received', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">New Reviews</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Get notified when collectors review your service'}
                    {isCollector && 'Get notified when pickers respond to your reviews'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.email_marketing}
                  onChange={(e) => updatePreference('email_marketing', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Marketing & Updates</div>
                  <div className="text-sm text-gray-500">Receive news, tips, and special offers</div>
                </div>
              </label>
            </div>
          </div>

          <div>
            <div className="flex items-center gap-2 mb-4">
              <Bell className="w-6 h-6 text-gray-700" />
              <h3 className="text-xl font-bold text-gray-900">Push Notifications</h3>
            </div>
            <div className="space-y-3 pl-8">
              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.push_new_message}
                  onChange={(e) => updatePreference('push_new_message', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">New Messages</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Instant alerts for collector messages and inquiries'}
                    {isCollector && 'Instant alerts when pickers respond'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.push_order_status}
                  onChange={(e) => updatePreference('push_order_status', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Order Updates</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Get instant alerts for new orders and updates'}
                    {isCollector && 'Real-time shipping and delivery updates'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.push_payment_received}
                  onChange={(e) => updatePreference('push_payment_received', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Payment Alerts</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'Get notified when payments are released'}
                    {isCollector && 'Instant purchase confirmations'}
                  </div>
                </div>
              </label>
            </div>
          </div>

          <div>
            <div className="flex items-center gap-2 mb-4">
              <Smartphone className="w-6 h-6 text-gray-700" />
              <h3 className="text-xl font-bold text-gray-900">SMS Notifications</h3>
            </div>
            <div className="bg-blue-50 border-l-4 border-blue-500 p-4 mb-4">
              <p className="text-sm text-blue-800">
                {isPicker && 'SMS notifications for critical order and shipping updates'}
                {isCollector && 'SMS notifications for important delivery updates'}
              </p>
            </div>
            <div className="space-y-3 pl-8">
              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.sms_order_shipped}
                  onChange={(e) => updatePreference('sms_order_shipped', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Order Shipped</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'SMS reminder when you ship an order'}
                    {isCollector && 'SMS when your order ships'}
                  </div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 hover:bg-gray-50 rounded-lg cursor-pointer">
                <input
                  type="checkbox"
                  checked={preferences.sms_order_delivered}
                  onChange={(e) => updatePreference('sms_order_delivered', e.target.checked)}
                  className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                />
                <div>
                  <div className="font-medium text-gray-900">Order Delivered</div>
                  <div className="text-sm text-gray-500">
                    {isPicker && 'SMS confirmation when order is delivered'}
                    {isCollector && 'SMS when your order arrives'}
                  </div>
                </div>
              </label>
            </div>
          </div>
        </div>

        {message && (
          <div className={`mt-6 p-4 rounded-lg ${message.includes('success') ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
            {message}
          </div>
        )}

        <div className="mt-8 flex gap-4">
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex items-center gap-2 bg-blue-600 text-white px-8 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Save className="w-5 h-5" />
            {saving ? 'Saving...' : 'Save Preferences'}
          </button>
        </div>
      </div>
    </div>
  );
}
