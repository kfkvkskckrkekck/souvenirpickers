import { useState } from 'react';
import { X, Package, DollarSign, MapPin, Gift } from 'lucide-react';
import { supabase, Listing, Profile, Order } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { StripeCheckoutForm } from './StripeCheckoutForm';

const COUNTRIES = [
  'United States', 'Canada', 'United Kingdom', 'Australia', 'Germany', 'France',
  'Italy', 'Spain', 'Netherlands', 'Belgium', 'Switzerland', 'Austria', 'Sweden',
  'Norway', 'Denmark', 'Finland', 'Ireland', 'Portugal', 'Greece', 'Poland',
  'Czech Republic', 'Hungary', 'Romania', 'Bulgaria', 'Croatia', 'Slovenia',
  'Slovakia', 'Lithuania', 'Latvia', 'Estonia', 'Luxembourg', 'Malta', 'Cyprus',
  'Japan', 'South Korea', 'Singapore', 'New Zealand', 'Mexico', 'Brazil',
  'Argentina', 'Chile', 'Colombia', 'Peru', 'Venezuela', 'Ecuador', 'Uruguay',
  'Paraguay', 'Bolivia', 'Costa Rica', 'Panama', 'Guatemala', 'Honduras',
  'El Salvador', 'Nicaragua', 'Dominican Republic', 'Puerto Rico', 'Jamaica',
  'Trinidad and Tobago', 'Bahamas', 'Barbados', 'Iceland', 'Turkey', 'Israel',
  'United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait', 'Bahrain', 'Oman',
  'Jordan', 'Lebanon', 'Egypt', 'Morocco', 'Tunisia', 'Algeria', 'South Africa',
  'Kenya', 'Nigeria', 'Ghana', 'Ethiopia', 'Tanzania', 'Uganda', 'Rwanda',
  'Senegal', 'Ivory Coast', 'Cameroon', 'Angola', 'Mozambique', 'Zambia',
  'Zimbabwe', 'Botswana', 'Namibia', 'Mauritius', 'Seychelles', 'India',
  'Pakistan', 'Bangladesh', 'Sri Lanka', 'Nepal', 'Bhutan', 'Maldives',
  'Thailand', 'Vietnam', 'Malaysia', 'Indonesia', 'Philippines', 'Cambodia',
  'Laos', 'Myanmar', 'Brunei', 'China', 'Hong Kong', 'Taiwan', 'Macau',
  'Mongolia', 'Kazakhstan', 'Uzbekistan', 'Turkmenistan', 'Kyrgyzstan',
  'Tajikistan', 'Afghanistan', 'Iran', 'Iraq', 'Syria', 'Yemen'
].sort();

