export const COUNTRIES = [
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

export const COUNTRY_NAME_TO_CODE: Record<string, string> = {
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

export function toCountryCode(name: string): string {
  if (!name) return '';
  if (/^[A-Z]{2}$/.test(name.trim().toUpperCase())) return name.trim().toUpperCase();
  return COUNTRY_NAME_TO_CODE[name.trim()] || '';
}
