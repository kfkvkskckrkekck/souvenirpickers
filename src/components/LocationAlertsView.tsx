import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Bell, Plus, MapPin, Trash2, ToggleLeft, ToggleRight, AlertCircle, Info } from 'lucide-react';
import SouvenirLoader from './SouvenirLoader';

interface LocationAlert {
  id: string;
  location_name: string;
  country: string;
  city: string;
  latitude: number;
  longitude: number;
  radius_km: number;
  alert_enabled: boolean;
  last_alerted_at: string | null;
  created_at: string;
}

export default function LocationAlertsView() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [alerts, setAlerts] = useState<LocationAlert[]>([]);
  const [showNewAlertModal, setShowNewAlertModal] = useState(false);
  const [newAlertCountry, setNewAlertCountry] = useState('');
  const [newAlertCity, setNewAlertCity] = useState('');

  useEffect(() => {
    if (user) {
      loadAlerts();
    }
  }, [user]);

  const loadAlerts = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('location_alerts')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAlerts(data || []);
    } catch (error) {

    } finally {
      setLoading(false);
    }
  };

  const createAlert = async () => {
    if (!newAlertCountry.trim() || !newAlertCity.trim()) {
      alert('Please fill in both country and city');
      return;
    }

    try {
      const { data, error } = await supabase
        .from('location_alerts')
        .insert({
          user_id: user?.id,
          location_name: `${newAlertCity}, ${newAlertCountry}`,
          country: newAlertCountry,
          city: newAlertCity,
          alert_enabled: true
        })
        .select()
        .single();

      if (error) throw error;

      setAlerts([data, ...alerts]);
      setShowNewAlertModal(false);
      resetForm();
    } catch (error) {

    }
  };

  const resetForm = () => {
    setNewAlertCountry('');
    setNewAlertCity('');
  };

  const deleteAlert = async (alertId: string) => {
    if (!confirm('Are you sure you want to delete this alert?')) return;

    try {
      const { error } = await supabase
        .from('location_alerts')
        .delete()
        .eq('id', alertId);

      if (error) throw error;

      setAlerts(alerts.filter(a => a.id !== alertId));
    } catch (error) {

    }
  };

  const toggleAlert = async (alertId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('location_alerts')
        .update({ alert_enabled: !currentStatus })
        .eq('id', alertId);

      if (error) throw error;

      setAlerts(alerts.map(a =>
        a.id === alertId ? { ...a, alert_enabled: !currentStatus } : a
      ));
    } catch (error) {

    }
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <SouvenirLoader message="Loading location alerts..." />
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2 flex items-center gap-3">
            <Bell className="w-8 h-8 text-blue-600" />
            Location Alerts
          </h1>
          <p className="text-gray-600">Get notified when pickers are near your desired locations</p>
        </div>
        <button
          onClick={() => setShowNewAlertModal(true)}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium flex items-center gap-2"
        >
          <Plus className="w-5 h-5" />
          New Alert
        </button>
      </div>

      <div className="mb-8 bg-blue-50 border border-blue-200 rounded-lg p-6">
        <div className="flex items-start gap-4">
          <div className="bg-blue-600 p-3 rounded-lg flex-shrink-0">
            <AlertCircle className="w-6 h-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">How Location Alerts Work</h3>
            <div className="space-y-3">
              <div className="flex gap-3">
                <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-bold">1</div>
                <p className="text-gray-700">
                  <strong>Set Your Location:</strong> Choose a country and city where you want souvenirs from.
                </p>
              </div>
              <div className="flex gap-3">
                <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-bold">2</div>
                <p className="text-gray-700">
                  <strong>Enable Alert:</strong> Keep your alert enabled to receive notifications when pickers are in that location.
                </p>
              </div>
              <div className="flex gap-3">
                <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-bold">3</div>
                <p className="text-gray-700">
                  <strong>Get Notified:</strong> When a picker's location matches your country and city, you'll receive a notification!
                </p>
              </div>
            </div>
            <div className="mt-4 p-3 bg-white border border-blue-200 rounded-lg">
              <p className="text-sm text-blue-800 flex items-start gap-2">
                <Info className="w-4 h-4 mt-0.5 flex-shrink-0" />
                <span><strong>Note:</strong> To prevent spam, you'll only receive one alert per location every 24 hours, even if multiple pickers enter the area.</span>
              </p>
            </div>
          </div>
        </div>
      </div>

      {showNewAlertModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 max-w-md w-full max-h-[90vh] overflow-y-auto">
            <h3 className="text-xl font-bold text-gray-900 mb-4">Create Location Alert</h3>

            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">Country</label>
              <input
                type="text"
                value={newAlertCountry}
                onChange={(e) => setNewAlertCountry(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., France"
              />
            </div>

            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 mb-2">City</label>
              <input
                type="text"
                value={newAlertCity}
                onChange={(e) => setNewAlertCity(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., Paris"
              />
              <div className="mt-2 p-3 bg-blue-50 border border-blue-200 rounded text-xs text-blue-800">
                <strong>Note:</strong> You'll be notified when pickers update their location to match this exact country and city.
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={createAlert}
                className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Create Alert
              </button>
              <button
                onClick={() => {
                  setShowNewAlertModal(false);
                  resetForm();
                }}
                className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {alerts.length === 0 ? (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-12">
          <div className="max-w-2xl mx-auto text-center">
            <Bell className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-3">No Location Alerts Set</h3>

            <div className="text-left bg-gray-50 rounded-lg p-6 mb-6">
              <h4 className="font-semibold text-gray-900 mb-3">Why set up location alerts?</h4>
              <ul className="space-y-3 text-gray-700">
                <li className="flex gap-3">
                  <Bell className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
                  <span><strong>Stay informed:</strong> Get notified immediately when pickers arrive at locations you care about</span>
                </li>
                <li className="flex gap-3">
                  <MapPin className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                  <span><strong>Be first:</strong> Contact pickers before other collectors and secure unique souvenirs</span>
                </li>
                <li className="flex gap-3">
                  <AlertCircle className="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
                  <span><strong>Set & forget:</strong> Once configured, alerts work automatically in the background</span>
                </li>
              </ul>

              <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <p className="text-sm text-blue-800">
                  <strong>Example:</strong> Set an alert for city "Tokyo" in country "Japan". When any picker updates their location
                  to Tokyo, Japan, you'll get notified so you can reach out and request souvenirs!
                </p>
              </div>
            </div>

            <button
              onClick={() => setShowNewAlertModal(true)}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium inline-flex items-center gap-2"
            >
              <Plus className="w-5 h-5" />
              Create Your First Alert
            </button>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {alerts.map(alert => (
            <div
              key={alert.id}
              className={`bg-white rounded-xl shadow-sm border-2 ${
                alert.alert_enabled ? 'border-blue-300' : 'border-gray-200'
              } p-6`}
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-lg ${alert.alert_enabled ? 'bg-blue-100' : 'bg-gray-100'}`}>
                    <MapPin className={`w-5 h-5 ${alert.alert_enabled ? 'text-blue-600' : 'text-gray-400'}`} />
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-900">{alert.location_name}</h3>
                    <p className="text-sm text-gray-600">{alert.city}, {alert.country}</p>
                  </div>
                </div>
              </div>

              {alert.last_alerted_at && (
                <div className="mb-4 bg-green-50 border border-green-200 rounded-lg p-3">
                  <p className="text-xs text-green-800">
                    <strong>Last Alert:</strong>{' '}
                    {new Date(alert.last_alerted_at).toLocaleDateString()} at{' '}
                    {new Date(alert.last_alerted_at).toLocaleTimeString()}
                  </p>
                </div>
              )}

              <div className="flex items-center justify-between mb-4">
                <span className="text-sm font-medium text-gray-700">Alert Status</span>
                <button
                  onClick={() => toggleAlert(alert.id, alert.alert_enabled)}
                  className="flex items-center gap-2"
                >
                  {alert.alert_enabled ? (
                    <>
                      <span className="text-sm text-blue-600 font-medium">Enabled</span>
                      <ToggleRight className="w-8 h-8 text-blue-600" />
                    </>
                  ) : (
                    <>
                      <span className="text-sm text-gray-500 font-medium">Disabled</span>
                      <ToggleLeft className="w-8 h-8 text-gray-400" />
                    </>
                  )}
                </button>
              </div>

              <div className="flex gap-2">
                <button
                  onClick={() => deleteAlert(alert.id)}
                  className="flex-1 px-3 py-2 text-sm border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors flex items-center justify-center gap-2"
                >
                  <Trash2 className="w-4 h-4" />
                  Delete
                </button>
              </div>

              <p className="text-xs text-gray-500 mt-3">
                Created {new Date(alert.created_at).toLocaleDateString()}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
