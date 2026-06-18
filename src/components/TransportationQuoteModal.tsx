import { useState } from 'react';
import { X, Truck as TruckIcon, MapPin, DollarSign, Package } from 'lucide-react';
import { supabase, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

type TransportationQuoteModalProps = {
  recipientProfile: Profile;
  conversationId: string;
  onClose: () => void;
  onQuoteSent?: () => void;
};

export function TransportationQuoteModal({
  recipientProfile,
  conversationId,
  onClose,
  onQuoteSent,
}: TransportationQuoteModalProps) {
  const { user, profile } = useAuth();
  const [fromLocation, setFromLocation] = useState('');
  const [toLocation, setToLocation] = useState('');
  const [itemDescription, setItemDescription] = useState('');
  const [transportationCost, setTransportationCost] = useState('');
  const [estimatedDays, setEstimatedDays] = useState('');
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !profile) return;

    setSubmitting(true);
    setError('');

    try {
      const { error: insertError } = await supabase.from('transportation_quotes').insert({
        conversation_id: conversationId,
        picker_id: user.id,
        client_id: recipientProfile.id,
        from_location: fromLocation,
        to_location: toLocation,
        item_description: itemDescription,
        transportation_cost: parseFloat(transportationCost),
        estimated_delivery_days: parseInt(estimatedDays) || null,
        notes: notes || null,
        status: 'pending',
      });

      if (insertError) throw insertError;

      await supabase.from('conversation_messages').insert({
        conversation_id: conversationId,
        sender_id: user.id,
        content: `🚚 Transportation Quote Sent\n\nFrom: ${fromLocation}\nTo: ${toLocation}\nItem: ${itemDescription}\nCost: €${parseFloat(transportationCost).toFixed(2)}\nEstimated Delivery: ${estimatedDays} days\n\nPlease review and accept the quote to proceed.`,
        read: false,
      });

      await supabase.from('notifications').insert({
        user_id: recipientProfile.id,
        type: 'transportation_quote',
        title: 'New Transportation Quote',
        message: `${profile.full_name} sent you a transportation quote for €${parseFloat(transportationCost).toFixed(2)}`,
        link: '/messages',
      });

      if (onQuoteSent) onQuoteSent();
      onClose();
    } catch (err) {
      setError('Failed to send transportation quote. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="bg-orange-100 p-2 rounded-lg">
              <TruckIcon className="w-6 h-6 text-orange-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900">Send Transportation Quote</h2>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
            <p className="text-sm text-blue-800">
              <strong>Sending to:</strong> {recipientProfile.full_name}
            </p>
            <p className="text-xs text-gray-600 mt-1">
              This transportation quote will be sent to the collector. They can accept or reject it.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <MapPin className="w-4 h-4 inline mr-1" />
              From Location <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={fromLocation}
              onChange={(e) => setFromLocation(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="e.g., Paris, France"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <MapPin className="w-4 h-4 inline mr-1" />
              To Location <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={toLocation}
              onChange={(e) => setToLocation(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="e.g., Berlin, Germany"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <Package className="w-4 h-4 inline mr-1" />
              Item Description <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={itemDescription}
              onChange={(e) => setItemDescription(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="e.g., Handcrafted souvenir (2kg)"
              required
            />
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="w-4 h-4 inline mr-1" />
                Transportation Cost (€) <span className="text-red-600">*</span>
              </label>
              <input
                type="number"
                value={transportationCost}
                onChange={(e) => setTransportationCost(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="0.00"
                min="0"
                step="0.01"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <TruckIcon className="w-4 h-4 inline mr-1" />
                Estimated Delivery (days) <span className="text-red-600">*</span>
              </label>
              <input
                type="number"
                value={estimatedDays}
                onChange={(e) => setEstimatedDays(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="e.g., 3-5 days"
                min="1"
                required
              />
            </div>
          </div>

          {transportationCost && (
            <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-gray-900">Total Transportation Cost:</span>
                <span className="text-2xl font-bold text-orange-600">
                  €{parseFloat(transportationCost).toFixed(2)}
                </span>
              </div>
              {estimatedDays && (
                <p className="text-sm text-gray-600 mt-2">
                  Estimated delivery in {estimatedDays} days
                </p>
              )}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Additional Notes (optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Any special instructions, insurance options, or tracking details..."
            />
          </div>

          <div className="bg-blue-50 border-l-4 border-blue-500 p-4 rounded-r-lg">
            <p className="text-sm text-blue-800">
              <strong>Note:</strong> Once the collector accepts this quote, you can proceed with creating a custom order that includes this transportation cost.
            </p>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              {error}
            </div>
          )}

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 px-6 py-3 bg-orange-600 text-white rounded-lg font-medium hover:bg-orange-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <TruckIcon className="w-5 h-5" />
              {submitting ? 'Sending...' : 'Send Quote'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
