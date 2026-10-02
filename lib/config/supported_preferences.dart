import 'package:flutter/material.dart';

class LocaleOption {
  final Locale locale;
  final String englishName;
  final String nativeName;
  final String flag;

  const LocaleOption({
    required this.locale,
    required this.englishName,
    required this.nativeName,
    required this.flag,
  });

  String get code => locale.languageCode;
}

class CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  final String region;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.region,
  });
}

String? sanitizeCurrencyCode(String? value) {
  final normalized = value?.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (normalized == null || normalized.isEmpty) return null;
  if (!RegExp(r'^[A-Z]{3,6}$').hasMatch(normalized)) return null;
  return normalized;
}

CurrencyOption customCurrencyOption(String code) {
  final normalized = sanitizeCurrencyCode(code) ?? 'USD';
  return CurrencyOption(
    code: normalized,
    name: 'Custom currency',
    symbol: normalized,
    region: 'Custom',
  );
}

const supportedLocaleOptions = <LocaleOption>[
  LocaleOption(
    locale: Locale('en'),
    englishName: 'English',
    nativeName: 'English',
    flag: '🇺🇸',
  ),
  LocaleOption(
    locale: Locale('ar'),
    englishName: 'Arabic',
    nativeName: 'العربية',
    flag: '🇪🇬',
  ),
  LocaleOption(
    locale: Locale('fr'),
    englishName: 'French',
    nativeName: 'Français',
    flag: '🇫🇷',
  ),
  LocaleOption(
    locale: Locale('de'),
    englishName: 'German',
    nativeName: 'Deutsch',
    flag: '🇩🇪',
  ),
  LocaleOption(
    locale: Locale('ru'),
    englishName: 'Russian',
    nativeName: 'Русский',
    flag: '🇷🇺',
  ),
  LocaleOption(
    locale: Locale('id'),
    englishName: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    flag: '🇮🇩',
  ),
  LocaleOption(
    locale: Locale('ur'),
    englishName: 'Urdu',
    nativeName: 'اردو',
    flag: '🇵🇰',
  ),
  LocaleOption(
    locale: Locale('hi'),
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
  ),
  LocaleOption(
    locale: Locale('pl'),
    englishName: 'Polish',
    nativeName: 'Polski',
    flag: '🇵🇱',
  ),
  LocaleOption(
    locale: Locale('es'),
    englishName: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
  ),
  LocaleOption(
    locale: Locale('it'),
    englishName: 'Italian',
    nativeName: 'Italiano',
    flag: '🇮🇹',
  ),
  LocaleOption(
    locale: Locale('pt'),
    englishName: 'Portuguese',
    nativeName: 'Português',
    flag: '🇵🇹',
  ),
  LocaleOption(
    locale: Locale('zh'),
    englishName: 'Chinese',
    nativeName: '中文',
    flag: '🇨🇳',
  ),
  LocaleOption(
    locale: Locale('ko'),
    englishName: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
  ),
  LocaleOption(
    locale: Locale('ja'),
    englishName: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
  ),
];

