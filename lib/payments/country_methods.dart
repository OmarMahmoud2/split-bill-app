/// Country -> recommended payment methods, and country detection from the
/// device locale or the bill currency. Pure Dart.
library;

import 'bank_formats.dart';
import 'payment_method_type.dart';
import 'payment_models.dart';

/// Methods offered everywhere, appended after the local ones.
const List<String> globalPaymentMethodIds = [
  'paypal',
  'revolut',
  'wise',
  'bank_transfer',
  'other',
];

const _euro = ['sepa_qr', 'wero'];

/// Local methods per ISO 3166 alpha-2 country, most used first.
/// Sources and dates: docs/2.0/PAYMENT_METHODS.md.
const Map<String, List<String>> countryPaymentMethodIds = {
  'US': ['venmo', 'zelle', 'cash_app', 'apple_cash'],
  'GB': ['bank_transfer', 'monzo'],
  'CA': ['interac'],
  'AU': ['payid'],
  'NZ': ['bank_transfer'],
  'IE': ['revolut', 'sepa_qr'],
  'DE': ['paypal', 'sepa_qr', 'wero'],
  'AT': ['sepa_qr', 'paypal'],
  'CH': ['twint'],
  'FR': ['wero', 'lydia', 'sepa_qr'],
  'BE': ['wero', 'payconiq', 'sepa_qr'],
  'NL': ['tikkie', 'wero', 'sepa_qr'],
  'LU': ['wero', 'payconiq', 'sepa_qr'],
  'ES': ['bizum', 'sepa_qr'],
  'PT': ['mb_way', 'sepa_qr'],
  'IT': ['satispay', 'paypal', 'sepa_qr'],
  'FI': ['mobilepay', 'sepa_qr'],
  'GR': _euro,
  'SE': ['swish'],
  'NO': ['vipps'],
  'DK': ['mobilepay'],
  'IS': ['aur'],
  'PL': ['blik'],
  'CZ': ['cz_qr_platba'],
  'SK': ['sepa_qr', 'cz_qr_platba'],
  'TR': ['tr_fast', 'papara'],
  'RU': ['sbp'],
  'UA': ['monobank'],
  'EG': ['instapay', 'vodafone_cash'],
  'SA': ['sarie', 'stc_bank', 'urpay'],
  'AE': ['aani', 'careem_pay'],
  'KW': ['wamd'],
  'QA': ['fawran'],
  'BH': ['benefitpay'],
  'OM': ['bank_transfer'],
  'JO': ['cliq'],
  'LB': ['whish'],
  'MA': ['bank_transfer'],
  'TN': ['d17'],
  'DZ': ['baridimob'],
  'IQ': ['zaincash', 'fib'],
  'PK': ['raast', 'jazzcash', 'easypaisa'],
  'IN': ['upi'],
  'BD': ['bkash', 'nagad'],
  'ID': ['bank_transfer', 'gopay', 'dana', 'ovo'],
  'MY': ['duitnow', 'tng'],
  'SG': ['paynow'],
  'PH': ['gcash', 'maya'],
  'TH': ['promptpay'],
  'VN': ['vietqr', 'momo'],
  'JP': ['paypay'],
  'KR': ['toss', 'kakaopay'],
  'CN': ['wechat_pay', 'alipay'],
  'HK': ['fps', 'payme', 'alipay'],
  'TW': ['line_pay', 'jkopay'],
  'BR': ['pix'],
  'MX': ['spei', 'mercado_pago'],
  'AR': ['mercado_pago'],
  'CO': ['nequi', 'bre_b'],
  'CL': ['bank_transfer', 'mach', 'mercado_pago'],
  'PE': ['yape', 'plin'],
  'NG': ['bank_transfer', 'opay', 'palmpay'],
  'KE': ['mpesa'],
  'TZ': ['mpesa'],
  'ZA': ['bank_transfer', 'payshap'],
  'GH': ['mtn_momo', 'telecel_cash'],
  'UG': ['mtn_momo'],
};

