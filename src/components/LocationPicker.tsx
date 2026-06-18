import { useState, useEffect } from 'react';
import { MapPin, Navigation, Loader } from 'lucide-react';

type LocationPickerProps = {
  latitude?: number;
  longitude?: number;
  onLocationChange: (lat: number, lng: number) => void;
  label?: string;
};

export function LocationPicker({
  latitude,
  longitude,
  onLocationChange,
  label = "GPS Location"
}: LocationPickerProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [manualLat, setManualLat] = useState(latitude?.toString() || '');
  const [manualLng, setManualLng] = useState(longitude?.toString() || '');

  useEffect(() => {
    if (latitude) setManualLat(latitude.toString());
    if (longitude) setManualLng(longitude.toString());
  }, [latitude, longitude]);

  const getCurrentLocation = () => {
    if (!navigator.geolocation) {
      setError('Geolocation is not supported by your browser');
      return;
    }

    setLoading(true);
    setError('');

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const lat = position.coords.latitude;
        const lng = position.coords.longitude;
        setManualLat(lat.toString());
        setManualLng(lng.toString());
        onLocationChange(lat, lng);
        setLoading(false);
      },
      (error) => {
        setError('Unable to retrieve your location: ' + error.message);
        setLoading(false);
      }
    );
  };

  const handleManualUpdate = () => {
    const lat = parseFloat(manualLat);
    const lng = parseFloat(manualLng);

    if (isNaN(lat) || isNaN(lng)) {
      setError('Please enter valid coordinates');
      return;
    }

    if (lat < -90 || lat > 90) {
      setError('Latitude must be between -90 and 90');
      return;
    }

    if (lng < -180 || lng > 180) {
      setError('Longitude must be between -180 and 180');
      return;
    }

    setError('');
    onLocationChange(lat, lng);
  };

  const hasLocation = latitude && longitude;
  const mapUrl = hasLocation
    ? `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=13/${latitude}/${longitude}`
    : null;

  return (
    <div className="space-y-4">
      <label className="block text-sm font-medium text-gray-700 mb-2">
        <MapPin className="w-5 h-5 inline mr-2" />
        {label}
      </label>

      <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-5 space-y-4">
        <button
          type="button"
          onClick={getCurrentLocation}
          disabled={loading}
          className="w-full flex items-center justify-center gap-2 bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-all shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed font-medium"
        >
          {loading ? (
            <>
              <Loader className="w-5 h-5 animate-spin" />
              Getting location...
            </>
          ) : (
            <>
              <Navigation className="w-5 h-5" />
              Use Current Location
            </>
          )}
        </button>

        <div className="relative">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-300"></div>
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="px-2 bg-blue-50 text-gray-500">or enter manually</span>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Latitude</label>
            <input
              type="number"
              step="any"
              value={manualLat}
              onChange={(e) => setManualLat(e.target.value)}
              placeholder="e.g., 40.7128"
              className="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm bg-white"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Longitude</label>
            <input
              type="number"
              step="any"
              value={manualLng}
              onChange={(e) => setManualLng(e.target.value)}
              placeholder="e.g., -74.0060"
              className="w-full px-3 py-2 border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm bg-white"
            />
          </div>
        </div>

        <button
          type="button"
          onClick={handleManualUpdate}
          className="w-full bg-gray-700 text-white px-4 py-2.5 rounded-lg hover:bg-gray-800 transition-colors font-medium shadow-sm hover:shadow-md"
        >
          Set Manual Location
        </button>

        {error && (
          <div className="bg-red-50 text-red-600 p-2 rounded text-sm">
            {error}
          </div>
        )}

        {hasLocation && (
          <div className="bg-green-50 text-green-700 p-3 rounded text-sm space-y-2">
            <div className="font-medium">Location saved:</div>
            <div className="text-xs">
              Lat: {latitude?.toFixed(6)}, Lng: {longitude?.toFixed(6)}
            </div>
            {mapUrl && (
              <a
                href={mapUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-blue-600 hover:text-blue-700 text-xs underline"
              >
                <MapPin className="w-3 h-3" />
                View on map
              </a>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
