import 'package:flutter/material.dart';

class LocaleOption {
  final Locale locale;
  final String englishName;
  final String nativeName;

  const LocaleOption({
    required this.locale,
    required this.englishName,
    required this.nativeName,
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

const supportedLocaleOptions = <LocaleOption>[
  LocaleOption(
    locale: Locale('en'),
    englishName: 'English',
    nativeName: 'English',
  ),
  LocaleOption(
    locale: Locale('ar'),
    englishName: 'Arabic',
    nativeName: 'العربية',
  ),
  LocaleOption(
    locale: Locale('fr'),
    englishName: 'French',
    nativeName: 'Français',
  ),
  LocaleOption(
    locale: Locale('de'),
    englishName: 'German',
    nativeName: 'Deutsch',
  ),
  LocaleOption(
    locale: Locale('ru'),
    englishName: 'Russian',
    nativeName: 'Русский',
  ),
  LocaleOption(
    locale: Locale('id'),
    englishName: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
  ),
  LocaleOption(
    locale: Locale('ur'),
    englishName: 'Urdu',
    nativeName: 'اردو',
  ),
  LocaleOption(
    locale: Locale('hi'),
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
  ),
  LocaleOption(
    locale: Locale('pl'),
    englishName: 'Polish',
    nativeName: 'Polski',
  ),
  LocaleOption(
    locale: Locale('es'),
    englishName: 'Spanish',
    nativeName: 'Español',
  ),
  LocaleOption(
    locale: Locale('it'),
    englishName: 'Italian',
    nativeName: 'Italiano',
  ),
  LocaleOption(
    locale: Locale('pt'),
    englishName: 'Portuguese',
    nativeName: 'Português',
  ),
  LocaleOption(
    locale: Locale('zh'),
    englishName: 'Chinese',
    nativeName: '中文',
  ),
  LocaleOption(
    locale: Locale('ko'),
    englishName: 'Korean',
    nativeName: '한국어',
  ),
  LocaleOption(
    locale: Locale('ja'),
    englishName: 'Japanese',
    nativeName: '日本語',
  ),
];

const supportedCurrencyOptions = <CurrencyOption>[
  CurrencyOption(code: 'USD', name: 'US Dollar', symbol: '\$', region: 'Americas'),
  CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€', region: 'Europe'),
  CurrencyOption(code: 'GBP', name: 'British Pound', symbol: '£', region: 'Europe'),
  CurrencyOption(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', region: 'Africa'),
  CurrencyOption(code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س', region: 'Middle East'),
  CurrencyOption(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', region: 'Middle East'),
  CurrencyOption(code: 'QAR', name: 'Qatari Riyal', symbol: 'ر.ق', region: 'Middle East'),
  CurrencyOption(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', region: 'Middle East'),
  CurrencyOption(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.', region: 'Middle East'),
  CurrencyOption(code: 'BHD', name: 'Bahraini Dinar', symbol: 'د.ب', region: 'Middle East'),
  CurrencyOption(code: 'JPY', name: 'Japanese Yen', symbol: '¥', region: 'Asia'),
  CurrencyOption(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', region: 'Asia'),
  CurrencyOption(code: 'KRW', name: 'South Korean Won', symbol: '₩', region: 'Asia'),
  CurrencyOption(code: 'INR', name: 'Indian Rupee', symbol: '₹', region: 'Asia'),
  CurrencyOption(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', region: 'Asia'),
  CurrencyOption(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', region: 'Asia'),
  CurrencyOption(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', region: 'Asia'),
  CurrencyOption(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$', region: 'Asia'),
  CurrencyOption(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', region: 'Asia'),
  CurrencyOption(code: 'THB', name: 'Thai Baht', symbol: '฿', region: 'Asia'),
  CurrencyOption(code: 'PHP', name: 'Philippine Peso', symbol: '₱', region: 'Asia'),
  CurrencyOption(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', region: 'Asia'),
  CurrencyOption(code: 'RUB', name: 'Russian Ruble', symbol: '₽', region: 'Europe/Asia'),
  CurrencyOption(code: 'PLN', name: 'Polish Zloty', symbol: 'zł', region: 'Europe'),
  CurrencyOption(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', region: 'Europe'),
  CurrencyOption(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', region: 'Europe'),
  CurrencyOption(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', region: 'Europe'),
  CurrencyOption(code: 'DKK', name: 'Danish Krone', symbol: 'kr', region: 'Europe'),
  CurrencyOption(code: 'TRY', name: 'Turkish Lira', symbol: '₺', region: 'Europe/Asia'),
  CurrencyOption(code: 'ZAR', name: 'South African Rand', symbol: 'R', region: 'Africa'),
  CurrencyOption(code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh', region: 'Africa'),
  CurrencyOption(code: 'NGN', name: 'Nigerian Naira', symbol: '₦', region: 'Africa'),
  CurrencyOption(code: 'MAD', name: 'Moroccan Dirham', symbol: 'MAD', region: 'Africa'),
  CurrencyOption(code: 'TND', name: 'Tunisian Dinar', symbol: 'DT', region: 'Africa'),
  CurrencyOption(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵', region: 'Africa'),
  CurrencyOption(code: 'UGX', name: 'Ugandan Shilling', symbol: 'USh', region: 'Africa'),
  CurrencyOption(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', region: 'Americas'),
  CurrencyOption(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', region: 'Oceania'),
  CurrencyOption(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$', region: 'Oceania'),
  CurrencyOption(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', region: 'Americas'),
  CurrencyOption(code: 'MXN', name: 'Mexican Peso', symbol: 'Mex\$', region: 'Americas'),
];

LocaleOption findLocaleOption(String code) {
  return supportedLocaleOptions.firstWhere(
    (option) => option.code == code,
    orElse: () => supportedLocaleOptions.first,
  );
}

CurrencyOption findCurrencyOption(String code) {
  return supportedCurrencyOptions.firstWhere(
    (option) => option.code == code,
    orElse: () => supportedCurrencyOptions.first,
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
