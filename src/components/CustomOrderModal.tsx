import { useState } from 'react';
import { X, DollarSign, Package, Truck as TruckIcon, Upload, Image as ImageIcon, MapPin, Clock } from 'lucide-react';
import { supabase, Profile } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { uploadImage } from '../lib/storage';

type CustomOrderModalProps = {
  recipientProfile: Profile;
  onClose: () => void;
  onOrderCreated?: () => void;
};

export function CustomOrderModal({ recipientProfile, onClose, onOrderCreated }: CustomOrderModalProps) {
  const { user, profile } = useAuth();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [basePrice, setBasePrice] = useState('');
  const [transportationCost, setTransportationCost] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [fromLocation, setFromLocation] = useState('');
  const [toLocation, setToLocation] = useState('');
  const [estimatedDays, setEstimatedDays] = useState('');

  // Structured delivery address fields
  const [deliveryStreet, setDeliveryStreet] = useState('');
  const [deliveryStreetLine2, setDeliveryStreetLine2] = useState('');
  const [deliveryCity, setDeliveryCity] = useState('');
  const [deliveryPostalCode, setDeliveryPostalCode] = useState('');
  const [deliveryCountry, setDeliveryCountry] = useState('');

  const [notes, setNotes] = useState('');
  const [images, setImages] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');

  const totalPrice = (parseFloat(basePrice) || 0) + (parseFloat(transportationCost) || 0);
  const grandTotal = totalPrice * quantity;

  // Helper function to format structured address into a single string
  const formatAddress = (street: string, line2: string, city: string, postal: string, country: string): string => {
    const parts = [
      street,
      line2,
      `${postal} ${city}`,
      country
    ].filter(part => part.trim());
    return parts.join(', ');
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadImage(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setImages([...images, ...urls]);
    } catch (error: any) {
      setError(error.message || 'Failed to upload images');
    } finally {
      setUploading(false);
    }
  };

  const removeImage = (url: string) => {
    setImages(images.filter(img => img !== url));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    // Verify user is a picker
    if (profile?.user_type !== 'picker') {
      setError('Only pickers can create custom orders.');
      return;
    }

    setSubmitting(true);
    setError('');

    try {
      // Get the picker_profile ID for the current user
      const { data: pickerProfile, error: pickerError } = await supabase
        .from('picker_profiles')
        .select('id')
        .eq('user_id', user.id)
        .single();

      if (pickerError || !pickerProfile) {
        throw new Error('Could not find picker profile. Please ensure your profile is set up correctly.');
      }

      // Format the delivery address
      const deliveryAddressFormatted = formatAddress(
        deliveryStreet,
        deliveryStreetLine2,
        deliveryCity,
        deliveryPostalCode,
        deliveryCountry
      ) || null;

      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 48); // Expires in 48 hours

      const { data: customOrder, error: insertError } = await supabase
        .from('custom_orders')
        .insert({
          picker_id: pickerProfile.id,
          client_id: recipientProfile.id,
          title,
          description,
          category: 'custom',
          region: fromLocation || 'Not specified',
          budget: grandTotal,
          reference_images: images,
          reference_links: [],
          base_price: parseFloat(basePrice) || 0,
          transportation_cost: parseFloat(transportationCost) || 0,
          total_price: totalPrice,
          quantity,
          images,
          delivery_address: deliveryAddressFormatted,
          notes,
          status: 'pending',
          expires_at: expiresAt.toISOString(),
        })
        .select()
        .single();

      if (insertError) {
        console.error('Error creating custom order:', insertError);
        throw insertError;
      }

      console.log('Custom order created successfully:', customOrder);

      // Get or create conversation
      let conversationId: string | null = null;

      const { data: existingConversations } = await supabase
        .from('conversations')
        .select('id')
        .or(`and(client_id.eq.${recipientProfile.id},picker_id.eq.${profile.id}),and(client_id.eq.${profile.id},picker_id.eq.${recipientProfile.id})`);

      if (existingConversations && existingConversations.length > 0) {
        conversationId = existingConversations[0].id;
      } else {
        // Create new conversation - use profile.id (from profiles table) not pickerProfile.id
        const { data: newConversation, error: convError } = await supabase
          .from('conversations')
          .insert({
            client_id: recipientProfile.id,
            picker_id: profile.id, // This should be the picker's profile.id from profiles table
            last_message: `Custom order: ${title}`,
            last_message_at: new Date().toISOString(),
            client_unread_count: 1,
            picker_unread_count: 0
          })
          .select('id')
          .single();

        if (!convError && newConversation) {
          conversationId = newConversation.id;
        } else if (convError) {
          console.error('Error creating conversation:', convError);
        }
      }

      if (conversationId) {
        // Send a chat message with custom order details
        const messageText = `📦 Custom Order Sent\n\n${title}\n\n💰 Total: €${grandTotal.toFixed(2)}\n${quantity > 1 ? `📦 Quantity: ${quantity}\n` : ''}${fromLocation && toLocation ? `📍 From ${fromLocation} to ${toLocation}\n` : ''}${estimatedDays ? `⏱️ Est. ${estimatedDays} days\n` : ''}\n✅ View in Custom Orders tab to accept or negotiate.`;

        await supabase
          .from('conversation_messages')
          .insert({
            conversation_id: conversationId,
            sender_id: profile.id,
            content: messageText,
            read: false
          });

        // Update conversation last message
        const unreadUpdate = profile.user_type === 'picker'
          ? { client_unread_count: supabase.rpc('increment') }
          : { picker_unread_count: supabase.rpc('increment') };

        await supabase
          .from('conversations')
          .update({
            last_message: messageText.substring(0, 100),
            last_message_at: new Date().toISOString()
          })
          .eq('id', conversationId);
      }

      // Send notification to recipient
      try {
        await supabase
          .from('notifications')
          .insert({
            user_id: recipientProfile.id,
            type: 'custom_order',
            title: 'New Custom Order Received',
            message: `${profile.full_name} sent you a custom order: ${title}`,
            metadata: { custom_order_id: customOrder.id },
            read: false
          });
      } catch (notifError) {
        console.error('Failed to send notification:', notifError);
      }

      if (onOrderCreated) onOrderCreated();
      onClose();
    } catch (err: any) {
      console.error('Failed to create custom order:', err);
      setError(err.message || 'Failed to create custom order. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">Create Custom Order</h2>
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
              This custom order will be sent to the collector. They can accept or reject it within 7 days.
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Title</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="e.g., Custom Handcrafted Souvenir"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Describe what you're offering in detail..."
              required
            />
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <DollarSign className="w-4 h-4 inline mr-1" />
                Base Item Price (€)
              </label>
              <input
                type="number"
                value={basePrice}
                onChange={(e) => setBasePrice(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="0.00"
                min="0"
                step="0.01"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                <Package className="w-4 h-4 inline mr-1" />
                Quantity
              </label>
              <input
                type="number"
                value={quantity}
                onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                min="1"
                required
              />
            </div>
          </div>

          <div className="border-t border-gray-200 pt-6">
            <div className="flex items-center gap-2 mb-4">
              <TruckIcon className="w-5 h-5 text-orange-600" />
              <h3 className="text-lg font-semibold text-gray-900">Transportation Details (Optional)</h3>
            </div>

            <div className="bg-orange-50 border-l-4 border-orange-500 p-4 rounded-r-lg mb-4">
              <p className="text-sm text-orange-800">
                Add transportation details to provide a complete quote including shipping from your location to the collector.
              </p>
            </div>

            <div className="grid md:grid-cols-2 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <MapPin className="w-4 h-4 inline mr-1" />
                  From Location
                </label>
                <input
                  type="text"
                  value={fromLocation}
                  onChange={(e) => setFromLocation(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="e.g., Paris, France"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <MapPin className="w-4 h-4 inline mr-1" />
                  To Location
                </label>
                <input
                  type="text"
                  value={toLocation}
                  onChange={(e) => setToLocation(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="e.g., Berlin, Germany"
                />
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <DollarSign className="w-4 h-4 inline mr-1" />
                  Transportation Cost (€)
                </label>
                <input
                  type="number"
                  value={transportationCost}
                  onChange={(e) => setTransportationCost(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="0.00"
                  min="0"
                  step="0.01"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <Clock className="w-4 h-4 inline mr-1" />
                  Estimated Delivery (days)
                </label>
                <input
                  type="number"
                  value={estimatedDays}
                  onChange={(e) => setEstimatedDays(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  placeholder="e.g., 3-5 days"
                  min="1"
                />
              </div>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <Package className="w-4 h-4 inline mr-1" />
              Quantity
            </label>
            <input
              type="number"
              value={quantity}
              onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              min="1"
              required
            />
          </div>

          {totalPrice > 0 && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <div className="space-y-1">
                <div className="flex items-center justify-between text-sm text-gray-700">
                  <span>Base item price:</span>
                  <span className="font-medium">€{parseFloat(basePrice || '0').toFixed(2)}</span>
                </div>
                {transportationCost && parseFloat(transportationCost) > 0 && (
                  <>
                    <div className="flex items-center justify-between text-sm text-gray-700">
                      <span className="flex items-center gap-1">
                        <TruckIcon className="w-3 h-3" />
                        Transportation:
                      </span>
                      <span className="font-medium">€{parseFloat(transportationCost).toFixed(2)}</span>
                    </div>
                    {fromLocation && toLocation && (
                      <p className="text-xs text-gray-600 flex items-center gap-1">
                        <MapPin className="w-3 h-3" />
                        {fromLocation} → {toLocation}
                        {estimatedDays && ` (${estimatedDays} days)`}
                      </p>
                    )}
                  </>
                )}
                <div className="flex items-center justify-between text-sm text-gray-700 pt-1">
                  <span>Unit total:</span>
                  <span className="font-medium">€{totalPrice.toFixed(2)}</span>
                </div>
                <div className="flex items-center justify-between text-sm text-gray-700">
                  <span>Quantity:</span>
                  <span className="font-medium">×{quantity}</span>
                </div>
                <div className="border-t border-green-300 pt-2 mt-2 flex items-center justify-between">
                  <span className="font-semibold text-gray-900">Total Price:</span>
                  <span className="text-2xl font-bold text-green-700">€{grandTotal.toFixed(2)}</span>
                </div>
              </div>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              <ImageIcon className="w-4 h-4 inline mr-1" />
              Images (optional)
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
              <input
                type="file"
                accept="image/jpeg,image/jpg,image/png,image/webp"
                multiple
                onChange={handleImageUpload}
                className="hidden"
                id="custom-order-images"
                disabled={uploading}
              />
              <label
                htmlFor="custom-order-images"
                className="flex flex-col items-center justify-center cursor-pointer"
              >
                <Upload className="w-8 h-8 text-gray-400 mb-2" />
                <span className="text-sm text-gray-600">
                  Click to upload images
                </span>
              </label>
            </div>

            {images.length > 0 && (
              <div className="grid grid-cols-3 gap-3 mt-3">
                {images.map((url, index) => (
                  <div key={index} className="relative group">
                    <img
                      src={url}
                      alt={`Upload ${index + 1}`}
                      className="w-full h-24 object-cover rounded-lg"
                    />
                    <button
                      type="button"
                      onClick={() => removeImage(url)}
                      className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="space-y-3">
            <label className="block text-sm font-medium text-gray-700">
              Delivery Address (optional)
            </label>

            <div>
              <input
                type="text"
                name="custom-street-address"
                autoComplete="street-address"
                value={deliveryStreet}
                onChange={(e) => setDeliveryStreet(e.target.value)}
                placeholder="Street address"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            <div>
              <input
                type="text"
                name="custom-address-line2"
                autoComplete="address-line2"
                value={deliveryStreetLine2}
                onChange={(e) => setDeliveryStreetLine2(e.target.value)}
                placeholder="Apartment, suite, unit, etc. (optional)"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <input
                  type="text"
                  name="custom-city"
                  autoComplete="address-level2"
                  value={deliveryCity}
                  onChange={(e) => setDeliveryCity(e.target.value)}
                  placeholder="City"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <div>
                <input
                  type="text"
                  name="custom-postal-code"
                  autoComplete="postal-code"
                  value={deliveryPostalCode}
                  onChange={(e) => setDeliveryPostalCode(e.target.value)}
                  placeholder="Postal code"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>

            <div>
              <input
                type="text"
                name="custom-country"
                autoComplete="country-name"
                value={deliveryCountry}
                onChange={(e) => setDeliveryCountry(e.target.value)}
                placeholder="Country"
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Additional Notes (optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Any additional information or special requests"
            />
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
              disabled={submitting || uploading}
              className="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {submitting ? 'Sending...' : 'Send Custom Order'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