const COUNTRY_NAME_TO_CODE: Record<string, string> = {
  'United States': 'US', 'Canada': 'CA', 'United Kingdom': 'GB', 'Australia': 'AU',
  'Germany': 'DE', 'France': 'FR', 'Italy': 'IT', 'Spain': 'ES', 'Netherlands': 'NL',
  'Belgium': 'BE', 'Switzerland': 'CH', 'Austria': 'AT', 'Sweden': 'SE', 'Norway': 'NO',
  'Denmark': 'DK', 'Finland': 'FI', 'Ireland': 'IE', 'Portugal': 'PT', 'Greece': 'GR',
  'Poland': 'PL', 'Czech Republic': 'CZ', 'Hungary': 'HU', 'Romania': 'RO', 'Bulgaria': 'BG',
  'Croatia': 'HR', 'Slovenia': 'SI', 'Slovakia': 'SK', 'Lithuania': 'LT', 'Latvia': 'LV',
  'Estonia': 'EE', 'Luxembourg': 'LU', 'Malta': 'MT', 'Cyprus': 'CY', 'Japan': 'JP',
  'South Korea': 'KR', 'Singapore': 'SG', 'New Zealand': 'NZ', 'Mexico': 'MX', 'Brazil': 'BR',
  'Argentina': 'AR', 'Chile': 'CL', 'Colombia': 'CO', 'Peru': 'PE', 'Venezuela': 'VE',
  'Ecuador': 'EC', 'Uruguay': 'UY', 'Paraguay': 'PY', 'Bolivia': 'BO', 'Costa Rica': 'CR',
  'Panama': 'PA', 'Guatemala': 'GT', 'Honduras': 'HN', 'El Salvador': 'SV', 'Nicaragua': 'NI',
  'Dominican Republic': 'DO', 'Puerto Rico': 'PR', 'Jamaica': 'JM', 'Trinidad and Tobago': 'TT',
  'Bahamas': 'BS', 'Barbados': 'BB', 'Iceland': 'IS', 'Turkey': 'TR', 'Israel': 'IL',
  'United Arab Emirates': 'AE', 'Saudi Arabia': 'SA', 'Qatar': 'QA', 'Kuwait': 'KW',
  'Bahrain': 'BH', 'Oman': 'OM', 'Jordan': 'JO', 'Lebanon': 'LB', 'Egypt': 'EG',
  'Morocco': 'MA', 'Tunisia': 'TN', 'Algeria': 'DZ', 'South Africa': 'ZA', 'Kenya': 'KE',
  'Nigeria': 'NG', 'Ghana': 'GH', 'Ethiopia': 'ET', 'Tanzania': 'TZ', 'Uganda': 'UG',
  'Rwanda': 'RW', 'Senegal': 'SN', 'Ivory Coast': 'CI', 'Cameroon': 'CM', 'Angola': 'AO',
  'Mozambique': 'MZ', 'Zambia': 'ZM', 'Zimbabwe': 'ZW', 'Botswana': 'BW', 'Namibia': 'NA',
  'Mauritius': 'MU', 'Seychelles': 'SC', 'India': 'IN', 'Pakistan': 'PK', 'Bangladesh': 'BD',
  'Sri Lanka': 'LK', 'Nepal': 'NP', 'Bhutan': 'BT', 'Maldives': 'MV', 'Thailand': 'TH',
  'Vietnam': 'VN', 'Malaysia': 'MY', 'Indonesia': 'ID', 'Philippines': 'PH', 'Cambodia': 'KH',
  'Laos': 'LA', 'Myanmar': 'MM', 'Brunei': 'BN', 'China': 'CN', 'Hong Kong': 'HK',
  'Taiwan': 'TW', 'Macau': 'MO', 'Mongolia': 'MN', 'Kazakhstan': 'KZ', 'Uzbekistan': 'UZ',
  'Turkmenistan': 'TM', 'Kyrgyzstan': 'KG', 'Tajikistan': 'TJ', 'Afghanistan': 'AF',
  'Iran': 'IR', 'Iraq': 'IQ', 'Syria': 'SY', 'Yemen': 'YE',
};

function toCountryCode(name: string): string {
  if (!name) return '';
  if (/^[A-Z]{2}$/.test(name.trim().toUpperCase())) return name.trim().toUpperCase();
  return COUNTRY_NAME_TO_CODE[name.trim()] || '';
}

type ShippingRate = {
  id: number;
  name: string;
  carrier: string;
  min_days: number;
  max_days: number;
  price: number;
};

type OrderCheckoutModalProps = {
  listing: Listing & { picker?: { profile?: Profile } };
  onClose: () => void;
  onOrderCreated: (order: Order) => void;
};

