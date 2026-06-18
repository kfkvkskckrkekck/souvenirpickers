import { useState } from 'react';
import { Package, CheckCircle, AlertCircle, MessageSquare } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface OrderConfirmationProps {
  orderId: string;
  orderStatus: string;
  goodsConfirmed: boolean;
  pickerName: string;
  onConfirmed?: () => void;
}

export default function OrderConfirmation({
  orderId,
  orderStatus,
  goodsConfirmed,
  pickerName,
  onConfirmed
}: OrderConfirmationProps) {
  const [isConfirming, setIsConfirming] = useState(false);
  const [showFeedback, setShowFeedback] = useState(false);
  const [notes, setNotes] = useState('');
  const [error, setError] = useState('');

  const canConfirm =
    (orderStatus === 'in_progress' || orderStatus === 'delivered') &&
    !goodsConfirmed;

  const handleConfirm = async () => {
    if (!showFeedback) {
      setShowFeedback(true);
      return;
    }

    setIsConfirming(true);
    setError('');

    try {
      // Collector confirms delivery - this is the primary way delivery is confirmed
      const { data, error: rpcError } = await supabase.rpc('collector_confirm_delivery', {
        p_order_id: orderId,
        p_notes: notes.trim() || null
      });

      if (rpcError) throw rpcError;

      if (data?.success) {
        // Get session for edge function authentication
        const { data: { session } } = await supabase.auth.getSession();

        // If delivery was confirmed and we have escrow info, trigger the payout
        if (data.escrow_id && session) {
          // Call the edge function to process the actual Stripe transfer
          // This runs asynchronously - we don't wait for it
          fetch(
            `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/process-picker-payout`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${session.access_token}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                escrowId: data.escrow_id,
                pickerId: data.picker_id || data.released_to,
              }),
            }
          ).catch(err => {
            // Log but don't fail - the escrow is marked for processing
            console.error('Payout processing error (non-blocking):', err);
          });
        }

        onConfirmed?.();
      } else {
        setError(data?.error || 'Failed to confirm delivery');
      }
    } catch (err: any) {
      setError(err.message || 'An error occurred');
    } finally {
      setIsConfirming(false);
    }
  };

  if (goodsConfirmed) {
    return (
      <div className="bg-green-50 border border-green-200 rounded-lg p-4">
        <div className="flex items-start space-x-3">
          <CheckCircle className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
          <div className="flex-1">
            <h3 className="font-medium text-green-900">Delivery Confirmed</h3>
            <p className="text-sm text-green-700 mt-1">
              You confirmed delivery of this order. The picker has been paid.
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (!canConfirm) {
    return null;
  }

  return (
    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
      <div className="flex items-start space-x-3">
        <Package className="w-5 h-5 text-blue-600 mt-0.5 flex-shrink-0" />
        <div className="flex-1">
          <h3 className="font-medium text-blue-900">Confirm Delivery</h3>
          <p className="text-sm text-blue-700 mt-1 mb-3">
            Have you received your order from {pickerName}? Confirm delivery to release payment immediately, or it will be automatically released in 14 days.
          </p>
          <p className="text-xs text-blue-600 font-medium">
            Product payment is held in escrow for your protection - auto-releases in 14 days if not confirmed or disputed.
          </p>

          {!showFeedback ? (
            <div className="space-y-2">
              <button
                onClick={handleConfirm}
                className="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Confirm Delivery
              </button>
              <p className="text-xs text-blue-600">
                Only confirm when you have physically received the item
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <MessageSquare className="w-4 h-4 inline mr-1" />
                  Optional Feedback (visible to picker)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Great service! Item was exactly as described."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                  rows={3}
                />
              </div>

              {error && (
                <div className="flex items-center space-x-2 text-red-600 text-sm">
                  <AlertCircle className="w-4 h-4" />
                  <span>{error}</span>
                </div>
              )}

              <div className="flex space-x-2">
                <button
                  onClick={handleConfirm}
                  disabled={isConfirming}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isConfirming ? 'Confirming...' : 'Confirm Delivery & Release Payment'}
                </button>
                <button
                  onClick={() => setShowFeedback(false)}
                  disabled={isConfirming}
                  className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
                >
                  Cancel
                </button>
              </div>

              <p className="text-xs text-gray-500">
                By confirming, you acknowledge that you physically received the item as described and the picker will be paid immediately.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
