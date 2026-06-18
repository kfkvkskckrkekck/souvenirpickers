import { useState, useEffect } from 'react';
import { Save, MapPin, Tag, Plus, X, Upload, User, Building2, Video, CreditCard, Facebook, Twitter, Instagram, RefreshCw, Package, ShoppingBag, DollarSign, CheckCircle, AlertCircle, Loader, ExternalLink, Award } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { supabase, PickerProfile, PaymentMethod } from '../lib/supabase';
import { uploadAvatar, uploadVideo } from '../lib/storage';
import { LocationPicker } from './LocationPicker';
import { SimplePaymentForm } from './SimplePaymentForm';
import { PayoutSetup } from './PayoutSetup';

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
  'Tajikistan', 'Afghanistan', 'Iran', 'Iraq', 'Syria', 'Yemen', 'Oman'
].sort();

export function ProfileView() {
  const { profile, user } = useAuth();
  const [pickerProfile, setPickerProfile] = useState<PickerProfile | null>(null);
  const [fullName, setFullName] = useState(profile?.full_name || '');
  const [bio, setBio] = useState(profile?.bio || '');
  const [currentLocation, setCurrentLocation] = useState('');
  const [regions, setRegions] = useState<string[]>([]);
  const [specialties, setSpecialties] = useState<string[]>([]);
  const [latitude, setLatitude] = useState<number | undefined>();
  const [longitude, setLongitude] = useState<number | undefined>();
  const [newRegion, setNewRegion] = useState('');
  const [newSpecialty, setNewSpecialty] = useState('');
  const [avatarUrl, setAvatarUrl] = useState(profile?.avatar_url || '');
  const [portfolioVideos, setPortfolioVideos] = useState<string[]>([]);
  const [newVideoLink, setNewVideoLink] = useState('');
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [billingStreet, setBillingStreet] = useState('');
  const [billingBuilding, setBillingBuilding] = useState('');
  const [billingApartment, setBillingApartment] = useState('');
  const [billingCity, setBillingCity] = useState('');
  const [billingState, setBillingState] = useState('');
  const [billingPostalCode, setBillingPostalCode] = useState('');
  const [billingCountry, setBillingCountry] = useState('');
  const [billingPhone, setBillingPhone] = useState('');
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [showPaymentForm, setShowPaymentForm] = useState(false);
  const [paymentMethodType, setPaymentMethodType] = useState<PaymentMethod['method_type']>('credit_card');
  const [cardNumber, setCardNumber] = useState('');
  const [cardholderName, setCardholderName] = useState('');
  const [expiryMonth, setExpiryMonth] = useState('');
  const [expiryYear, setExpiryYear] = useState('');
  const [cvv, setCvv] = useState('');
  const [facebookUrl, setFacebookUrl] = useState(profile?.facebook_url || '');
  const [twitterUrl, setTwitterUrl] = useState(profile?.twitter_url || '');
  const [instagramUrl, setInstagramUrl] = useState(profile?.instagram_url || '');
  const [threadsUrl, setThreadsUrl] = useState(profile?.threads_url || '');
  const [payoutInfo, setPayoutInfo] = useState<any>(null);
  const [showPayoutForm, setShowPayoutForm] = useState(false);
  const [savingPayout, setSavingPayout] = useState(false);
  const [payoutError, setPayoutError] = useState('');
  const [bankAccountName, setBankAccountName] = useState('');
  const [bankAccountNumber, setBankAccountNumber] = useState('');
  const [bankName, setBankName] = useState('');
  const [bankRoutingNumber, setBankRoutingNumber] = useState('');
  const [bankSwiftCode, setBankSwiftCode] = useState('');
  const [payoutCountry, setPayoutCountry] = useState('');
  const [payoutCurrency, setPayoutCurrency] = useState('USD');
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [deliveryStreet, setDeliveryStreet] = useState('');
  const [deliveryBuilding, setDeliveryBuilding] = useState('');
  const [deliveryApartment, setDeliveryApartment] = useState('');
  const [deliveryCity, setDeliveryCity] = useState('');
  const [deliveryState, setDeliveryState] = useState('');
  const [deliveryPostalCode, setDeliveryPostalCode] = useState('');
  const [deliveryCountry, setDeliveryCountry] = useState('');

  useEffect(() => {
    if (profile) {
      // Clear any previous errors when profile changes
      setPayoutError('');
      setMessage('');

      // Load social media and delivery address (shared between modes)
      setFacebookUrl(profile.facebook_url || '');
      setTwitterUrl(profile.twitter_url || '');
      setInstagramUrl(profile.instagram_url || '');
      setThreadsUrl(profile.threads_url || '');

      // Parse delivery address
      const addressLines = (profile.default_delivery_address || '').split('\n');
      setDeliveryStreet(addressLines[0] || '');
      setDeliveryBuilding(addressLines[1] || '');
      setDeliveryApartment(addressLines[2] || '');
      setDeliveryCity(addressLines[3] || '');
      setDeliveryState(addressLines[4] || '');
      setDeliveryPostalCode(addressLines[5] || '');
      setDeliveryCountry(addressLines[6] || '');

      if (profile.user_type === 'picker') {
        // Picker mode: Load billing info and picker-specific data
        // Parse billing address (same format as delivery address)
        const billingLines = (profile.billing_address || '').split('\n');
        console.log('Loading billing address:', { raw: profile.billing_address, lines: billingLines });
        setBillingStreet(billingLines[0] || '');
        setBillingBuilding(billingLines[1] || '');
        setBillingApartment(billingLines[2] || '');
        setBillingCity(billingLines[3] || '');
        setBillingState(billingLines[4] || '');
        setBillingPostalCode(billingLines[5] || '');
        setBillingCountry(billingLines[6] || '');
        setBillingPhone(profile.billing_phone || '');

        // Don't load identity from profiles - wait for picker_profiles
        setFullName('');
        setBio('');
        setAvatarUrl('');

        loadPickerProfile();
        loadPaymentMethods();
        loadPayoutInfo();
      } else {
        // Collector mode: Load identity from profiles table
        setFullName(profile.full_name || '');
        setBio(profile.bio || '');
        setAvatarUrl(profile.avatar_url || '');

        // Clear ALL picker-specific data when not in picker mode
        setPayoutInfo(null);
        setPickerProfile(null);
        setPaymentMethods([]);
        setPortfolioVideos([]);
        setCurrentLocation('');
        setRegions([]);
        setSpecialties([]);
        setLatitude(undefined);
        setLongitude(undefined);
        setBillingStreet('');
        setBillingBuilding('');
        setBillingApartment('');
        setBillingCity('');
        setBillingState('');
        setBillingPostalCode('');
        setBillingCountry('');
        setBillingPhone('');
      }
    }
  }, [profile]);

  // Debug: Log whenever payoutInfo changes
  useEffect(() => {
    console.log('🔄 PayoutInfo state changed:', payoutInfo);
  }, [payoutInfo]);

  // Check if profile is complete
  const isProfileComplete = () => {
    if (!profile) return false;

    const hasBasicInfo = fullName && bio && avatarUrl;

    if (profile.user_type === 'picker') {
      const hasPickerInfo = currentLocation && regions.length > 0 && specialties.length > 0;
      const hasPayoutInfo = payoutInfo && payoutInfo.bank_account_name && payoutInfo.bank_swift_code;
      return hasBasicInfo && hasPickerInfo && hasPayoutInfo;
    } else {
      // Collector - State is only required for US addresses
      const hasDeliveryAddress = deliveryStreet && deliveryCity && deliveryPostalCode && deliveryCountry &&
        (deliveryCountry !== 'United States' || deliveryState);
      return hasBasicInfo && hasDeliveryAddress;
    }
  };

  const loadPaymentMethods = async () => {
    try {
      const { data, error } = await supabase
        .from('picker_payment_cards')
        .select('*')
        .eq('picker_id', user?.id)
        .order('is_default', { ascending: false })
        .order('created_at', { ascending: false});

      if (error) throw error;
      setPaymentMethods(data || []);
    } catch (error) {

    }
  };

  const loadPayoutInfo = async () => {
    try {
      console.log('📥 Loading payout info for user:', user?.id);
      // Clear any previous error
      setPayoutError('');

      const { data, error } = await supabase
        .from('picker_payout_info')
        .select('*')
        .eq('picker_id', user?.id)
        .maybeSingle();

      if (error) {
        console.log('⚠️ Load error:', error);
        // Silently ignore these common non-critical errors:
        // - PGRST116: Row not found (user hasn't set up payout yet)
        // - Permission denied (can happen during profile transitions)
        // - Row-level security errors
        const ignorableErrors = [
          'PGRST116',
          'permission denied',
          'row-level security',
          'new row violates row-level security'
        ];

        const shouldIgnore = ignorableErrors.some(msg =>
          error.code === msg ||
          error.message?.toLowerCase().includes(msg.toLowerCase())
        );

        if (!shouldIgnore) {
          console.error('❌ Payout info error:', error);
          // Only show error for unexpected issues
          setPayoutError('Unable to load payout information. Please try again later.');
        } else {
          console.log('ℹ️ Ignorable error (user may not have payout info yet)');
        }
        return;
      }

      console.log('📦 Loaded payout data:', data);

      if (data) {
        console.log('✅ Setting payout info state with data:', data);
        setPayoutInfo(data);
        console.log('✅ PayoutInfo state should now be set');
        setBankAccountName(data.bank_account_name || '');
        setBankName(data.bank_name || '');
        setBankRoutingNumber(data.bank_routing_number || '');
        setBankSwiftCode(data.bank_swift_code || '');
        setPayoutCountry(data.country || '');
        setPayoutCurrency(data.currency || 'USD');
      } else {
        console.log('⚠️ No payout data returned from database');
        setPayoutInfo(null);
      }
    } catch (err: any) {
      // Catch-all: only log, never show to user
      console.error('❌ Failed to load payout info:', err);
    }
  };

  const loadPickerProfile = async () => {
    try {
      const { data, error } = await supabase
        .from('picker_profiles')
        .select('*')
        .eq('user_id', user?.id)
        .maybeSingle();

      if (error) throw error;
      if (data) {
        setPickerProfile(data);
        setCurrentLocation(data.current_location || '');
        setRegions(data.regions || []);
        setSpecialties(data.specialties || []);
        setLatitude(data.latitude || undefined);
        setLongitude(data.longitude || undefined);
        setPortfolioVideos(data.portfolio_videos || []);

        // Always use picker-specific identity fields (even if empty)
        setFullName(data.full_name || '');
        setBio(data.bio || '');
        setAvatarUrl(data.avatar_url || '');
      }
    } catch (error) {

    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0] || !user) return;

    setUploading(true);
    setMessage('');

    try {
      const file = e.target.files[0];
      const result = await uploadAvatar(file, user.id);
      setAvatarUrl(result.url);
      setMessage('Avatar uploaded successfully!');
    } catch (error: any) {
      setMessage('Error uploading avatar: ' + error.message);
    } finally {
      setUploading(false);
    }
  };

  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !user) return;

    setUploading(true);
    setMessage('');

    try {
      const files = Array.from(e.target.files);
      const uploadPromises = files.map(file => uploadVideo(file, user.id));
      const results = await Promise.all(uploadPromises);
      const urls = results.map(r => r.url);
      setPortfolioVideos([...portfolioVideos, ...urls]);
      setMessage('Videos uploaded successfully!');
    } catch (error: any) {
      setMessage('Error uploading videos: ' + error.message);
    } finally {
      setUploading(false);
    }
  };

  const removeVideo = (url: string) => {
    setPortfolioVideos(portfolioVideos.filter(vid => vid !== url));
  };

  const addVideoLink = () => {
    const trimmedLink = newVideoLink.trim();
    if (trimmedLink && !portfolioVideos.includes(trimmedLink)) {
      setPortfolioVideos([...portfolioVideos, trimmedLink]);
      setNewVideoLink('');
      setMessage('TikTok/Video link added!');
    }
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    console.log('State before save:', {
      billingStreet, billingBuilding, billingApartment,
      deliveryStreet, deliveryBuilding, deliveryApartment
    });

    try {
      if (profile?.user_type === 'picker') {
        // Picker mode: Save identity to picker_profiles, keep billing/social in profiles
        const billingAddressArray = [
          billingStreet,
          billingBuilding || '',
          billingApartment || '',
          billingCity,
          billingState || '',
          billingPostalCode,
          billingCountry
        ];
        console.log('Saving billing address:', { array: billingAddressArray, joined: billingAddressArray.join('\n') });

        const { error: profileError } = await supabase
          .from('profiles')
          .update({
            billing_address: billingAddressArray.join('\n') || null,
            billing_phone: billingPhone || null,
            default_delivery_address: [
              deliveryStreet,
              deliveryBuilding || '',
              deliveryApartment || '',
              deliveryCity,
              deliveryState || '',
              deliveryPostalCode,
              deliveryCountry
            ].join('\n') || null,
            facebook_url: facebookUrl || null,
            twitter_url: twitterUrl || null,
            instagram_url: instagramUrl || null,
            threads_url: threadsUrl || null,
          })
          .eq('id', user?.id);

        if (profileError) throw profileError;

        // Save picker-specific identity and location data
        const { error: pickerError } = await supabase
          .from('picker_profiles')
          .update({
            full_name: fullName,
            bio,
            avatar_url: avatarUrl || null,
            current_location: currentLocation,
            regions,
            specialties,
            latitude: latitude || null,
            longitude: longitude || null,
            location_updated_at: latitude && longitude ? new Date().toISOString() : null,
            portfolio_videos: portfolioVideos,
          })
          .eq('user_id', user?.id);

        if (pickerError) throw pickerError;
      } else {
        // Collector mode: Save identity to profiles
        const { error: profileError } = await supabase
          .from('profiles')
          .update({
            full_name: fullName,
            bio,
            avatar_url: avatarUrl || null,
            default_delivery_address: [
              deliveryStreet,
              deliveryBuilding || '',
              deliveryApartment || '',
              deliveryCity,
              deliveryState || '',
              deliveryPostalCode,
              deliveryCountry
            ].join('\n') || null,
            facebook_url: facebookUrl || null,
            twitter_url: twitterUrl || null,
            instagram_url: instagramUrl || null,
            threads_url: threadsUrl || null,
          })
          .eq('id', user?.id);

        if (profileError) throw profileError;
      }

      // Check if profile is now complete
      const profileComplete = isProfileComplete();

      if (profileComplete) {
        setMessage('Profile updated successfully! Your profile is now 100% complete.');
        // Scroll to top to show the completion banner
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } else {
        setMessage('Profile updated successfully!');
      }
    } catch (error: any) {
      setMessage('Error updating profile: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const addRegion = () => {
    if (newRegion.trim() && !regions.includes(newRegion.trim())) {
      setRegions([...regions, newRegion.trim()]);
      setNewRegion('');
    }
  };

  const removeRegion = (region: string) => {
    setRegions(regions.filter(r => r !== region));
  };

  const addSpecialty = () => {
    if (newSpecialty.trim() && !specialties.includes(newSpecialty.trim())) {
      setSpecialties([...specialties, newSpecialty.trim()]);
      setNewSpecialty('');
    }
  };

  const removeSpecialty = (specialty: string) => {
    setSpecialties(specialties.filter(s => s !== specialty));
  };

  const handleAddPaymentMethod = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const lastFour = cardNumber.slice(-4);
      const cardBrand = detectCardBrand(cardNumber);

      const { error } = await supabase.from('payment_methods').insert({
        picker_id: user?.id,
        method_type: paymentMethodType,
        last_four: lastFour,
        card_brand: cardBrand,
        cardholder_name: cardholderName,
        expiry_month: parseInt(expiryMonth),
        expiry_year: parseInt(expiryYear),
        is_default: paymentMethods.length === 0,
      });

      if (error) throw error;

      setCardNumber('');
      setCardholderName('');
      setExpiryMonth('');
      setExpiryYear('');
      setCvv('');
      setShowPaymentForm(false);
      loadPaymentMethods();
      setMessage('Payment method added successfully!');
    } catch (error: any) {
      setMessage('Error adding payment method: ' + error.message);
    }
  };

  const detectCardBrand = (cardNumber: string): string => {
    const digits = cardNumber.replace(/\s/g, '');
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('3')) return 'American Express';
    return 'Unknown';
  };

  const togglePaymentDefault = async (paymentId: string) => {
    try {
      await supabase
        .from('picker_payment_cards')
        .update({ is_default: false })
        .eq('picker_id', user?.id);

      const { error } = await supabase
        .from('picker_payment_cards')
        .update({ is_default: true })
        .eq('id', paymentId);

      if (error) throw error;
      loadPaymentMethods();
    } catch (error) {

    }
  };

  const deletePaymentMethod = async (paymentId: string) => {
    if (!confirm('Are you sure you want to delete this payment method?')) return;

    try {
      const { error } = await supabase
        .from('picker_payment_cards')
        .delete()
        .eq('id', paymentId);

      if (error) throw error;
      loadPaymentMethods();
      setMessage('Payment method deleted successfully!');
    } catch (error) {

    }
  };

  const validateIBAN = (iban: string): { valid: boolean; error?: string } => {
    // Remove spaces and convert to uppercase
    const cleanIBAN = iban.replace(/\s/g, '').toUpperCase();

    // Check if IBAN is empty
    if (!cleanIBAN) {
      return { valid: false, error: 'IBAN is required' };
    }

    // Check minimum length (15 characters)
    if (cleanIBAN.length < 15) {
      return { valid: false, error: 'IBAN is too short (minimum 15 characters)' };
    }

    // Check maximum length (34 characters)
    if (cleanIBAN.length > 34) {
      return { valid: false, error: 'IBAN is too long (maximum 34 characters)' };
    }

    // Check if it starts with 2 letters (country code)
    if (!/^[A-Z]{2}/.test(cleanIBAN)) {
      return { valid: false, error: 'IBAN must start with 2-letter country code (e.g., RO, DE, FR)' };
    }

    // Check if followed by 2 check digits
    if (!/^[A-Z]{2}[0-9]{2}/.test(cleanIBAN)) {
      return { valid: false, error: 'IBAN must have 2 check digits after country code' };
    }

    // Check if rest contains only letters and numbers
    if (!/^[A-Z]{2}[0-9]{2}[A-Z0-9]+$/.test(cleanIBAN)) {
      return { valid: false, error: 'IBAN can only contain letters and numbers' };
    }

    // Validate country-specific IBAN lengths - Complete list of all IBAN countries
    const ibanLengths: Record<string, number> = {
      // European Union & EEA
      'AT': 20, // Austria
      'BE': 16, // Belgium
      'BG': 22, // Bulgaria
      'HR': 21, // Croatia
      'CY': 28, // Cyprus
      'CZ': 24, // Czech Republic
      'DK': 18, // Denmark
      'EE': 20, // Estonia
      'FI': 18, // Finland
      'FR': 27, // France
      'DE': 22, // Germany
      'GR': 27, // Greece
      'HU': 28, // Hungary
      'IE': 22, // Ireland
      'IT': 27, // Italy
      'LV': 21, // Latvia
      'LT': 20, // Lithuania
      'LU': 20, // Luxembourg
      'MT': 31, // Malta
      'NL': 18, // Netherlands
      'PL': 28, // Poland
      'PT': 25, // Portugal
      'RO': 24, // Romania
      'SK': 24, // Slovakia
      'SI': 19, // Slovenia
      'ES': 24, // Spain
      'SE': 24, // Sweden
      'GB': 22, // United Kingdom
      'IS': 26, // Iceland
      'LI': 21, // Liechtenstein
      'NO': 15, // Norway
      'CH': 21, // Switzerland

      // Middle East
      'AE': 23, // United Arab Emirates
      'BH': 22, // Bahrain
      'IL': 23, // Israel
      'IQ': 23, // Iraq
      'JO': 30, // Jordan
      'KW': 30, // Kuwait
      'LB': 28, // Lebanon
      'OM': 23, // Oman
      'PS': 29, // Palestine
      'QA': 29, // Qatar
      'SA': 24, // Saudi Arabia
      'TR': 26, // Turkey
      'YE': 30, // Yemen

      // Africa
      'DZ': 26, // Algeria
      'AO': 25, // Angola
      'BJ': 28, // Benin
      'BF': 28, // Burkina Faso
      'BI': 16, // Burundi
      'CM': 27, // Cameroon
      'CV': 25, // Cape Verde
      'CG': 27, // Congo
      'CI': 28, // Ivory Coast
      'DJ': 27, // Djibouti
      'EG': 29, // Egypt
      'GA': 27, // Gabon
      'GW': 25, // Guinea-Bissau
      'IR': 26, // Iran
      'MA': 28, // Morocco
      'MG': 27, // Madagascar
      'ML': 28, // Mali
      'MZ': 25, // Mozambique
      'NE': 28, // Niger
      'SN': 28, // Senegal
      'TN': 24, // Tunisia

      // Latin America & Caribbean
      'BR': 29, // Brazil
      'CR': 22, // Costa Rica
      'GT': 28, // Guatemala
      'SV': 28, // El Salvador
      'VG': 24, // Virgin Islands, British

      // Central Asia & Caucasus
      'AZ': 28, // Azerbaijan
      'BY': 28, // Belarus
      'GE': 22, // Georgia
      'KZ': 20, // Kazakhstan
      'MD': 24, // Moldova
      'MR': 27, // Mauritania
      'MU': 30, // Mauritius
      'MK': 19, // North Macedonia
      'PK': 24, // Pakistan
      'RS': 22, // Serbia
      'SC': 31, // Seychelles
      'UA': 29, // Ukraine
      'VA': 22, // Vatican City
      'XK': 20, // Kosovo

      // Additional territories
      'AD': 24, // Andorra
      'AL': 28, // Albania
      'BA': 20, // Bosnia and Herzegovina
      'DO': 28, // Dominican Republic
      'FO': 18, // Faroe Islands
      'GI': 23, // Gibraltar
      'GL': 18, // Greenland
      'LC': 32, // Saint Lucia
      'MC': 27, // Monaco
      'ME': 22, // Montenegro
      'SM': 27, // San Marino
      'ST': 25, // Sao Tome and Principe
      'TL': 23, // East Timor
    };

    const countryCode = cleanIBAN.substring(0, 2);
    const expectedLength = ibanLengths[countryCode];

    if (expectedLength && cleanIBAN.length !== expectedLength) {
      const diff = expectedLength - cleanIBAN.length;
      return {
        valid: false,
        error: `${countryCode} IBAN must be exactly ${expectedLength} characters. You entered ${cleanIBAN.length}. ${diff > 0 ? `Missing ${diff}` : `Extra ${Math.abs(diff)}`} character(s).`
      };
    }

    // Perform mod-97 checksum validation
    try {
      // Move first 4 chars to end
      const rearranged = cleanIBAN.slice(4) + cleanIBAN.slice(0, 4);

      // Replace letters with numbers (A=10, B=11, ..., Z=35)
      const numeric = rearranged.split('').map(char => {
        const code = char.charCodeAt(0);
        if (code >= 65 && code <= 90) { // A-Z
          return (code - 55).toString();
        }
        return char;
      }).join('');

      // Calculate mod 97
      let remainder = numeric;
      while (remainder.length > 2) {
        const block = remainder.slice(0, 9);
        remainder = (parseInt(block, 10) % 97).toString() + remainder.slice(9);
      }

      const checksum = parseInt(remainder, 10) % 97;
      if (checksum !== 1) {
        return { valid: false, error: 'Invalid IBAN checksum. Please verify the account number is correct.' };
      }
    } catch (e) {
      return { valid: false, error: 'Unable to validate IBAN format' };
    }

    return { valid: true };
  };

  const formatIBAN = (value: string): string => {
    // Remove all spaces and convert to uppercase
    const clean = value.replace(/\s/g, '').toUpperCase();
    // Add space every 4 characters for readability
    return clean.match(/.{1,4}/g)?.join(' ') || clean;
  };

  // Auto-fill mappings
  const ibanCountryMap: Record<string, { country: string; currency: string }> = {
    'RO': { country: 'Romania', currency: 'RON' },
    'DE': { country: 'Germany', currency: 'EUR' },
    'FR': { country: 'France', currency: 'EUR' },
    'GB': { country: 'United Kingdom', currency: 'GBP' },
    'US': { country: 'United States', currency: 'USD' },
    'IT': { country: 'Italy', currency: 'EUR' },
    'ES': { country: 'Spain', currency: 'EUR' },
    'NL': { country: 'Netherlands', currency: 'EUR' },
    'BE': { country: 'Belgium', currency: 'EUR' },
    'AT': { country: 'Austria', currency: 'EUR' },
    'PL': { country: 'Poland', currency: 'PLN' },
    'SE': { country: 'Sweden', currency: 'SEK' },
    'DK': { country: 'Denmark', currency: 'DKK' },
    'FI': { country: 'Finland', currency: 'EUR' },
    'NO': { country: 'Norway', currency: 'NOK' },
    'CH': { country: 'Switzerland', currency: 'CHF' },
    'PT': { country: 'Portugal', currency: 'EUR' },
    'GR': { country: 'Greece', currency: 'EUR' },
    'IE': { country: 'Ireland', currency: 'EUR' },
    'CZ': { country: 'Czech Republic', currency: 'CZK' },
    'HU': { country: 'Hungary', currency: 'HUF' },
    'BG': { country: 'Bulgaria', currency: 'BGN' },
    'HR': { country: 'Croatia', currency: 'EUR' },
    'SK': { country: 'Slovakia', currency: 'EUR' },
    'SI': { country: 'Slovenia', currency: 'EUR' },
    'LT': { country: 'Lithuania', currency: 'EUR' },
    'LV': { country: 'Latvia', currency: 'EUR' },
    'EE': { country: 'Estonia', currency: 'EUR' },
    'CY': { country: 'Cyprus', currency: 'EUR' },
    'MT': { country: 'Malta', currency: 'EUR' },
    'LU': { country: 'Luxembourg', currency: 'EUR' },
  };

  const routingNumberBankMap: Record<string, string> = {
    '021': 'JPMorgan Chase',
    '026': 'Bank of America',
    '111': 'Wells Fargo',
    '121': 'Citibank',
    '031': 'Capital One',
    '063': 'US Bank',
    '044': 'PNC Bank',
    '091': 'TD Bank',
    '071': 'Fifth Third Bank',
    '124': 'Truist Bank',
  };

  const swiftBankMap: Record<string, { bank: string; country: string }> = {
    'HSBCGB2L': { bank: 'HSBC UK', country: 'United Kingdom' },
    'BARCGB22': { bank: 'Barclays', country: 'United Kingdom' },
    'DEUTDEFF': { bank: 'Deutsche Bank', country: 'Germany' },
    'BNPAFRPP': { bank: 'BNP Paribas', country: 'France' },
    'CHASGB2L': { bank: 'JPMorgan Chase', country: 'United Kingdom' },
    'CITIUS33': { bank: 'Citibank', country: 'United States' },
    'BOFAUS3N': { bank: 'Bank of America', country: 'United States' },
    'WFBIUS6S': { bank: 'Wells Fargo', country: 'United States' },
    'BTRLRO22': { bank: 'Banca Transilvania', country: 'Romania' },
    'RZBBROBU': { bank: 'Raiffeisen Bank', country: 'Romania' },
  };

  // IBAN Bank Code to SWIFT mapping (for auto-filling SWIFT from IBAN)
  const ibanBankCodeToSwift: Record<string, Record<string, string>> = {
    'RO': {
      'BTRL': 'BTRLRO22',
      'RZBR': 'RZBBROBU',
      'INGB': 'INGBROBU',
      'BRDE': 'BRDEROBU',
      'PIRB': 'PIRBROBU',
      'BACX': 'BACXROBU',
      'UGBI': 'UGBIROBU',
      'BREL': 'BRELROBU',
      'CECE': 'CECEROBU',
      'ROIN': 'ROINROBU',
      'BUCU': 'BUCUROBU',
      'BNRB': 'BNRBROBU',
    },
    'DE': {
      'DEUT': 'DEUTDEFF',
      'COBA': 'COBADEFF',
      'DRSD': 'DRSDEFF2',
      'WELADE': 'WELADED1',
      'BYLADEM': 'BYLADEM1',
      'SOLADEST': 'SOLADEST',
      'DEUTDEDB': 'DEUTDEDB',
    },
    'GB': {
      'HSBC': 'HSBCGB2L',
      'BARC': 'BARCGB22',
      'NWBK': 'NWBKGB2L',
      'MIDL': 'MIDLGB22',
      'LOYD': 'LOYDGB2L',
      'RBOS': 'RBOSGB2L',
      'HBUK': 'HBUKGB4B',
    },
    'FR': {
      'BNPA': 'BNPAFRPP',
      'CEPA': 'CEPAFRPP',
      'SOGEFRPP': 'SOGEFRPP',
      'CRLYFRPP': 'CRLYFRPP',
      'AGRIFRPP': 'AGRIFRPP',
    },
    'IT': {
      'BCIT': 'BCITITMM',
      'UNCRITMM': 'UNCRITMM',
      'BLOPIT22': 'BLOPIT22',
      'IBSPITR': 'IBSPITNA',
    },
    'ES': {
      'BBVA': 'BBVAESMM',
      'BSCH': 'BSCHESMM',
      'CAIX': 'CAIXESBB',
      'SABH': 'SABHESBM',
    },
    'NL': {
      'ABNA': 'ABNANL2A',
      'INGB': 'INGBNL2A',
      'RABO': 'RABONL2U',
      'TRIO': 'TRIONL2U',
    },
    'BE': {
      'GKCC': 'GKCCBEBB',
      'KREH': 'KREDBEBB',
      'BNAG': 'BPOTBEB1',
      'ARSP': 'ARSPBE22',
    },
    'AT': {
      'RZBAATWW': 'RZBAATWW',
      'BKAUATWW': 'BKAUATWW',
      'GIBAATWW': 'GIBAATWW',
    },
    'PL': {
      'PKOP': 'PKOPPLPW',
      'BPKO': 'BPKOPLPW',
      'BREX': 'BREXPLPW',
      'INGB': 'INGBPLPW',
    },
    'SE': {
      'HAND': 'HANDSESS',
      'NDEA': 'NDEASES1',
      'SWED': 'SWEDSESS',
      'SEB': 'ESSESESS',
    },
    'DK': {
      'DANSKE': 'DABADKKK',
      'NYKR': 'NYKBDKKK',
      'JYBA': 'JYBADKKK',
    },
    'NO': {
      'DNBA': 'DNBANOKK',
      'HAND': 'HANDNOKK',
      'SPNO': 'SPNONO22',
    },
    'CH': {
      'UBSW': 'UBSWCHZH',
      'CRESCHZZ': 'CRESCHZZ',
      'ZKBKCHZZ': 'ZKBKCHZZ',
    },
    'PT': {
      'CGDI': 'CGDIPTPL',
      'BSCH': 'BSCHPTPL',
      'BCOM': 'BCOMPTPL',
    },
  };

  // Bank code to bank name mapping (for displaying bank names)
  const bankCodeToBankName: Record<string, string> = {
    'BTRL': 'Banca Transilvania',
    'RZBR': 'Raiffeisen Bank',
    'INGB': 'ING Bank',
    'BRDE': 'BRD Groupe Societe Generale',
    'PIRB': 'Piraeus Bank',
    'BACX': 'UniCredit Bank',
    'UGBI': 'Garanti BBVA',
    'BREL': 'Libra Internet Bank',
    'CECE': 'CEC Bank',
    'ROIN': 'Alpha Bank',
    'BUCU': 'Bancpost',
    'BNRB': 'National Bank of Romania',
    'DEUT': 'Deutsche Bank',
    'COBA': 'Commerzbank',
    'DRSD': 'Dresdner Bank',
    'WELADE': 'Sparkasse',
    'BYLADEM': 'HypoVereinsbank',
    'SOLADEST': 'Landesbank Baden-Württemberg',
    'DEUTDEDB': 'Deutsche Bank Berlin',
    'HSBC': 'HSBC UK',
    'BARC': 'Barclays',
    'NWBK': 'NatWest',
    'MIDL': 'HSBC Bank',
    'LOYD': 'Lloyds Bank',
    'RBOS': 'Royal Bank of Scotland',
    'HBUK': 'Halifax',
    'BNPA': 'BNP Paribas',
    'CEPA': 'Caisse d\'Epargne',
    'SOGEFRPP': 'Societe Generale',
    'CRLYFRPP': 'Credit Lyonnais',
    'AGRIFRPP': 'Credit Agricole',
    'BCIT': 'Intesa Sanpaolo',
    'UNCRITMM': 'UniCredit',
    'BLOPIT22': 'BNL',
    'IBSPITR': 'Banco Popolare',
    'BBVA': 'BBVA',
    'BSCH': 'Santander',
    'CAIX': 'CaixaBank',
    'SABH': 'Banco Sabadell',
    'ABNA': 'ABN AMRO',
    'RABO': 'Rabobank',
    'TRIO': 'Triodos Bank',
    'GKCC': 'KBC Bank',
    'KREH': 'Belfius',
    'BNAG': 'BNP Paribas Fortis',
    'ARSP': 'Argenta',
    'RZBAATWW': 'Raiffeisen Bank Austria',
    'BKAUATWW': 'Bank Austria',
    'GIBAATWW': 'Erste Bank',
    'PKOP': 'PKO Bank Polski',
    'BPKO': 'Pekao SA',
    'BREX': 'mBank',
    'HAND': 'Handelsbanken',
    'NDEA': 'Nordea',
    'SWED': 'Swedbank',
    'SEB': 'SEB Bank',
    'DANSKE': 'Danske Bank',
    'NYKR': 'Nykredit',
    'JYBA': 'Jyske Bank',
    'DNBA': 'DNB Bank',
    'SPNO': 'SpareBank 1',
    'UBSW': 'UBS',
    'CRESCHZZ': 'Credit Suisse',
    'ZKBKCHZZ': 'Zurcher Kantonalbank',
    'CGDI': 'Caixa Geral de Depositos',
    'BCOM': 'Millennium BCP',
  };

  // Function to extract bank code from IBAN and look up SWIFT
  const getSwiftFromIBAN = (iban: string): string | null => {
    const cleanIBAN = iban.replace(/\s/g, '').toUpperCase();
    if (cleanIBAN.length < 8) return null;

    const countryCode = cleanIBAN.substring(0, 2);
    const bankCodeMap = ibanBankCodeToSwift[countryCode];
    if (!bankCodeMap) return null;

    // Bank code position varies by country
    // Most countries: characters 4-8 (after country code and check digits)
    const bankCode = cleanIBAN.substring(4, 8);

    // Try exact match first
    if (bankCodeMap[bankCode]) {
      return bankCodeMap[bankCode];
    }

    // Try partial matches (for codes like SOLADEST that are longer)
    for (const [code, swift] of Object.entries(bankCodeMap)) {
      if (bankCode.startsWith(code) || code.startsWith(bankCode)) {
        return swift;
      }
    }

    return null;
  };

  // Function to extract bank name from IBAN
  const getBankNameFromIBAN = (iban: string): string | null => {
    const cleanIBAN = iban.replace(/\s/g, '').toUpperCase();
    if (cleanIBAN.length < 8) return null;

    const countryCode = cleanIBAN.substring(0, 2);
    const bankCodeMap = ibanBankCodeToSwift[countryCode];
    if (!bankCodeMap) return null;

    // Extract bank code (characters 4-8)
    const bankCode = cleanIBAN.substring(4, 8);

    // Try exact match first
    if (bankCodeToBankName[bankCode]) {
      return bankCodeToBankName[bankCode];
    }

    // Try partial matches
    for (const [code, name] of Object.entries(bankCodeToBankName)) {
      if (bankCode.startsWith(code) || code.startsWith(bankCode)) {
        return name;
      }
    }

    return null;
  };

  const [autoFilledFields, setAutoFilledFields] = useState<Set<string>>(new Set());

  const handleIBANChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setBankAccountNumber(value);

    // Clear error when user starts typing
    if (payoutError && payoutError.includes('IBAN')) {
      setPayoutError('');
    }

    // Auto-fill country and currency from IBAN
    const cleanValue = value.replace(/\s/g, '').toUpperCase();
    if (cleanValue.length >= 2) {
      const countryCode = cleanValue.substring(0, 2);
      const mapping = ibanCountryMap[countryCode];
      if (mapping) {
        if (!payoutCountry || autoFilledFields.has('country')) {
          setPayoutCountry(mapping.country);
          setAutoFilledFields(prev => new Set(prev).add('country'));
        }
        if (!payoutCurrency || payoutCurrency === 'USD' || autoFilledFields.has('currency')) {
          setPayoutCurrency(mapping.currency);
          setAutoFilledFields(prev => new Set(prev).add('currency'));
        }
      }
    }

    // Auto-fill bank name and SWIFT code from IBAN bank code
    if (cleanValue.length >= 8) {
      const countryCode = cleanValue.substring(0, 2);
      const bankCode = cleanValue.substring(4, 8);
      console.log('🏦 Detecting bank from IBAN:', {
        iban: cleanValue.substring(0, 8) + '...',
        countryCode,
        bankCode,
        fullIBAN: cleanValue
      });

      // Auto-fill bank name directly from IBAN
      const bankNameFromIBAN = getBankNameFromIBAN(cleanValue);
      console.log('🏦 Bank name detection result:', bankNameFromIBAN || 'not found');

      if (bankNameFromIBAN) {
        console.log('✅ Setting bank name to:', bankNameFromIBAN);
        setBankName(bankNameFromIBAN);
        setAutoFilledFields(prev => new Set(prev).add('bankName'));
      }

      // Auto-fill SWIFT code
      const swift = getSwiftFromIBAN(cleanValue);
      console.log('🏦 SWIFT detection result:', swift || 'not found');

      if (swift) {
        console.log('✅ Setting SWIFT code to:', swift);
        setBankSwiftCode(swift);
        setAutoFilledFields(prev => new Set(prev).add('swiftCode'));

        // Also auto-fill bank name from SWIFT mapping if we don't have it from IBAN yet
        if (!bankNameFromIBAN) {
          const swiftMapping = swiftBankMap[swift];
          if (swiftMapping) {
            console.log('✅ Setting bank name from SWIFT mapping to:', swiftMapping.bank);
            setBankName(swiftMapping.bank);
            setAutoFilledFields(prev => new Set(prev).add('bankName'));
          }
        }
      }
    }
  };

  const handleRoutingNumberChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setBankRoutingNumber(value);

    // Auto-fill bank name from routing number
    if (value.length >= 3) {
      const prefix = value.substring(0, 3);
      const bankName = routingNumberBankMap[prefix];
      if (bankName && (!bankName || autoFilledFields.has('bankName'))) {
        setBankName(bankName);
        setAutoFilledFields(prev => new Set(prev).add('bankName'));
        setPayoutCountry('United States');
        setPayoutCurrency('USD');
        setAutoFilledFields(prev => new Set(prev).add('country').add('currency'));
      }
    }
  };

  const handleSwiftChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.toUpperCase();
    setBankSwiftCode(value);

    // Clear error when user starts typing
    if (payoutError && payoutError.includes('SWIFT')) {
      setPayoutError('');
    }

    // Auto-fill bank name and country from SWIFT code
    if (value.length >= 8) {
      const mapping = swiftBankMap[value.substring(0, 8)];
      if (mapping) {
        if (!bankName || autoFilledFields.has('bankName')) {
          setBankName(mapping.bank);
          setAutoFilledFields(prev => new Set(prev).add('bankName'));
        }
        if (!payoutCountry || autoFilledFields.has('country')) {
          setPayoutCountry(mapping.country);
          setAutoFilledFields(prev => new Set(prev).add('country'));
        }
        // Set currency based on country
        const currencyMap: Record<string, string> = {
          'United Kingdom': 'GBP',
          'Germany': 'EUR',
          'France': 'EUR',
          'United States': 'USD',
          'Romania': 'RON',
        };
        const currency = currencyMap[mapping.country];
        if (currency && (!payoutCurrency || payoutCurrency === 'USD' || autoFilledFields.has('currency'))) {
          setPayoutCurrency(currency);
          setAutoFilledFields(prev => new Set(prev).add('currency'));
        }
      }
    }
  };

  const validateBankAccountName = (name: string): { valid: boolean; error?: string } => {
    const trimmed = name.trim();
    if (!trimmed) {
      return { valid: false, error: 'Account holder name is required' };
    }
    if (trimmed.length < 2) {
      return { valid: false, error: 'Account holder name must be at least 2 characters' };
    }
    if (trimmed.length > 100) {
      return { valid: false, error: 'Account holder name is too long (maximum 100 characters)' };
    }
    // Allow letters, spaces, hyphens, apostrophes
    if (!/^[a-zA-Z\s\-'\.]+$/.test(trimmed)) {
      return { valid: false, error: 'Account holder name can only contain letters, spaces, hyphens, and apostrophes' };
    }
    return { valid: true };
  };

  const validateBankName = (name: string): { valid: boolean; error?: string } => {
    const trimmed = name.trim();
    if (!trimmed) {
      return { valid: false, error: 'Bank name is required' };
    }
    if (trimmed.length < 2) {
      return { valid: false, error: 'Bank name must be at least 2 characters' };
    }
    if (trimmed.length > 100) {
      return { valid: false, error: 'Bank name is too long (maximum 100 characters)' };
    }
    return { valid: true };
  };

  const validateCountry = (country: string): { valid: boolean; error?: string } => {
    const trimmed = country.trim();
    if (!trimmed) {
      return { valid: false, error: 'Country is required' };
    }
    if (trimmed.length < 2) {
      return { valid: false, error: 'Country name must be at least 2 characters' };
    }
    // Allow letters, spaces, hyphens
    if (!/^[a-zA-Z\s\-]+$/.test(trimmed)) {
      return { valid: false, error: 'Country name can only contain letters, spaces, and hyphens' };
    }
    return { valid: true };
  };

  const handleSavePayoutInfo = async (e?: React.FormEvent) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    console.log('🚀 Starting payout save process...');

    // Check if user is logged in FIRST
    if (!user?.id) {
      console.error('❌ No user ID found');
      setPayoutError('You must be logged in. Please refresh and try again.');
      return;
    }

    console.log('✅ User ID:', user.id);

    // Validate account holder name
    const nameValidation = validateBankAccountName(bankAccountName);
    if (!nameValidation.valid) {
      console.error('❌ Name validation failed:', nameValidation.error);
      setPayoutError(nameValidation.error || 'Invalid account holder name');
      return;
    }

    // Validate bank name
    const bankNameValidation = validateBankName(bankName);
    if (!bankNameValidation.valid) {
      console.error('❌ Bank name validation failed:', bankNameValidation.error);
      setPayoutError(bankNameValidation.error || 'Invalid bank name');
      return;
    }

    // Validate IBAN format
    const ibanValidation = validateIBAN(bankAccountNumber);
    if (!ibanValidation.valid) {
      console.error('❌ IBAN validation failed:', ibanValidation.error);
      setPayoutError(ibanValidation.error || 'Invalid IBAN format');
      return;
    }

    // Validate country
    const countryValidation = validateCountry(payoutCountry);
    if (!countryValidation.valid) {
      console.error('❌ Country validation failed:', countryValidation.error);
      setPayoutError(countryValidation.error || 'Invalid country');
      return;
    }

    // Validate currency is selected
    if (!payoutCurrency || payoutCurrency.trim() === '') {
      console.error('❌ Currency not selected');
      setPayoutError('Currency is required. Please select a currency.');
      return;
    }

    // Validate SWIFT code is required and properly formatted
    if (!bankSwiftCode || bankSwiftCode.trim() === '') {
      console.error('❌ SWIFT code missing');
      setPayoutError('SWIFT/BIC code is required for international transfers');
      return;
    }

    if (!/^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$/.test(bankSwiftCode.toUpperCase())) {
      console.error('❌ SWIFT code format invalid');
      setPayoutError('Invalid SWIFT/BIC code format. Should be 8 or 11 characters (e.g., BTRLRO22 or BTRLRO22XXX)');
      return;
    }

    console.log('✅ All validations passed');

    // Store IBAN without spaces and uppercase for display in confirmation
    const cleanIBAN = bankAccountNumber.replace(/\s/g, '').toUpperCase();
    const last4 = cleanIBAN.slice(-4);

    try {
      setSavingPayout(true);
      setPayoutError('');

      console.log('💾 Saving to database...');
      console.log('📝 Data:', {
        picker_id: user.id,
        account_holder: bankAccountName.trim(),
        bank: bankName.trim(),
        iban_last4: last4,
        swift: bankSwiftCode.toUpperCase().trim(),
        country: payoutCountry.trim(),
        currency: payoutCurrency.trim()
      });

      // First, check if a record already exists
      const { data: existingRecord, error: checkError } = await supabase
        .from('picker_payout_info')
        .select('id')
        .eq('picker_id', user.id)
        .maybeSingle();

      if (checkError) {
        console.error('❌ Error checking existing record:', checkError);
        throw checkError;
      }

      console.log('📋 Existing record:', existingRecord ? 'Found' : 'Not found');

      let result;
      if (existingRecord) {
        // Update existing record
        console.log('🔄 Updating existing record...');
        result = await supabase
          .from('picker_payout_info')
          .update({
            bank_account_name: bankAccountName.trim(),
            bank_account_number: cleanIBAN,
            bank_account_last4: last4,
            bank_name: bankName.trim(),
            bank_routing_number: bankRoutingNumber?.trim() || null,
            bank_swift_code: bankSwiftCode.toUpperCase().trim(),
            country: payoutCountry.trim(),
            currency: payoutCurrency.trim(),
            is_verified: false,
            account_status: 'pending',
            payouts_enabled: false,
            updated_at: new Date().toISOString()
          })
          .eq('id', existingRecord.id)
          .select()
          .single();
      } else {
        // Insert new record
        console.log('➕ Creating new record...');
        result = await supabase
          .from('picker_payout_info')
          .insert({
            picker_id: user.id,
            stripe_account_id: null,
            bank_account_name: bankAccountName.trim(),
            bank_account_number: cleanIBAN,
            bank_account_last4: last4,
            bank_name: bankName.trim(),
            bank_routing_number: bankRoutingNumber?.trim() || null,
            bank_swift_code: bankSwiftCode.toUpperCase().trim(),
            country: payoutCountry.trim(),
            currency: payoutCurrency.trim(),
            is_verified: false,
            account_status: 'pending',
            payouts_enabled: false
          })
          .select()
          .single();
      }

      if (result.error) {
        console.error('❌ Database error:', result.error);
        throw result.error;
      }

      console.log('✅ Saved successfully!', result.data);

      // Small delay to ensure database transaction is fully committed
      await new Promise(resolve => setTimeout(resolve, 500));

      // Reload payout info
      await loadPayoutInfo();

      // Close form
      setShowPayoutForm(false);

      // Show success message
      setMessage(
        `Bank account saved successfully!\n\n` +
        `Bank: ${bankName.trim()}\n` +
        `Account: ****${last4}\n` +
        `SWIFT: ${bankSwiftCode.toUpperCase().trim()}\n` +
        `Currency: ${payoutCurrency.trim()}`
      );

      // Clear form
      setBankAccountNumber('');
      setBankAccountName('');
      setBankName('');
      setBankRoutingNumber('');
      setBankSwiftCode('');
      setPayoutCountry('');
      setPayoutCurrency('USD');

      console.log('✅ Process completed successfully');
    } catch (err: any) {
      console.error('❌ Save failed:', err);

      // Provide more specific error messages
      let errorMessage = 'Failed to save bank account information. Please try again.';

      if (err.message) {
        // Check for common constraint violations
        if (err.message.includes('bank_swift_code_format')) {
          errorMessage = 'Invalid SWIFT/BIC code format. Must be 8-11 uppercase characters (e.g., BTRLRO22XXX)';
        } else if (err.message.includes('bank_swift_code_not_empty')) {
          errorMessage = 'SWIFT/BIC code must be between 8-11 characters';
        } else if (err.message.includes('bank_account_number_not_empty')) {
          errorMessage = 'IBAN/Account number must be at least 15 characters';
        } else if (err.message.includes('currency_not_empty')) {
          errorMessage = 'Currency code must be exactly 3 characters (e.g., USD, EUR, GBP)';
        } else if (err.message.includes('country_not_empty')) {
          errorMessage = 'Country name must be at least 2 characters';
        } else if (err.message.includes('bank_name_not_empty')) {
          errorMessage = 'Bank name must be at least 2 characters';
        } else if (err.message.includes('bank_account_name_not_empty')) {
          errorMessage = 'Account holder name must be at least 2 characters';
        } else {
          errorMessage = err.message;
        }
      }

      console.error('❌ Error message shown to user:', errorMessage);
      setPayoutError(errorMessage);
    } finally {
      setSavingPayout(false);
    }
  };

  const handleSwitchUserType = async (newType: 'picker' | 'client') => {
    if (!user || profile?.user_type === newType) return;

    const confirmed = window.confirm(
      `Are you sure you want to switch to ${newType === 'picker' ? 'Picker' : 'Collector'} mode? This will change your dashboard and available features.`
    );

    if (!confirmed) return;

    try {
      setLoading(true);

      const { error: updateError } = await supabase
        .from('profiles')
        .update({ user_type: newType })
        .eq('id', user.id);

      if (updateError) throw updateError;

      if (newType === 'picker') {
        const { data: existingPicker } = await supabase
          .from('picker_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

        if (!existingPicker) {
          const { error: pickerError } = await supabase
            .from('picker_profiles')
            .insert({ user_id: user.id });

          if (pickerError) throw pickerError;
        }
      }

      setMessage(`Successfully switched to ${newType === 'picker' ? 'Picker' : 'Collector'} mode!`);

      setTimeout(() => {
        window.location.reload();
      }, 1000);
    } catch (error: any) {
      setMessage('Error switching user type: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-gradient-to-br from-blue-50 to-green-50 rounded-2xl shadow-xl p-6 sm:p-8 mb-6">
        <div className="flex items-center gap-4 mb-2">
          <div className="bg-blue-600 rounded-2xl p-3 shadow-lg">
            <User className="w-8 h-8 text-white" />
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="text-3xl sm:text-4xl font-bold text-gray-900">
                {isProfileComplete() ? 'Profile Complete' : 'Edit Complete Profile'}
              </h1>
              {isProfileComplete() && (
                <div className="inline-flex items-center gap-2 bg-green-50 text-green-700 px-3 py-1.5 rounded-full border-2 border-green-300 shadow-sm">
                  <CheckCircle className="w-5 h-5 fill-green-500 text-white" />
                  <span className="text-sm font-bold">100% Complete</span>
                </div>
              )}
            </div>
            <p className="text-sm text-gray-600 mt-1">
              {isProfileComplete()
                ? 'Your profile is fully set up. You can still update your information anytime.'
                : 'Complete all required fields to unlock full platform access'}
            </p>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-lg p-6 sm:p-8">

        {isProfileComplete() && (
          <div className="mb-8 p-6 bg-gradient-to-br from-green-50 via-blue-50 to-green-50 rounded-2xl border-2 border-green-300 shadow-lg">
            <div className="flex items-start gap-4">
              <div className="bg-green-500 rounded-full p-3 shadow-md">
                <Award className="w-8 h-8 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  Your Profile is Complete!
                </h3>
                <p className="text-gray-700 mb-4">
                  {profile?.user_type === 'picker'
                    ? 'You\'re all set to start earning! Your profile is fully set up with all required information. Collectors can now find you and place orders.'
                    : 'You\'re ready to start shopping! Your profile is complete with all necessary delivery information. Browse souvenirs and place your first order.'}
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="flex items-center gap-2 text-sm text-green-700">
                    <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                    <span>Profile information complete</span>
                  </div>
                  {profile?.user_type === 'picker' ? (
                    <>
                      <div className="flex items-center gap-2 text-sm text-green-700">
                        <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                        <span>Location & regions set</span>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-green-700">
                        <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                        <span>Payout information verified</span>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-green-700">
                        <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                        <span>Ready to receive orders</span>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="flex items-center gap-2 text-sm text-green-700">
                        <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                        <span>Delivery address saved</span>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-green-700">
                        <CheckCircle className="w-4 h-4 fill-green-500 text-white" />
                        <span>Ready to place orders</span>
                      </div>
                    </>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="mb-8 p-6 bg-gradient-to-r from-blue-50 to-green-50 rounded-xl border-2 border-blue-200">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-2">
                <RefreshCw className="w-5 h-5 text-blue-600" />
                <h3 className="text-lg font-bold text-gray-900">Account Type</h3>
              </div>
              <p className="text-sm text-gray-600 mb-4">
                Switch between Collector and Picker modes. You can be both!
              </p>
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  onClick={() => handleSwitchUserType('client')}
                  disabled={profile?.user_type === 'client' || loading}
                  className={`px-6 py-3 rounded-lg font-semibold transition-all duration-300 ${
                    profile?.user_type === 'client'
                      ? 'bg-blue-600 text-white shadow-lg cursor-default'
                      : 'bg-white text-blue-600 border-2 border-blue-600 hover:bg-blue-50 hover:shadow-md'
                  } disabled:opacity-50`}
                >
                  {profile?.user_type === 'client' && '✓ '}
                  Collector Mode
                </button>
                <button
                  type="button"
                  onClick={() => handleSwitchUserType('picker')}
                  disabled={profile?.user_type === 'picker' || loading}
                  className={`px-6 py-3 rounded-lg font-semibold transition-all duration-300 ${
                    profile?.user_type === 'picker'
                      ? 'bg-green-600 text-white shadow-lg cursor-default'
                      : 'bg-white text-green-600 border-2 border-green-600 hover:bg-green-50 hover:shadow-md'
                  } disabled:opacity-50`}
                >
                  {profile?.user_type === 'picker' && '✓ '}
                  Picker Mode
                </button>
              </div>
            </div>
            <div className="hidden md:block">
              <div className={`w-20 h-20 rounded-2xl flex items-center justify-center shadow-lg ${
                profile?.user_type === 'picker' ? 'bg-green-600' : 'bg-blue-600'
              }`}>
                {profile?.user_type === 'picker' ? (
                  <Package className="w-10 h-10 text-white" />
                ) : (
                  <ShoppingBag className="w-10 h-10 text-white" />
                )}
              </div>
            </div>
          </div>
          <div className="mt-4 p-4 bg-white rounded-lg border border-blue-200">
            <p className="text-sm text-gray-700">
              <span className="font-semibold">Current Mode:</span>{' '}
              {profile?.user_type === 'picker' ? (
                <span className="text-green-600 font-bold">Picker - You can create listings and earn money</span>
              ) : (
                <span className="text-blue-600 font-bold">Collector - You can browse and order souvenirs</span>
              )}
            </p>
          </div>
        </div>

        <div className="mb-6 p-4 bg-blue-50 border-l-4 border-blue-500 rounded-r-lg">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="text-sm font-medium text-blue-900 mb-1">
                Required vs Optional Fields
              </p>
              <p className="text-sm text-blue-800">
                Fields marked with <span className="text-red-600 font-bold">*</span> are required to complete your profile.
                Optional fields help enhance your profile but are not mandatory.
              </p>
            </div>
          </div>
        </div>

        <form onSubmit={handleSave} className="space-y-8">
          <div className="border-b pb-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <User className="w-5 h-5" />
              Basic Information
            </h2>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Profile Picture <span className="text-red-600">*</span>
            </label>
            <p className="text-xs text-gray-600 mb-3">Required to complete your profile</p>
            <div className="flex items-center gap-6">
              <div className="w-24 h-24 rounded-full bg-gray-200 flex items-center justify-center overflow-hidden">
                {avatarUrl ? (
                  <img src={avatarUrl} alt="Avatar" className="w-full h-full object-cover" />
                ) : (
                  <User className="w-12 h-12 text-gray-400" />
                )}
              </div>
              <div>
                <input
                  type="file"
                  accept="image/jpeg,image/jpg,image/png,image/webp"
                  onChange={handleAvatarUpload}
                  className="hidden"
                  id="avatar-upload"
                  disabled={uploading}
                />
                <label
                  htmlFor="avatar-upload"
                  className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors cursor-pointer disabled:opacity-50"
                >
                  <Upload className="w-4 h-4" />
                  {uploading ? 'Uploading...' : 'Upload Photo'}
                </label>
                <p className="text-xs text-gray-500 mt-2">JPG, PNG or WebP. Max 5MB.</p>
              </div>
            </div>
          </div>

          <div className="mt-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Full Name <span className="text-red-600">*</span>
            </label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              autoComplete="off"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Bio <span className="text-red-600">*</span>
            </label>
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              rows={4}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Tell others about yourself..."
              autoComplete="off"
              required
            />
            <p className="text-xs text-gray-500 mt-1">Required to complete your profile</p>
          </div>

          <div className="border-t pt-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
              <ExternalLink className="w-5 h-5" />
              Social Media Links (optional)
            </h2>
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <Facebook className="w-5 h-5 text-blue-600" />
                <input
                  type="text"
                  value={facebookUrl}
                  onChange={(e) => setFacebookUrl(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="https://facebook.com/yourprofile"
                  autoComplete="off"
                />
              </div>
              <div className="flex items-center gap-2">
                <Twitter className="w-5 h-5 text-blue-400" />
                <input
                  type="text"
                  value={twitterUrl}
                  onChange={(e) => setTwitterUrl(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="https://twitter.com/yourhandle"
                  autoComplete="off"
                />
              </div>
              <div className="flex items-center gap-2">
                <Instagram className="w-5 h-5 text-pink-600" />
                <input
                  type="text"
                  value={instagramUrl}
                  onChange={(e) => setInstagramUrl(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="https://instagram.com/yourhandle"
                  autoComplete="off"
                />
              </div>
              <div className="flex items-center gap-2">
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12.186 24h-.007c-3.581-.024-6.334-1.205-8.184-3.509C2.35 18.44 1.5 15.586 1.472 12.01v-.017c.03-3.579.879-6.43 2.525-8.482C5.845 1.205 8.6.024 12.18 0h.014c2.746.02 5.043.725 6.826 2.098 1.677 1.29 2.858 3.13 3.509 5.467l-2.04.569c-.542-1.937-1.488-3.427-2.812-4.424-1.452-1.094-3.387-1.67-5.746-1.708-3.05.022-5.317.977-6.73 2.838-1.33 1.749-2.052 4.14-2.084 6.912v.017c.032 2.766.755 5.156 2.084 6.91 1.413 1.862 3.68 2.816 6.73 2.838 2.36-.038 4.295-.613 5.746-1.707 1.324-.998 2.27-2.488 2.812-4.424l2.04.569c-.651 2.337-1.832 4.177-3.509 5.467-1.783 1.373-4.08 2.078-6.826 2.098z"/>
                </svg>
                <input
                  type="text"
                  value={threadsUrl}
                  onChange={(e) => setThreadsUrl(e.target.value)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="https://threads.net/@yourhandle"
                  autoComplete="off"
                />
              </div>
            </div>
          </div>

          {profile?.user_type === 'picker' && (
            <>
              <div className="border-t pt-6">
                <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <MapPin className="w-5 h-5" />
                  Location & Expertise
                </h2>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Current Location <span className="text-red-600">*</span>
                </label>
                <input
                  type="text"
                  value={currentLocation}
                  onChange={(e) => setCurrentLocation(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="e.g., Tokyo, Japan"
                  autoComplete="off"
                  required
                />
                <p className="text-xs text-gray-500 mt-1">Required for pickers to receive orders</p>
              </div>

              <LocationPicker
                latitude={latitude}
                longitude={longitude}
                onLocationChange={(lat, lng) => {
                  setLatitude(lat);
                  setLongitude(lng);
                }}
                label="Your Current GPS Location"
              />

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Regions You Can Access <span className="text-red-600">*</span>
                </label>
                <p className="text-sm text-gray-600 mb-3">
                  Add countries, cities, or regions where you can source souvenirs (required - add at least one)
                </p>
                <div className="flex gap-2 mb-3">
                  <input
                    type="text"
                    value={newRegion}
                    onChange={(e) => setNewRegion(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addRegion())}
                    className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Tokyo, Japan or Southeast Asia"
                    autoComplete="off"
                  />
                  <button
                    type="button"
                    onClick={addRegion}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    <Plus className="w-5 h-5" />
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {regions.map((region) => (
                    <span
                      key={region}
                      className="inline-flex items-center gap-1 bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-sm"
                    >
                      {region}
                      <button
                        type="button"
                        onClick={() => removeRegion(region)}
                        className="hover:text-blue-900"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <Tag className="w-4 h-4 inline mr-1" />
                  Specialties <span className="text-red-600">*</span>
                </label>
                <p className="text-sm text-gray-600 mb-3">
                  Add your expertise areas (required - add at least one)
                </p>
                <div className="flex gap-2 mb-3">
                  <input
                    type="text"
                    value={newSpecialty}
                    onChange={(e) => setNewSpecialty(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addSpecialty())}
                    className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Traditional crafts, Local snacks"
                    autoComplete="off"
                  />
                  <button
                    type="button"
                    onClick={addSpecialty}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    <Plus className="w-5 h-5" />
                  </button>
                </div>
                <div className="flex flex-wrap gap-2">
                  {specialties.map((specialty) => (
                    <span
                      key={specialty}
                      className="inline-flex items-center gap-1 bg-orange-100 text-orange-700 px-3 py-1 rounded-full text-sm"
                    >
                      {specialty}
                      <button
                        type="button"
                        onClick={() => removeSpecialty(specialty)}
                        className="hover:text-orange-900"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </span>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  <Video className="w-4 h-4 inline mr-1" />
                  Portfolio Videos
                </label>
                <p className="text-sm text-gray-600 mb-3">
                  Showcase your work by adding TikTok links or uploading videos
                </p>

                <div className="mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Add TikTok or Video Link (optional)
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={newVideoLink}
                      onChange={(e) => setNewVideoLink(e.target.value)}
                      placeholder="https://www.tiktok.com/@username/video/..."
                      className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      autoComplete="off"
                    />
                    <button
                      type="button"
                      onClick={addVideoLink}
                      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    >
                      <Plus className="w-5 h-5" />
                    </button>
                  </div>
                </div>

                <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 hover:border-blue-500 transition-colors">
                  <input
                    type="file"
                    accept="video/mp4,video/webm,video/quicktime"
                    multiple
                    onChange={handleVideoUpload}
                    className="hidden"
                    id="video-upload"
                    disabled={uploading}
                  />
                  <label
                    htmlFor="video-upload"
                    className="flex flex-col items-center justify-center cursor-pointer"
                  >
                    <Upload className="w-8 h-8 text-gray-400 mb-2" />
                    <span className="text-sm text-gray-600">
                      {uploading ? 'Uploading...' : 'Or upload videos (MP4, WebM)'}
                    </span>
                    <span className="text-xs text-gray-500 mt-1">Max 50MB • Use MP4 with H.264 codec for best compatibility</span>
                  </label>
                </div>

                {portfolioVideos.length > 0 && (
                  <div className="grid grid-cols-2 gap-3 mt-3">
                    {portfolioVideos.map((url, index) => (
                      <div key={index} className="relative group">
                        <video
                          src={url}
                          className="w-full h-32 object-cover rounded-lg bg-gray-100"
                          controls
                          preload="metadata"
                          playsInline
                          onLoadedMetadata={(e) => {
                            console.log('Video loaded successfully:', url);
                          }}
                          onError={(e) => {
                            console.error('Video load error:', e);
                            console.log('Failed video URL:', url);
                            const target = e.target as HTMLVideoElement;
                            target.poster = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="100" height="100"%3E%3Ctext x="50%25" y="50%25" text-anchor="middle" dy=".3em" fill="%23999"%3EVideo unavailable%3C/text%3E%3C/svg%3E';
                          }}
                        />
                        <button
                          type="button"
                          onClick={() => removeVideo(url)}
                          className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {pickerProfile && (
                <div className="bg-gray-50 p-4 rounded-lg">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-gray-600">Rating</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {pickerProfile.rating.toFixed(1)} ⭐
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600">Reviews</p>
                      <p className="text-2xl font-bold text-gray-900">
                        {pickerProfile.total_reviews}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600">Status</p>
                      <p className="text-sm font-medium">
                        {pickerProfile.verified ? (
                          <span className="text-green-600">✓ Verified</span>
                        ) : (
                          <span className="text-gray-500">Not Verified</span>
                        )}
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}

          {profile?.user_type === 'picker' && (
            <div className="border-t pt-6">
              <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2 mb-4">
                <User className="w-5 h-5" />
                Personal Billing Information
              </h3>
              <p className="text-sm text-gray-600 mb-4">
                This information will be used for your SouvenirPickers subscription billing after your free trial ends (€10/month)
              </p>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Street Address <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="text"
                    value={billingStreet}
                    onChange={(e) => setBillingStreet(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    autoComplete="off"
                    required
                  />
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Building Number <span className="text-gray-500">(optional)</span>
                    </label>
                    <input
                      type="text"
                      value={billingBuilding}
                      onChange={(e) => {
                        console.log('Building changed to:', e.target.value);
                        setBillingBuilding(e.target.value);
                      }}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      autoComplete="off"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Apartment/Unit <span className="text-gray-500">(optional)</span>
                    </label>
                    <input
                      type="text"
                      value={billingApartment}
                      onChange={(e) => {
                        console.log('Apartment changed to:', e.target.value);
                        setBillingApartment(e.target.value);
                      }}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      autoComplete="off"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Country <span className="text-red-600">*</span>
                  </label>
                  <select
                    value={billingCountry}
                    onChange={(e) => {
                      setBillingCountry(e.target.value);
                      if (e.target.value !== 'United States') {
                        setBillingState('');
                      }
                    }}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    autoComplete="off"
                    required
                  >
                    <option value="">Select a country</option>
                    {COUNTRIES.map(country => (
                      <option key={country} value={country}>{country}</option>
                    ))}
                  </select>
                </div>

                {billingCountry === 'United States' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      State <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      value={billingState}
                      onChange={(e) => setBillingState(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      placeholder="California"
                      autoComplete="off"
                      required
                    />
                  </div>
                )}

                <div className="grid md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      City <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      value={billingCity}
                      onChange={(e) => setBillingCity(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      autoComplete="off"
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Postal/ZIP Code <span className="text-red-600">*</span>
                    </label>
                    <input
                      type="text"
                      value={billingPostalCode}
                      onChange={(e) => setBillingPostalCode(e.target.value)}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      autoComplete="off"
                      required
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Phone Number <span className="text-red-600">*</span>
                  </label>
                  <input
                    type="tel"
                    value={billingPhone}
                    onChange={(e) => setBillingPhone(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., +40 123 456 789"
                    autoComplete="off"
                  />
                </div>
              </div>

              <div className="border-t mt-6 pt-6">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
                    <CreditCard className="w-5 h-5" />
                    Payment Methods
                  </h3>
                  <button
                    type="button"
                    onClick={() => setShowPaymentForm(!showPaymentForm)}
                    className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2 text-sm"
                  >
                    <Plus className="w-4 h-4" />
                    Add Payment Method
                  </button>
                </div>
                <p className="text-sm text-gray-600 mb-4">
                  Securely save your payment information for subscription billing
                </p>

                {message && (
                  <div className={`mb-4 p-4 rounded-xl border-2 font-medium ${
                    message.includes('Error') ? 'bg-red-50 text-red-600 border-red-300' : 'bg-green-50 text-green-600 border-green-300'
                  }`}>
                    <div className="flex items-start gap-3">
                      {message.includes('Error') ? (
                        <AlertCircle className="h-5 w-5 flex-shrink-0 mt-0.5" />
                      ) : (
                        <CheckCircle className="h-5 w-5 flex-shrink-0 mt-0.5" />
                      )}
                      <pre className="whitespace-pre-wrap font-sans flex-1">{message}</pre>
                    </div>
                  </div>
                )}

                {paymentMethods.length === 0 ? (
                  <div className="text-center py-8 text-gray-500 bg-gray-50 rounded-lg">
                    <CreditCard className="w-12 h-12 mx-auto mb-2 text-gray-300" />
                    <p>No payment methods added yet</p>
                  </div>
                ) : (
                  <div className="space-y-3">
                    {paymentMethods.map((method) => (
                      <div
                        key={method.id}
                        className="border rounded-lg p-4 hover:shadow-md transition-shadow"
                      >
                        <div className="flex items-start justify-between">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-2">
                              <CreditCard className="w-5 h-5 text-gray-600" />
                              <div>
                                <div className="flex items-center gap-2">
                                  <span className="font-semibold text-gray-900">
                                    {method.card_brand} •••• {method.card_last4}
                                  </span>
                                  {method.is_default && (
                                    <span className="bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full text-xs">
                                      Default
                                    </span>
                                  )}
                                </div>
                                <p className="text-sm text-gray-600">{method.cardholder_name}</p>
                              </div>
                            </div>
                            <p className="text-xs text-gray-600">
                              Expires: {method.card_exp_month}/{method.card_exp_year}
                            </p>
                          </div>
                          <div className="flex gap-2 ml-4">
                            {!method.is_default && (
                              <button
                                type="button"
                                onClick={() => togglePaymentDefault(method.id)}
                                className="px-3 py-1 bg-blue-50 text-blue-600 rounded text-xs font-medium hover:bg-blue-100 transition-colors"
                              >
                                Set Default
                              </button>
                            )}
                            <button
                              type="button"
                              onClick={() => deletePaymentMethod(method.id)}
                              className="px-3 py-1 bg-red-50 text-red-600 rounded text-xs font-medium hover:bg-red-100 transition-colors"
                            >
                              Delete
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {profile?.user_type === 'client' && (
            <>
              <div className="border-t pt-6">
                <h3 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <MapPin className="w-6 h-6 text-blue-600" />
                  Default Delivery Address <span className="text-red-600">*</span>
                </h3>
                <p className="text-sm text-gray-600 mb-4">
                  Save your default shipping address to make checkout faster. This will be pre-filled when you proceed to checkout. <span className="font-semibold text-red-600">Required to complete your profile.</span>
                </p>

                <div className="bg-gray-50 rounded-lg p-6 border-2 border-gray-200">
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Street Address <span className="text-red-600">*</span>
                      </label>
                      <input
                        type="text"
                        value={deliveryStreet}
                        onChange={(e) => setDeliveryStreet(e.target.value)}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        autoComplete="off"
                        required
                      />
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2">
                          Building Number <span className="text-gray-500">(optional)</span>
                        </label>
                        <input
                          type="text"
                          value={deliveryBuilding}
                          onChange={(e) => {
                            console.log('Delivery Building changed to:', e.target.value);
                            setDeliveryBuilding(e.target.value);
                          }}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          autoComplete="off"
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2">
                          Apartment/Unit <span className="text-gray-500">(optional)</span>
                        </label>
                        <input
                          type="text"
                          value={deliveryApartment}
                          onChange={(e) => {
                            console.log('Delivery Apartment changed to:', e.target.value);
                            setDeliveryApartment(e.target.value);
                          }}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          autoComplete="off"
                        />
                      </div>
                    </div>

                    <div>
                      <label className="block text-sm font-semibold text-gray-700 mb-2">
                        Country <span className="text-red-600">*</span>
                      </label>
                      <select
                        value={deliveryCountry}
                        onChange={(e) => {
                          setDeliveryCountry(e.target.value);
                          if (e.target.value !== 'United States') {
                            setDeliveryState('');
                          }
                        }}
                        className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        autoComplete="off"
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
                        <label className="block text-sm font-semibold text-gray-700 mb-2">
                          State <span className="text-red-600">*</span>
                        </label>
                        <input
                          type="text"
                          value={deliveryState}
                          onChange={(e) => setDeliveryState(e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          placeholder="California"
                          autoComplete="off"
                          required
                        />
                      </div>
                    )}

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2">
                          City <span className="text-red-600">*</span>
                        </label>
                        <input
                          type="text"
                          value={deliveryCity}
                          onChange={(e) => setDeliveryCity(e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          autoComplete="off"
                          required
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2">
                          Postal/ZIP Code <span className="text-red-600">*</span>
                        </label>
                        <input
                          type="text"
                          value={deliveryPostalCode}
                          onChange={(e) => setDeliveryPostalCode(e.target.value)}
                          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                          autoComplete="off"
                          required
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="border-t pt-6">
                <div className="bg-gradient-to-br from-green-50 to-blue-50 rounded-xl p-6 border-2 border-green-200">
                  <div className="flex items-start gap-3">
                    <div className="bg-green-500 rounded-full p-2">
                      <CreditCard className="w-5 h-5 text-white" />
                    </div>
                    <div className="flex-1">
                      <h3 className="text-lg font-bold text-gray-900 mb-1">
                        No Subscription Required
                      </h3>
                      <p className="text-sm text-gray-700">
                        As a collector, you enjoy full access to SouvenirPickers completely free. You only pay for the souvenirs you order - no subscription fees ever!
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </>
          )}

          {message && (
            <div className={`p-4 rounded-xl border-2 font-medium mb-4 ${
              message.includes('Error') ? 'bg-red-50 text-red-600 border-red-300' : 'bg-green-50 text-green-600 border-green-300'
            }`}>
              <div className="flex items-start gap-3">
                {message.includes('Error') ? (
                  <AlertCircle className="h-5 w-5 flex-shrink-0 mt-0.5" />
                ) : (
                  <CheckCircle className="h-5 w-5 flex-shrink-0 mt-0.5" />
                )}
                <div className="flex-1">
                  <pre className="whitespace-pre-wrap font-sans">{message}</pre>
                  {message.includes('100% complete') && (
                    <p className="text-sm mt-2 font-normal">Scroll up to see your profile completion banner!</p>
                  )}
                </div>
              </div>
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-blue-600 to-green-600 text-white py-4 rounded-xl font-bold text-lg hover:from-blue-700 hover:to-green-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-3 transform hover:scale-105"
          >
            <Save className="w-6 h-6" />
            {loading ? 'Saving Changes...' : 'Save All Changes'}
          </button>
        </form>

        {profile?.user_type === 'picker' && (
          <div className="border-t mt-6 pt-6">
            <PayoutSetup />
          </div>
        )}
      </div>

      {showPaymentForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-xl font-bold mb-4">Add Payment Method</h3>
            <SimplePaymentForm
              onSuccess={() => {
                setShowPaymentForm(false);
                loadPaymentMethods();
                setMessage('Payment card added successfully!');
                setTimeout(() => setMessage(''), 3000);
              }}
              onCancel={() => setShowPaymentForm(false)}
            />
          </div>
        </div>
      )}
    </div>
  );
}