const supportedCurrencyOptions = <CurrencyOption>[
  CurrencyOption(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
    region: 'Americas',
  ),
  CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€', region: 'Europe'),
  CurrencyOption(
    code: 'GBP',
    name: 'British Pound',
    symbol: '£',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'EGP',
    name: 'Egyptian Pound',
    symbol: 'E£',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SAR',
    name: 'Saudi Riyal',
    symbol: 'ر.س',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'AED',
    name: 'UAE Dirham',
    symbol: 'د.إ',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'QAR',
    name: 'Qatari Riyal',
    symbol: 'ر.ق',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'KWD',
    name: 'Kuwaiti Dinar',
    symbol: 'د.ك',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'OMR',
    name: 'Omani Rial',
    symbol: 'ر.ع.',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'BHD',
    name: 'Bahraini Dinar',
    symbol: 'د.ب',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'JPY',
    name: 'Japanese Yen',
    symbol: '¥',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'CNY',
    name: 'Chinese Yuan',
    symbol: '¥',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'KRW',
    name: 'South Korean Won',
    symbol: '₩',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: '₹',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'IDR',
    name: 'Indonesian Rupiah',
    symbol: 'Rp',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'PKR',
    name: 'Pakistani Rupee',
    symbol: '₨',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'SGD',
    name: 'Singapore Dollar',
    symbol: 'S\$',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'HKD',
    name: 'Hong Kong Dollar',
    symbol: 'HK\$',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'MYR',
    name: 'Malaysian Ringgit',
    symbol: 'RM',
    region: 'Asia',
  ),
  CurrencyOption(code: 'THB', name: 'Thai Baht', symbol: '฿', region: 'Asia'),
  CurrencyOption(
    code: 'PHP',
    name: 'Philippine Peso',
    symbol: '₱',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'VND',
    name: 'Vietnamese Dong',
    symbol: '₫',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'RUB',
    name: 'Russian Ruble',
    symbol: '₽',
    region: 'Europe/Asia',
  ),
  CurrencyOption(
    code: 'PLN',
    name: 'Polish Zloty',
    symbol: 'zł',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'CHF',
    name: 'Swiss Franc',
    symbol: 'CHF',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'SEK',
    name: 'Swedish Krona',
    symbol: 'kr',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'NOK',
    name: 'Norwegian Krone',
    symbol: 'kr',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'DKK',
    name: 'Danish Krone',
    symbol: 'kr',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'TRY',
    name: 'Turkish Lira',
    symbol: '₺',
    region: 'Europe/Asia',
  ),
  CurrencyOption(
    code: 'ZAR',
    name: 'South African Rand',
    symbol: 'R',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'KES',
    name: 'Kenyan Shilling',
    symbol: 'KSh',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'NGN',
    name: 'Nigerian Naira',
    symbol: '₦',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MAD',
    name: 'Moroccan Dirham',
    symbol: 'MAD',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'TND',
    name: 'Tunisian Dinar',
    symbol: 'DT',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'GHS',
    name: 'Ghanaian Cedi',
    symbol: '₵',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'UGX',
    name: 'Ugandan Shilling',
    symbol: 'USh',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'CAD',
    name: 'Canadian Dollar',
    symbol: 'C\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'AUD',
    name: 'Australian Dollar',
    symbol: 'A\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'NZD',
    name: 'New Zealand Dollar',
    symbol: 'NZ\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'BRL',
    name: 'Brazilian Real',
    symbol: 'R\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'MXN',
    name: 'Mexican Peso',
    symbol: 'Mex\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'ALL',
    name: 'Albanian Lek',
    symbol: 'ALL',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'AMD',
    name: 'Armenian Dram',
    symbol: 'AMD',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'ANG',
    name: 'Netherlands Antillean Guilder',
    symbol: 'ANG',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'AOA',
    name: 'Angolan Kwanza',
    symbol: 'Kz',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'ARS',
    name: 'Argentine Peso',
    symbol: 'AR\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'AWG',
    name: 'Aruban Florin',
    symbol: 'Afl',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'AZN',
    name: 'Azerbaijani Manat',
    symbol: 'AZN',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'BAM',
    name: 'Bosnia-Herzegovina Convertible Mark',
    symbol: 'KM',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'BBD',
    name: 'Barbadian Dollar',
    symbol: 'Bds\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'BDT',
    name: 'Bangladeshi Taka',
    symbol: 'Tk',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'BGN',
    name: 'Bulgarian Lev',
    symbol: 'BGN',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'BIF',
    name: 'Burundian Franc',
    symbol: 'BIF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'BMD',
    name: 'Bermudian Dollar',
    symbol: 'BD\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'BND',
    name: 'Brunei Dollar',
    symbol: 'B\$',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'BOB',
    name: 'Bolivian Boliviano',
    symbol: 'Bs',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'BSD',
    name: 'Bahamian Dollar',
    symbol: 'B\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'BTN',
    name: 'Bhutanese Ngultrum',
    symbol: 'Nu',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'BWP',
    name: 'Botswana Pula',
    symbol: 'P',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'BYN',
    name: 'Belarusian Ruble',
    symbol: 'Br',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'BZD',
    name: 'Belize Dollar',
    symbol: 'BZ\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'CDF',
    name: 'Congolese Franc',
    symbol: 'CDF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'CLP',
    name: 'Chilean Peso',
    symbol: 'CLP',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'COP',
    name: 'Colombian Peso',
    symbol: 'COL\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'CRC',
    name: 'Costa Rican Colon',
    symbol: 'CRC',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'CUP',
    name: 'Cuban Peso',
    symbol: 'CUP',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'CVE',
    name: 'Cape Verdean Escudo',
    symbol: 'CVE',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'CZK',
    name: 'Czech Koruna',
    symbol: 'Kc',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'DJF',
    name: 'Djiboutian Franc',
    symbol: 'DJF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'DOP',
    name: 'Dominican Peso',
    symbol: 'RD\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'DZD',
    name: 'Algerian Dinar',
    symbol: 'DA',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'ETB',
    name: 'Ethiopian Birr',
    symbol: 'Br',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'FJD',
    name: 'Fijian Dollar',
    symbol: 'FJ\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'GEL',
    name: 'Georgian Lari',
    symbol: 'GEL',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'GMD',
    name: 'Gambian Dalasi',
    symbol: 'D',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'GNF',
    name: 'Guinean Franc',
    symbol: 'GNF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'GTQ',
    name: 'Guatemalan Quetzal',
    symbol: 'Q',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'GYD',
    name: 'Guyanese Dollar',
    symbol: 'G\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'HNL',
    name: 'Honduran Lempira',
    symbol: 'L',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'HRK',
    name: 'Croatian Kuna',
    symbol: 'kn',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'HTG',
    name: 'Haitian Gourde',
    symbol: 'G',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'HUF',
    name: 'Hungarian Forint',
    symbol: 'Ft',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'ILS',
    name: 'Israeli New Shekel',
    symbol: 'ILS',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'IQD',
    name: 'Iraqi Dinar',
    symbol: 'IQD',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'IRR',
    name: 'Iranian Rial',
    symbol: 'IRR',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'ISK',
    name: 'Icelandic Krona',
    symbol: 'kr',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'JMD',
    name: 'Jamaican Dollar',
    symbol: 'J\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'JOD',
    name: 'Jordanian Dinar',
    symbol: 'JD',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'KGS',
    name: 'Kyrgyzstani Som',
    symbol: 'KGS',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'KHR',
    name: 'Cambodian Riel',
    symbol: 'KHR',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'KMF',
    name: 'Comorian Franc',
    symbol: 'KMF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'KZT',
    name: 'Kazakhstani Tenge',
    symbol: 'KZT',
    region: 'Asia',
  ),
  CurrencyOption(code: 'LAK', name: 'Lao Kip', symbol: 'LAK', region: 'Asia'),
  CurrencyOption(
    code: 'LBP',
    name: 'Lebanese Pound',
    symbol: 'LBP',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'LKR',
    name: 'Sri Lankan Rupee',
    symbol: 'Rs',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'LRD',
    name: 'Liberian Dollar',
    symbol: 'L\$',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'LSL',
    name: 'Lesotho Loti',
    symbol: 'L',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'LYD',
    name: 'Libyan Dinar',
    symbol: 'LD',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MDL',
    name: 'Moldovan Leu',
    symbol: 'MDL',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'MGA',
    name: 'Malagasy Ariary',
    symbol: 'MGA',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MKD',
    name: 'Macedonian Denar',
    symbol: 'MKD',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'MMK',
    name: 'Myanmar Kyat',
    symbol: 'MMK',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'MNT',
    name: 'Mongolian Tugrik',
    symbol: 'MNT',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'MOP',
    name: 'Macanese Pataca',
    symbol: 'MOP',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'MRU',
    name: 'Mauritanian Ouguiya',
    symbol: 'MRU',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MUR',
    name: 'Mauritian Rupee',
    symbol: 'Rs',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MVR',
    name: 'Maldivian Rufiyaa',
    symbol: 'MVR',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'MWK',
    name: 'Malawian Kwacha',
    symbol: 'MWK',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'MZN',
    name: 'Mozambican Metical',
    symbol: 'MT',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'NAD',
    name: 'Namibian Dollar',
    symbol: 'N\$',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'NIO',
    name: 'Nicaraguan Cordoba',
    symbol: 'C\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'NPR',
    name: 'Nepalese Rupee',
    symbol: 'Rs',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'PAB',
    name: 'Panamanian Balboa',
    symbol: 'B/.',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'PEN',
    name: 'Peruvian Sol',
    symbol: 'S/',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'PGK',
    name: 'Papua New Guinean Kina',
    symbol: 'K',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'PYG',
    name: 'Paraguayan Guarani',
    symbol: 'PYG',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'RON',
    name: 'Romanian Leu',
    symbol: 'lei',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'RSD',
    name: 'Serbian Dinar',
    symbol: 'RSD',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'RWF',
    name: 'Rwandan Franc',
    symbol: 'RWF',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SBD',
    name: 'Solomon Islands Dollar',
    symbol: 'SI\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'SCR',
    name: 'Seychellois Rupee',
    symbol: 'SCR',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SDG',
    name: 'Sudanese Pound',
    symbol: 'SDG',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SOS',
    name: 'Somali Shilling',
    symbol: 'SOS',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SRD',
    name: 'Surinamese Dollar',
    symbol: 'SRD',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'SSP',
    name: 'South Sudanese Pound',
    symbol: 'SSP',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'STN',
    name: 'Sao Tome and Principe Dobra',
    symbol: 'STN',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'SVC',
    name: 'Salvadoran Colon',
    symbol: 'SVC',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'SYP',
    name: 'Syrian Pound',
    symbol: 'SYP',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'TJS',
    name: 'Tajikistani Somoni',
    symbol: 'TJS',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'TMT',
    name: 'Turkmenistani Manat',
    symbol: 'TMT',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'TOP',
    name: 'Tongan Paanga',
    symbol: 'T\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'TTD',
    name: 'Trinidad and Tobago Dollar',
    symbol: 'TT\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'TWD',
    name: 'New Taiwan Dollar',
    symbol: 'NT\$',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'TZS',
    name: 'Tanzanian Shilling',
    symbol: 'TSh',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'UAH',
    name: 'Ukrainian Hryvnia',
    symbol: 'UAH',
    region: 'Europe',
  ),
  CurrencyOption(
    code: 'UYU',
    name: 'Uruguayan Peso',
    symbol: 'UYU',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'UZS',
    name: 'Uzbekistani Som',
    symbol: 'UZS',
    region: 'Asia',
  ),
  CurrencyOption(
    code: 'WST',
    name: 'Samoan Tala',
    symbol: 'WS\$',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'XAF',
    name: 'Central African CFA Franc',
    symbol: 'FCFA',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'XCD',
    name: 'East Caribbean Dollar',
    symbol: 'EC\$',
    region: 'Americas',
  ),
  CurrencyOption(
    code: 'XOF',
    name: 'West African CFA Franc',
    symbol: 'CFA',
    region: 'Africa',
  ),
  CurrencyOption(
    code: 'XPF',
    name: 'CFP Franc',
    symbol: 'XPF',
    region: 'Oceania',
  ),
  CurrencyOption(
    code: 'YER',
    name: 'Yemeni Rial',
    symbol: 'YER',
    region: 'Middle East',
  ),
  CurrencyOption(
    code: 'ZMW',
    name: 'Zambian Kwacha',
    symbol: 'ZK',
    region: 'Africa',
  ),
];

LocaleOption findLocaleOption(String code) {
  return supportedLocaleOptions.firstWhere(
    (option) => option.code == code,
    orElse: () => supportedLocaleOptions.first,
  );
}

CurrencyOption findCurrencyOption(String code) {
  final normalized = sanitizeCurrencyCode(code);
  if (normalized == null) return supportedCurrencyOptions.first;

  return supportedCurrencyOptions.firstWhere(
    (option) => option.code == normalized,
    orElse: () => customCurrencyOption(normalized),
  );
}

Locale resolveSupportedLocale(
  Iterable<Locale> preferredLocales, {
  Locale fallback = const Locale('en'),
}) {
  for (final locale in preferredLocales) {
    final match = supportedLocaleOptions.where(
      (option) => option.code == locale.languageCode,
    );
    if (match.isNotEmpty) {
      return match.first.locale;
    }
  }

  return fallback;
}