export function OrderCheckoutModal({ listing, onClose, onOrderCreated }: OrderCheckoutModalProps) {
  const { profile, user } = useAuth();
  const [quantity, setQuantity] = useState(1);

  // Structured delivery address fields
  const [deliveryStreet, setDeliveryStreet] = useState('');
  const [deliveryBuilding, setDeliveryBuilding] = useState('');
  const [deliveryApartment, setDeliveryApartment] = useState('');
  const [deliveryCity, setDeliveryCity] = useState('');
  const [deliveryState, setDeliveryState] = useState('');
  const [deliveryPostalCode, setDeliveryPostalCode] = useState('');
  const [deliveryCountry, setDeliveryCountry] = useState('');

  const [deliveryInstructions, setDeliveryInstructions] = useState('');
  const [notes, setNotes] = useState('');
  const [isGift, setIsGift] = useState(false);
  const [giftRecipientName, setGiftRecipientName] = useState('');
  const [giftRecipientEmail, setGiftRecipientEmail] = useState('');
  const [giftMessage, setGiftMessage] = useState('');

  // Structured gift recipient address fields
  const [giftStreet, setGiftStreet] = useState('');
  const [giftBuilding, setGiftBuilding] = useState('');
  const [giftApartment, setGiftApartment] = useState('');
  const [giftCity, setGiftCity] = useState('');
  const [giftState, setGiftState] = useState('');
  const [giftPostalCode, setGiftPostalCode] = useState('');
  const [giftCountry, setGiftCountry] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [showPayment, setShowPayment] = useState(false);
  const [createdOrderId, setCreatedOrderId] = useState<string | null>(null);
  const [shippingRates, setShippingRates] = useState<ShippingRate[]>([]);
  const [selectedShippingRate, setSelectedShippingRate] = useState<ShippingRate | null>(null);
  const [loadingRates, setLoadingRates] = useState(false);

  const itemTotal = listing.price * quantity;
  const shippingTotal = selectedShippingRate?.price || 0;
  const totalPrice = itemTotal + shippingTotal;

  // Helper function to format structured address into a single string
  const formatAddress = (street: string, building: string, apartment: string, city: string, state: string, postal: string, country: string): string => {
    const parts = [
      street,
      building,
      apartment,
      city,
      state,
      postal,
      country
    ].filter(part => part && part.trim());
    return parts.join('\n');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profile || !user || !listing.picker_id) return;

    setSubmitting(true);
    setError('');

    try {
      if (!selectedShippingRate) {
        setLoadingRates(true);
        const { data: rateData, error: rateError } = await supabase.functions.invoke('get-shipping-rates', {
          body: {
            product_id: listing.id,
            buyer_postcode: isGift ? giftPostalCode : deliveryPostalCode,
            buyer_city: isGift ? giftCity : deliveryCity,
            buyer_country: toCountryCode(isGift ? giftCountry : deliveryCountry),
          },
        });
        if (rateError) {
          const serverMsg = (rateData as { error?: string } | null)?.error;
          throw new Error(serverMsg || rateError.message || 'Unable to get shipping rates. Please try again.');
        }
        if (rateData?.error) throw new Error(rateData.error);
        const rates = Array.isArray(rateData?.rates) ? rateData.rates as ShippingRate[] : [];
        if (rates.length === 0) throw new Error('Shipping is not available for this destination. Please contact the seller.');
        setShippingRates(rates);
        setError('Choose a shipping option to continue.');
        return;
      }

      // Format addresses
      const deliveryAddressFormatted = formatAddress(
        deliveryStreet,
        deliveryBuilding,
        deliveryApartment,
        deliveryCity,
        deliveryState,
        deliveryPostalCode,
        deliveryCountry
      );

      const giftRecipientAddressFormatted = isGift ? formatAddress(
        giftStreet,
        giftBuilding,
        giftApartment,
        giftCity,
        giftState,
        giftPostalCode,
        giftCountry
      ) : null;

      // Get the picker's user_id from picker_profiles
      const { data: pickerProfile, error: pickerError } = await supabase
        .from('picker_profiles')
        .select('user_id')
        .eq('id', listing.picker_id)
        .maybeSingle();

      if (pickerError) throw pickerError;
      if (!pickerProfile) throw new Error('Picker not found');

      const { data, error: insertError } = await supabase
        .from('orders')
        .insert({
          client_id: user.id,
          picker_id: pickerProfile.user_id,
          listing_id: listing.id,
          quantity,
          total_price: totalPrice,
          shipping_cost: shippingTotal,
          shipping_carrier: selectedShippingRate.carrier,
          shipping_service: selectedShippingRate.name,
          estimated_delivery_days: selectedShippingRate.max_days > 0
            ? `${selectedShippingRate.min_days}-${selectedShippingRate.max_days} business days`
            : null,
          delivery_address: isGift ? giftRecipientAddressFormatted : (deliveryAddressFormatted || null),
          delivery_street: isGift ? giftStreet : deliveryStreet,
          delivery_street_line2: isGift ? `${giftBuilding || ''}${giftApartment ? ' ' + giftApartment : ''}`.trim() || null : `${deliveryBuilding || ''}${deliveryApartment ? ' ' + deliveryApartment : ''}`.trim() || null,
          delivery_city: isGift ? giftCity : deliveryCity,
          delivery_postal_code: isGift ? giftPostalCode : deliveryPostalCode,
          delivery_country: isGift
            ? (giftState ? `${giftState}, ${giftCountry}` : giftCountry)
            : (deliveryState ? `${deliveryState}, ${deliveryCountry}` : deliveryCountry),
          delivery_instructions: deliveryInstructions || null,
          notes: notes || null,
          status: 'pending',
          payment_status: 'pending',
          tracking_status: 'pending',
          is_gift: isGift,
          gift_recipient_name: isGift ? giftRecipientName : null,
          gift_recipient_email: isGift ? giftRecipientEmail : null,
          gift_message: isGift ? giftMessage : null,
          gift_recipient_address: isGift ? giftRecipientAddressFormatted : null,
        })
        .select()
        .maybeSingle();

      if (insertError) throw insertError;
      if (!data) throw new Error('Order creation returned no data');

      await supabase
        .from('order_status_history')
        .insert({
          order_id: data.id,
          status: 'pending',
          notes: 'Order created',
          changed_by: user.id,
        });

      setCreatedOrderId(data.id);
      setShowPayment(true);
    } catch (err) {

      setError('Failed to create order. Please try again.');
    } finally {
      setSubmitting(false);
      setLoadingRates(false);
    }
  };

  const handlePaymentSuccess = async () => {
    if (createdOrderId) {
      const { data } = await supabase
        .from('orders')
        .select('*')
        .eq('id', createdOrderId)
        .single();

      if (data) {
        onOrderCreated(data);
      }
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-2 sm:p-4 z-50">
      <div className="bg-white rounded-xl sm:rounded-2xl max-w-2xl w-full max-h-[95vh] sm:max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-4 sm:px-6 py-3 sm:py-4 flex items-center justify-between">
          <h2 className="text-lg sm:text-xl md:text-2xl font-bold text-gray-900">Complete Your Order</h2>
          <button
            onClick={onClose}
            className="p-1.5 sm:p-2 hover:bg-gray-100 rounded-lg transition-colors flex-shrink-0"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-4 sm:p-6 space-y-4 sm:space-y-6">
          <div className="bg-gray-50 rounded-lg sm:rounded-xl p-3 sm:p-4">
            <div className="flex gap-3 sm:gap-4">
              {listing.images[0] && (
                <img
                  src={listing.images[0]}
                  alt={listing.title}
                  className="w-20 h-20 sm:w-24 sm:h-24 object-cover rounded-lg flex-shrink-0"
                />
              )}
              <div className="flex-1 min-w-0">
                <h3 className="font-semibold text-sm sm:text-base text-gray-900 line-clamp-2">{listing.title}</h3>
                <p className="text-xs sm:text-sm text-gray-600 mt-1">{listing.category}</p>
                <div className="mt-1 sm:mt-2">
                  <p className="text-base sm:text-lg font-bold text-gray-900">
                    €{listing.price.toFixed(2)} each
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div>
            <label className="block text-xs sm:text-sm font-medium text-gray-700 mb-2">
              <Package className="w-3 h-3 sm:w-4 sm:h-4 inline mr-2" />
              Quantity <span className="text-red-600">*</span>
            </label>
            <input
              type="number"
              min="1"
              value={quantity}
              onChange={(e) => setQuantity(Math.max(1, parseInt(e.target.value) || 1))}
              className="w-full px-3 sm:px-4 py-2 sm:py-3 text-sm sm:text-base border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              required
            />
          </div>

          <div className="bg-green-50 rounded-lg sm:rounded-xl p-3 sm:p-4 border-2 border-green-200">
            <label className="flex items-start sm:items-center gap-2 sm:gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={isGift}
                onChange={(e) => setIsGift(e.target.checked)}
                className="w-4 h-4 sm:w-5 sm:h-5 text-green-600 rounded focus:ring-2 focus:ring-green-500 flex-shrink-0 mt-0.5 sm:mt-0"
              />
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <Gift className="w-4 h-4 sm:w-5 sm:h-5 text-green-600 flex-shrink-0" />
                <span className="font-medium text-sm sm:text-base text-gray-900">Send as a gift</span>
              </div>
            </label>
            <p className="text-xs sm:text-sm text-gray-600 mt-2 ml-6 sm:ml-8">
              Send this souvenir to someone special with a personalized message
            </p>
          </div>

          {isGift ? (
            <>
              <div className="bg-green-50 rounded-xl p-4 space-y-4">
                <h3 className="font-semibold text-gray-900 flex items-center gap-2">
                  <Gift className="w-5 h-5 text-green-600" />
                  Gift Information
                </h3>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Recipient Name <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="text"
                    value={giftRecipientName}
                    onChange={(e) => setGiftRecipientName(e.target.value)}
                    placeholder="Who is this gift for?"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    required={isGift}
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Recipient Email <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="email"
                    value={giftRecipientEmail}
                    onChange={(e) => setGiftRecipientEmail(e.target.value)}
                    placeholder="recipient@example.com"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                    required={isGift}
                  />
                  <p className="text-xs text-gray-500 mt-1">They'll receive a notification when the gift is on its way</p>
                </div>

                <div className="space-y-3">
                  <label className="block text-sm font-medium text-gray-700">
                    <MapPin className="w-4 h-4 inline mr-2" />
                    Recipient Delivery Address <span className="text-red-600">*</span>
                  </label>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Street Address <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      name="gift-street-address"
                      autoComplete="shipping street-address"
                      value={giftStreet}
                      onChange={(e) => setGiftStreet(e.target.value)}
                      placeholder="Pescarusului 28 G"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                      required={isGift}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Building Number <span className="text-gray-500">(optional)</span>
                      </label>
                      <input
                        type="text"
                        value={giftBuilding}
                        onChange={(e) => setGiftBuilding(e.target.value)}
                        placeholder="Building 2"
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Apartment/Unit <span className="text-gray-500">(optional)</span>
                      </label>
                      <input
                        type="text"
                        value={giftApartment}
                        onChange={(e) => setGiftApartment(e.target.value)}
                        placeholder="Apt 4B"
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Country <span className="text-red-600">*</span>
                    </label>
                    <select
                      name="gift-country"
                      autoComplete="shipping country-name"
                      value={giftCountry}
                      onChange={(e) => {
                        setGiftCountry(e.target.value);
                        if (e.target.value !== 'United States') {
                          setGiftState('');
                        }
                      }}
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                      required={isGift}
                    >
                      <option value="">Select a country</option>
                      {COUNTRIES.map(country => (
                        <option key={country} value={country}>{country}</option>
                      ))}
                    </select>
                  </div>

                  {giftCountry === 'United States' && (
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        State <span className="text-red-600">*</span>
                      </label>
                      <input
                        type="text"
                        value={giftState}
                        onChange={(e) => setGiftState(e.target.value)}
                        placeholder="California"
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                        required={isGift}
                      />
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        City <span className="text-red-600">*</span>
                      </label>
                      <input
                        type="text"
                        name="gift-city"
                        autoComplete="shipping address-level2"
                        value={giftCity}
                        onChange={(e) => setGiftCity(e.target.value)}
                        placeholder="Municipiul București"
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                        required={isGift}
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Postal/ZIP Code <span className="text-red-600">*</span>
                      </label>
                      <input
                        type="text"
                        name="gift-postal-code"
                        autoComplete="shipping postal-code"
                        value={giftPostalCode}
                        onChange={(e) => setGiftPostalCode(e.target.value)}
                        placeholder="077065"
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm sm:text-base"
                        required={isGift}
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Gift Message
                  </label>
                  <textarea
                    value={giftMessage}
                    onChange={(e) => setGiftMessage(e.target.value)}
                    placeholder="Write a personal message for your gift recipient..."
                    rows={3}
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                  />
                </div>
              </div>
            </>
          ) : (
            <div className="space-y-4">
              <div className="space-y-3">
                <label className="block text-sm font-medium text-gray-700">
                  <MapPin className="w-4 h-4 inline mr-2" />
                  Delivery Address <span className="text-red-600">*</span>
                </label>

                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Street Address <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="text"
                    name="street-address"
                    autoComplete="street-address"
                    value={deliveryStreet}
                    onChange={(e) => setDeliveryStreet(e.target.value)}
                    placeholder="Pescarusului 28 G"
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                    required
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Building Number <span className="text-gray-500">(optional)</span>
                    </label>
                    <input
                      type="text"
                      value={deliveryBuilding}
                      onChange={(e) => setDeliveryBuilding(e.target.value)}
                      placeholder="Building 2"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Apartment/Unit <span className="text-gray-500">(optional)</span>
                    </label>
                    <input
                      type="text"
                      value={deliveryApartment}
                      onChange={(e) => setDeliveryApartment(e.target.value)}
                      placeholder="Apt 4B"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">
                    Country <span className="text-red-600">*</span>
                  </label>
                  <select
                    name="country"
                    autoComplete="country-name"
                    value={deliveryCountry}
                    onChange={(e) => {
                      setDeliveryCountry(e.target.value);
                      if (e.target.value !== 'United States') {
                        setDeliveryState('');
                      }
                    }}
                    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                    required
                  >
                    <option value="">Select a country</option>
                    {COUNTRIES.map(country => (
                      <option key={country} value={country}>{country}</option>
                    ))}
                  </select>
                </div>

                {deliveryCountry === 'United States' && (
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      State <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      value={deliveryState}
                      onChange={(e) => setDeliveryState(e.target.value)}
                      placeholder="California"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                      required
                    />
                  </div>
                )}

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      City <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      name="city"
                      autoComplete="address-level2"
                      value={deliveryCity}
                      onChange={(e) => setDeliveryCity(e.target.value)}
                      placeholder="Municipiul București"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">
                      Postal/ZIP Code <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      name="postal-code"
                      autoComplete="postal-code"
                      value={deliveryPostalCode}
                      onChange={(e) => setDeliveryPostalCode(e.target.value)}
                      placeholder="077065"
                      className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm sm:text-base"
                      required
                    />
                  </div>
                </div>
              </div>

              <div className="bg-blue-50 border-2 border-blue-200 rounded-lg p-4">
                <h4 className="text-sm font-semibold text-gray-900 mb-3">Choose Shipping</h4>
                {shippingRates.length > 0 ? (
                  <div className="space-y-2">
                    {shippingRates.map((rate) => (
                      <button type="button" key={rate.id} onClick={() => { setSelectedShippingRate(rate); setError(''); }} className={`w-full text-left rounded-lg border-2 p-3 transition-colors ${selectedShippingRate?.id === rate.id ? 'border-blue-600 bg-white' : 'border-blue-100 bg-white/70 hover:border-blue-400'}`}>
                        <div className="flex items-center justify-between gap-3">
                          <div><p className="font-semibold text-gray-900">{rate.carrier}</p><p className="text-sm text-gray-700">{rate.name}</p><p className="text-xs text-gray-500">{rate.min_days}-{rate.max_days} business days</p></div>
                          <span className="font-bold text-gray-900">€{rate.price.toFixed(2)}</span>
                        </div>
                      </button>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-gray-700">Shipping rates will be calculated after you submit your delivery address.</p>
                )}
                {loadingRates && <p className="text-sm text-blue-700 mt-3">Calculating shipping rates...</p>}
              </div>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Delivery Instructions (Optional)
            </label>
            <textarea
              value={deliveryInstructions}
              onChange={(e) => setDeliveryInstructions(e.target.value)}
              placeholder="Any special instructions for the picker"
              rows={2}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Additional Notes (Optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Any additional information"
              rows={2}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          {showPayment && createdOrderId ? (
            <div className="bg-gray-50 rounded-xl p-6">
              <h3 className="text-lg font-bold text-gray-900 mb-4">Complete Payment</h3>
              <StripeCheckoutForm
                orderId={createdOrderId}
                amount={totalPrice}
                onSuccess={handlePaymentSuccess}
                onCancel={() => {
                  setShowPayment(false);
                  setCreatedOrderId(null);
                }}
              />
            </div>
          ) : null}

          <div className="bg-blue-50 rounded-xl p-4">
            <div className="space-y-2 mb-3">
              <div className="flex items-center justify-between text-sm text-gray-700">
                <span>Item price ({quantity}x):</span>
                <span>€{itemTotal.toFixed(2)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-gray-600 italic">
                <span>Shipping:</span>
                <span>€{shippingTotal.toFixed(2)}</span>
              </div>
              <div className="border-t border-blue-200 pt-2"></div>
              <div className="flex items-center justify-between text-lg font-bold">
                <span className="flex items-center gap-2">
                  <DollarSign className="w-5 h-5" />
                  Initial Total:
                </span>
                <span className="text-blue-600">€{totalPrice.toFixed(2)}</span>
              </div>
              <p className="text-xs text-gray-600 italic">Shipping is calculated automatically from the seller's package details.</p>
            </div>
            <div className="mt-3 p-3 bg-white rounded-lg border border-blue-200">
              <div className="flex items-start gap-2">
                <div className="w-5 h-5 bg-blue-600 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                  <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                  </svg>
                </div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-gray-900">Escrow Payment Protection</p>
                  <p className="text-xs text-gray-600 mt-1">
                    Your payment is held securely until you confirm delivery. Payment will be processed after shipping costs are confirmed and you approve the final total.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
              {error}
            </div>
          )}

          {!showPayment && (
            <div className="flex flex-col sm:flex-row gap-2 sm:gap-3">
              <button
                type="button"
                onClick={onClose}
                className="w-full sm:flex-1 px-6 py-3 border border-gray-300 rounded-lg text-sm sm:text-base font-medium text-gray-700 hover:bg-gray-50 transition-colors order-2 sm:order-1"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="w-full sm:flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg text-sm sm:text-base font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed order-1 sm:order-2"
              >
                {loadingRates ? 'Calculating Shipping...' : submitting ? 'Creating Order...' : selectedShippingRate ? 'Place Order' : 'Get Shipping Rates'}
              </button>
            </div>
          )}
        </form>
      </div>
    </div>
  );
}