/// Recommended methods for [countryCode]: local ones first, then the
/// worldwide ones, without duplicates. Unknown or null countries get the
/// worldwide list. Pass [platform] to drop methods that can't work there
/// (Apple Cash off iOS).
List<PaymentMethodType> methodsForCountry(
  String? countryCode, {
  PaymentPlatform? platform,
}) {
  final cc = countryCode?.trim().toUpperCase();
  final ids = <String>[
    ...?countryPaymentMethodIds[cc],
    if (cc != null &&
        !countryPaymentMethodIds.containsKey(cc) &&
        sepaEurCountries.contains(cc))
      ..._euro,
    ...globalPaymentMethodIds,
  ];
  final seen = <String>{};
  final result = <PaymentMethodType>[];
  for (final id in ids) {
    if (!seen.add(id)) continue;
    final type = paymentMethodById(id);
    if (type == null) continue;
    if (platform != null && !type.isAvailableOn(platform)) continue;
    result.add(type);
  }
  return result;
}

/// Primary country for a currency. EUR (and other shared currencies) map to
/// null: use [methodsForCurrency] or the locale's country instead.
const Map<String, String> currencyHomeCountry = {
  'USD': 'US',
  'GBP': 'GB',
  'CAD': 'CA',
  'AUD': 'AU',
  'NZD': 'NZ',
  'CHF': 'CH',
  'SEK': 'SE',
  'NOK': 'NO',
  'DKK': 'DK',
  'ISK': 'IS',
  'PLN': 'PL',
  'CZK': 'CZ',
  'TRY': 'TR',
  'RUB': 'RU',
  'UAH': 'UA',
  'EGP': 'EG',
  'SAR': 'SA',
  'AED': 'AE',
  'KWD': 'KW',
  'QAR': 'QA',
  'BHD': 'BH',
  'OMR': 'OM',
  'JOD': 'JO',
  'LBP': 'LB',
  'MAD': 'MA',
  'TND': 'TN',
  'DZD': 'DZ',
  'IQD': 'IQ',
  'PKR': 'PK',
  'INR': 'IN',
  'BDT': 'BD',
  'IDR': 'ID',
  'MYR': 'MY',
  'SGD': 'SG',
  'PHP': 'PH',
  'THB': 'TH',
  'VND': 'VN',
  'JPY': 'JP',
  'KRW': 'KR',
  'CNY': 'CN',
  'HKD': 'HK',
  'TWD': 'TW',
  'BRL': 'BR',
  'MXN': 'MX',
  'ARS': 'AR',
  'COP': 'CO',
  'CLP': 'CL',
  'PEN': 'PE',
  'NGN': 'NG',
  'KES': 'KE',
  'ZAR': 'ZA',
  'GHS': 'GH',
  'UGX': 'UG',
  'TZS': 'TZ',
};

/// Recommended methods for a bill currency.
List<PaymentMethodType> methodsForCurrency(
  String? currency, {
  PaymentPlatform? platform,
}) {
  final code = currency?.trim().toUpperCase();
  if (code == 'EUR') {
    final result = <PaymentMethodType>[
      for (final id in [..._euro, ...globalPaymentMethodIds])
        paymentMethodById(id)!,
    ];
    return result;
  }
  return methodsForCountry(currencyHomeCountry[code], platform: platform);
}

/// Best-guess country: the device locale's region when present (e.g.
/// "en_US", "pt-BR", or just "BR"), else the currency's home country.
String? detectPaymentCountry({String? localeTag, String? currency}) {
  final tag = localeTag?.trim();
  if (tag != null && tag.isNotEmpty) {
    final parts = tag.split(RegExp(r'[-_]'));
    for (final part in parts.skip(parts.length > 1 ? 1 : 0)) {
      if (RegExp(r'^[A-Za-z]{2}$').hasMatch(part) &&
          (parts.length > 1 || part == part.toUpperCase())) {
        return part.toUpperCase();
      }
    }
  }
  final code = currency?.trim().toUpperCase();
  return code == null ? null : currencyHomeCountry[code];
}

/// One-call recommendation for screens: detect the country from the locale
/// and currency, then order methods for it.
List<PaymentMethodType> recommendedPaymentMethods({
  String? localeTag,
  String? currency,
  PaymentPlatform? platform,
}) {
  final country = detectPaymentCountry(
    localeTag: localeTag,
    currency: currency,
  );
  if (country == null && currency?.toUpperCase() == 'EUR') {
    return methodsForCurrency('EUR', platform: platform);
  }
  return methodsForCountry(country, platform: platform);
}
