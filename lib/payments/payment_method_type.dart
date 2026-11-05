/// Registry of payment methods people use to pay friends back, with honest
/// link capabilities (see docs/2.0/PAYMENT_METHODS.md for sources).
/// Pure Dart.
library;

import 'dart:convert';

import 'bank_formats.dart';
import 'emv_qr.dart';
import 'payment_models.dart';

typedef PaymentLaunchBuilder =
    PaymentLaunch Function(PaymentMethodType type, PaymentRequest request);
typedef PaymentQrBuilder =
    String? Function(PaymentMethodType type, PaymentRequest request);

/// One payment method (PayPal, Pix, Swish...).
class PaymentMethodType {
  const PaymentMethodType({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.brandColor,
    required this.handleKinds,
    required this.capability,
    required this.descriptionKey,
    this.countries = const {},
    this.currencies,
    this.platforms,
    this.aliases = const [],
    this.linkHosts = const [],
    this.logoAsset,
    this.appUri,
    PaymentLaunchBuilder? launch,
    PaymentQrBuilder? qr,
  }) : _launch = launch,
       _qr = qr;

  /// Stable id stored in Firestore as `type` (e.g. "paypal").
  final String id;
  final String displayName;

  /// Two-letter fallback badge when there is no [logoAsset].
  final String initials;

  /// Brand colour as ARGB (use `Color(type.brandColor)` in Flutter).
  final int brandColor;

  /// Bundled logo, if the app ships one.
  final String? logoAsset;

  /// Accepted handle kinds, preferred first.
  final List<HandleKind> handleKinds;

  /// Best capability when the request matches the method's currency.
  final PaymentCapability capability;

  /// Translation key for a one-line description.
  final String descriptionKey;

  /// ISO 3166 alpha-2 countries where it is used; empty = worldwide.
  final Set<String> countries;

  /// Currencies the link can prefill; null = any.
  final Set<String>? currencies;

  /// Platforms where the pay action works; null = all.
  final Set<PaymentPlatform>? platforms;

  /// Lower-case names this method was stored under before 2.0.
  final List<String> aliases;

  /// Hosts of the provider's own links (paypal.me...), parsed for a handle.
  final List<String> linkHosts;

  /// Generic "open the app/site" target for copy-only methods.
  final Uri? appUri;

  final PaymentLaunchBuilder? _launch;
  final PaymentQrBuilder? _qr;

  bool get isGlobal => countries.isEmpty;

  HandleKind get primaryHandleKind => handleKinds.first;

  /// True when the method can be used on [platform].
  bool isAvailableOn(PaymentPlatform platform) =>
      platforms == null || platforms!.contains(platform);

  /// True when the link can carry an amount in [currency].
  bool prefillsCurrency(String? currency) =>
      currency != null &&
      (currencies == null || currencies!.contains(currency.toUpperCase()));

  /// The first handle kind that accepts [raw], or null.
  HandleKind? kindFor(String raw) {
    for (final kind in handleKinds) {
      if (kind.validate(raw)) return kind;
    }
    if (linkHandle(raw) != null) return HandleKind.url;
    return null;
  }

  /// Whether [raw] is a valid handle for this method (a provider link counts).
  bool validateHandle(String raw) =>
      kindFor(raw) != null || HandleKind.url.validate(raw);

  /// Canonical handle used in links and copies.
  String normalizeHandle(String raw) {
    final fromLink = linkHandle(raw);
    if (fromLink != null) return fromLink;
    final kind = kindFor(raw);
    return kind == null ? raw.trim() : kind.normalize(raw);
  }

  /// Extracts the handle from one of this provider's links
  /// ("https://paypal.me/omar/5" -> "omar").
  String? linkHandle(String raw) {
    if (linkHosts.isEmpty) return null;
    var v = raw.trim();
    if (!v.contains('://')) v = 'https://$v';
    final uri = Uri.tryParse(v);
    if (uri == null || !linkHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    // venmo.com/u/<user>, account.venmo.com/u/<user>
    final index = segments.first == 'u' && segments.length > 1 ? 1 : 0;
    final first = Uri.decodeComponent(segments[index]);
    return first.startsWith('@') ? first.substring(1) : first;
  }

  /// What tapping this method should do for [request].
  PaymentLaunch buildLaunch(PaymentRequest request) {
    final raw = request.handle.trim();
    // A pasted link we can't rebuild (InstaPay, Tikkie, custom...): open it.
    if (HandleKind.url.validate(raw) && linkHandle(raw) == null) {
      return _openStoredLink(this, request, Uri.parse(raw));
    }
    final builder = _launch ?? _copyHandle;
    return builder(this, request);
  }

  /// QR / copy-paste payload (Pix, PromptPay, PayNow, VietQR, EPC, SPAYD,
  /// UPI), or null when the method has none or the handle doesn't fit.
  String? qrPayload(PaymentRequest request) {
    final builder = _qr;
    if (builder == null) return null;
    try {
      return builder(this, request);
    } on ArgumentError {
      return null;
    }
  }

  @override
  String toString() => 'PaymentMethodType($id)';
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Map<String, String> _args(
  PaymentMethodType t,
  PaymentRequest r,
  String handle,
) => {'app': t.displayName, 'amount': r.displayAmount, 'handle': handle};

CopyInstruction _copyHandle(
  PaymentMethodType t,
  PaymentRequest r, {
  String key = 'payment_instruction_copy_handle',
}) {
  final handle = t.normalizeHandle(r.handle);
  return CopyInstruction(
    text: handle,
    openUri: t.appUri,
    instructionKey: key,
    instructionArgs: _args(t, r, handle),
  );
}

DeepLinkLaunch _openStoredLink(
  PaymentMethodType t,
  PaymentRequest r,
  Uri link,
) => DeepLinkLaunch(
  uri: link,
  prefillsAmount: false,
  clipboardText: r.amountString,
  fallback: CopyInstruction(
    text: link.toString(),
    instructionKey: 'payment_instruction_copy_handle',
    instructionArgs: _args(t, r, link.toString()),
  ),
  instructionKey: 'payment_instruction_opens_enter_amount',
  instructionArgs: _args(t, r, link.toString()),
);

DeepLinkLaunch _link(
  PaymentMethodType t,
  PaymentRequest r, {
  required Uri uri,
  Uri? web,
  required bool prefills,
}) {
  final handle = t.normalizeHandle(r.handle);
  return DeepLinkLaunch(
    uri: uri,
    webFallback: web,
    prefillsAmount: prefills,
    clipboardText: prefills ? null : r.amountString,
    fallback: _copyHandle(t, r),
    instructionKey: prefills
        ? 'payment_instruction_opens_prefilled'
        : 'payment_instruction_opens_enter_amount',
    instructionArgs: _args(t, r, handle),
  );
}

/// Amount string when [t] can prefill the request's currency, else null.
String? _prefillAmount(PaymentMethodType t, PaymentRequest r) =>
    t.prefillsCurrency(r.currency) ? r.amountString : null;

String _qs(Map<String, String?> params) => params.entries
    .where((e) => e.value != null && e.value!.isNotEmpty)
    .map((e) => '${e.key}=${Uri.encodeComponent(e.value!)}')
    .join('&');

/// PayPal.me: `https://paypal.me/<user>/<amount><CUR>`. Emails can't be put in
/// a PayPal.me link, so they are copied.
PaymentLaunch _paypal(PaymentMethodType t, PaymentRequest r) {
  final handle = t.normalizeHandle(r.handle);
  if (HandleKind.email.validate(handle)) {
    return _copyHandle(t, r);
  }
  final amount = _prefillAmount(t, r);
  final path = amount == null
      ? '/${Uri.encodeComponent(handle)}'
      : '/${Uri.encodeComponent(handle)}/$amount${r.currency}';
  return _link(
    t,
    r,
    uri: Uri.parse('https://paypal.me$path'),
    prefills: amount != null,
  );
}

/// Venmo app scheme, with the venmo.com payment-link fallback.
PaymentLaunch _venmo(PaymentMethodType t, PaymentRequest r) {
  final handle = t.normalizeHandle(r.handle);
  final amount = _prefillAmount(t, r);
  final query = _qs({
    'txn': 'pay',
    'recipients': handle,
    'amount': amount,
    'note': r.note,
  });
  return _link(
    t,
    r,
    uri: Uri.parse('venmo://paycharge?$query'),
    web: Uri.parse('https://venmo.com/?$query'),
    prefills: amount != null,
  );
}

/// Cash App: `https://cash.app/$cashtag/<amount>`.
PaymentLaunch _cashApp(PaymentMethodType t, PaymentRequest r) {
  final tag = HandleKind.cashtag.normalize(t.normalizeHandle(r.handle));
  final amount = _prefillAmount(t, r);
  final path = amount == null ? '/$tag' : '/$tag/$amount';
  return _link(
    t,
    r,
    uri: Uri.parse('https://cash.app$path'),
    prefills: amount != null,
  );
}

/// Monzo: `https://monzo.me/<user>/<amount>?d=<note>`.
PaymentLaunch _monzo(PaymentMethodType t, PaymentRequest r) {
  final handle = t.normalizeHandle(r.handle);
  final amount = _prefillAmount(t, r);
  final note = r.note == null ? '' : '?${_qs({'d': r.note})}';
  final path = amount == null ? '/$handle' : '/$handle/$amount$note';
  return _link(
    t,
    r,
    uri: Uri.parse('https://monzo.me$path'),
    prefills: amount != null,
  );
}

/// Recipient-only profile links (`revolut.me/<tag>`, `toss.me/<id>`).
PaymentLaunchBuilder _profileLink(String base) => (t, r) {
  final handle = t.normalizeHandle(r.handle);
  if (!HandleKind.username.validate(handle)) return _copyHandle(t, r);
  return _link(
    t,
    r,
    uri: Uri.parse('$base/${Uri.encodeComponent(handle)}'),
    prefills: false,
  );
};

/// UPI intent link; the same string is the UPI QR content.
PaymentLaunch _upi(PaymentMethodType t, PaymentRequest r) {
  final vpa = t.normalizeHandle(r.handle);
  if (!HandleKind.upiVpa.validate(vpa)) return _copyHandle(t, r);
  final uri = buildUpiUri(
    vpa: vpa,
    payeeName: r.recipientName,
    amount: _prefillAmount(t, r),
    note: r.note,
  );
  return _link(t, r, uri: uri, prefills: _prefillAmount(t, r) != null);
}

String? _upiQr(PaymentMethodType t, PaymentRequest r) {
  final vpa = t.normalizeHandle(r.handle);
  if (!HandleKind.upiVpa.validate(vpa)) return null;
  return buildUpiUri(
    vpa: vpa,
    payeeName: r.recipientName,
    amount: _prefillAmount(t, r),
    note: r.note,
  ).toString();
}

/// Swish app-switch with a prefilled payment (Swish QR/app-switch format).
PaymentLaunch _swish(PaymentMethodType t, PaymentRequest r) {
  final number = t.normalizeHandle(r.handle).replaceAll('+46', '0');
  final amount = _prefillAmount(t, r);
  final data = <String, Object>{
    'version': 1,
    'payee': {'value': number, 'editable': false},
    if (amount != null)
      'amount': {'value': double.parse(amount), 'editable': false},
    if (r.note != null && r.note!.isNotEmpty)
      'message': {
        'value': r.note!.length > 50 ? r.note!.substring(0, 50) : r.note!,
        'editable': true,
      },
  };
  final uri = Uri.parse(
    'swish://payment?data=${Uri.encodeComponent(jsonEncode(data))}',
  );
  return _link(t, r, uri: uri, prefills: amount != null);
}

/// Apple Cash: no third-party API. Open Messages to the recipient with a
/// prefilled note; the payer taps Apple Cash there.
PaymentLaunch _appleCash(PaymentMethodType t, PaymentRequest r) {
  final handle = t.normalizeHandle(r.handle);
  final message =
      r.message ??
      [
        'Paying you',
        if (r.displayAmount.isNotEmpty) r.displayAmount,
        if (r.note != null && r.note!.isNotEmpty) 'for ${r.note}',
        'via Apple Cash',
      ].join(' ');
  final uri = Uri.parse(
    'sms:${Uri.encodeComponent(handle).replaceAll('%2B', '+').replaceAll('%40', '@')}'
    '&body=${Uri.encodeComponent(message)}',
  );
  return DeepLinkLaunch(
    uri: uri,
    prefillsAmount: false,
    clipboardText: r.amountString,
    fallback: _copyHandle(t, r),
    instructionKey: 'payment_instruction_apple_cash',
    instructionArgs: _args(t, r, handle),
  );
}

PaymentLaunch _zelle(PaymentMethodType t, PaymentRequest r) =>
    _copyHandle(t, r, key: 'payment_instruction_zelle');

/// Pix: copy the BR Code ("Pix copia e cola"); QR shows the same payload.
PaymentLaunch _pix(PaymentMethodType t, PaymentRequest r) {
  final payload = _pixQr(t, r);
  if (payload == null) return _copyHandle(t, r);
  return CopyInstruction(
    text: payload,
    instructionKey: 'payment_instruction_copy_code',
    instructionArgs: _args(t, r, t.normalizeHandle(r.handle)),
  );
}

String? _pixQr(PaymentMethodType t, PaymentRequest r) {
  final key = t.normalizeHandle(r.handle);
  if (!isValidPixKey(key)) return null;
  return buildPixPayload(
    key: key,
    merchantName: r.recipientName ?? 'Evens',
    merchantCity: 'BRASIL',
    amount: _prefillAmount(t, r),
    description: r.note,
  );
}

/// QR-first methods: copy the handle, show the QR.
PaymentLaunchBuilder _qrCopy() => (t, r) {
  final hasQr = t.qrPayload(r) != null;
  return _copyHandle(
    t,
    r,
    key: hasQr
        ? 'payment_instruction_scan_qr'
        : 'payment_instruction_copy_handle',
  );
};

String? _promptPayQr(PaymentMethodType t, PaymentRequest r) {
  final id = t.normalizeHandle(r.handle);
  if (!HandleKind.promptPayId.validate(id)) return null;
  return buildPromptPayPayload(id: id, amount: _prefillAmount(t, r));
}

String? _payNowQr(PaymentMethodType t, PaymentRequest r) {
  final proxy = t.normalizeHandle(r.handle);
  if (!HandleKind.payNowProxy.validate(proxy)) return null;
  return buildPayNowPayload(
    proxy: proxy,
    merchantName: r.recipientName ?? 'NA',
    amount: _prefillAmount(t, r),
    reference: r.note,
  );
}

String? _vietQr(PaymentMethodType t, PaymentRequest r) {
  final parsed = parseVietQrAccount(r.handle);
  if (parsed == null) return null;
  return buildVietQrPayload(
    bankBin: parsed.$1,
    accountNumber: parsed.$2,
    amount: _prefillAmount(t, r),
    message: r.note,
  );
}

String? _epcQr(PaymentMethodType t, PaymentRequest r) {
  final iban = compactIban(r.handle);
  if (!isValidIban(iban)) return null;
  if (r.currency != null && r.currency != 'EUR') return null;
  return buildEpcQrPayload(
    name: (r.recipientName == null || r.recipientName!.trim().isEmpty)
        ? 'Evens'
        : r.recipientName!,
    iban: iban,
    amountEur: r.currency == 'EUR' ? r.amountString : null,
    remittance: r.note,
  );
}

String? _spaydQr(PaymentMethodType t, PaymentRequest r) {
  final iban = compactIban(r.handle);
  if (!isValidIban(iban)) return null;
  final currency = r.currency ?? 'CZK';
  if (currency != 'CZK' && currency != 'EUR') return null;
  return buildSpaydPayload(
    iban: iban,
    amount: r.amountString,
    currency: currency,
    message: r.note,
    recipientName: r.recipientName,
  );
}

/// Bank transfer: EPC QR when the handle is an IBAN and the bill is in EUR.
String? _bankQr(PaymentMethodType t, PaymentRequest r) =>
    r.currency == 'EUR' ? _epcQr(t, r) : null;

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

const _phone = [HandleKind.phone];
const _phoneOrEmail = [HandleKind.phoneOrEmail];
const _bank = [HandleKind.iban, HandleKind.accountDetails];

const _descGlobal = 'payment_desc_global_wallet';
const _descApp = 'payment_desc_p2p_app';
const _descWallet = 'payment_desc_mobile_wallet';
const _descBank = 'payment_desc_bank_instant';
const _descQr = 'payment_desc_bank_qr';

PaymentMethodType _wallet(
  String id,
  String name,
  String initials,
  int color,
  Set<String> countries, {
  List<String> aliases = const [],
  List<HandleKind> kinds = _phone,
  String desc = _descWallet,
  Uri? app,
}) => PaymentMethodType(
  id: id,
  displayName: name,
  initials: initials,
  brandColor: color,
  handleKinds: kinds,
  capability: PaymentCapability.copy,
  descriptionKey: desc,
  countries: countries,
  aliases: aliases,
  appUri: app,
);

/// Every method the app knows, keyed by [PaymentMethodType.id].
final List<PaymentMethodType> paymentMethodRegistry = [
  // Global -----------------------------------------------------------------
  PaymentMethodType(
    id: 'paypal',
    displayName: 'PayPal',
    initials: 'PP',
    brandColor: 0xFF003087,
    logoAsset: 'assets/payments/paypal.jpg',
    handleKinds: const [HandleKind.username, HandleKind.email],
    capability: PaymentCapability.prefill,
    descriptionKey: _descGlobal,
    currencies: const {
      'AUD',
      'BRL',
      'CAD',
      'CHF',
      'CNY',
      'CZK',
      'DKK',
      'EUR',
      'GBP',
      'HKD',
      'HUF',
      'ILS',
      'JPY',
      'MXN',
      'MYR',
      'NOK',
      'NZD',
      'PHP',
      'PLN',
      'SEK',
      'SGD',
      'THB',
      'TWD',
      'USD',
    },
    aliases: const ['paypal', 'pay pal', 'paypal.me'],
    linkHosts: const ['paypal.me', 'www.paypal.me'],
    launch: _paypal,
  ),
  PaymentMethodType(
    id: 'revolut',
    displayName: 'Revolut',
    initials: 'R',
    brandColor: 0xFF0055FF,
    handleKinds: const [HandleKind.username, HandleKind.phone],
    capability: PaymentCapability.recipientOnly,
    descriptionKey: _descGlobal,
    aliases: const ['revolut', 'revtag'],
    linkHosts: const ['revolut.me', 'www.revolut.me'],
    launch: _profileLink('https://revolut.me'),
  ),
  PaymentMethodType(
    id: 'wise',
    displayName: 'Wise',
    initials: 'W',
    brandColor: 0xFF9FE870,
    handleKinds: const [HandleKind.email, HandleKind.username, HandleKind.iban],
    capability: PaymentCapability.copy,
    descriptionKey: _descGlobal,
    aliases: const ['wise', 'transferwise'],
    appUri: Uri.parse('https://wise.com/send'),
  ),
  PaymentMethodType(
    id: 'bank_transfer',
    displayName: 'Bank transfer',
    initials: 'BT',
    brandColor: 0xFF455A64,
    handleKinds: _bank,
    capability: PaymentCapability.copy,
    descriptionKey: _descBank,
    aliases: const ['bank transfer', 'bank', 'iban', 'wire', 'account'],
    launch: _qrCopy(),
    qr: _bankQr,
  ),
  const PaymentMethodType(
    id: 'other',
    displayName: 'Other',
    initials: '…',
    brandColor: 0xFF607D8B,
    handleKinds: [HandleKind.url, HandleKind.accountDetails],
    capability: PaymentCapability.copy,
    descriptionKey: 'payment_desc_custom',
    aliases: ['other'],
  ),

  // United States ------------------------------------------------------------
  PaymentMethodType(
    id: 'venmo',
    displayName: 'Venmo',
    initials: 'V',
    brandColor: 0xFF008CFF,
    logoAsset: 'assets/payments/venmo.png',
    handleKinds: const [HandleKind.username, HandleKind.phoneOrEmail],
    capability: PaymentCapability.prefill,
    descriptionKey: _descApp,
    countries: const {'US'},
    currencies: const {'USD'},
    aliases: const ['venmo'],
    linkHosts: const ['venmo.com', 'www.venmo.com', 'account.venmo.com'],
    launch: _venmo,
  ),
  PaymentMethodType(
    id: 'cash_app',
    displayName: 'Cash App',
    initials: r'$',
    brandColor: 0xFF00D632,
    handleKinds: const [HandleKind.cashtag],
    capability: PaymentCapability.prefill,
    descriptionKey: _descApp,
    countries: const {'US'},
    currencies: const {'USD'},
    aliases: const ['cash app', 'cashapp', 'cashtag', 'square cash'],
    linkHosts: const ['cash.app', 'cash.me'],
    launch: _cashApp,
  ),
  const PaymentMethodType(
    id: 'zelle',
    displayName: 'Zelle',
    initials: 'Z',
    brandColor: 0xFF6D1ED4,
    handleKinds: _phoneOrEmail,
    capability: PaymentCapability.copy,
    descriptionKey: _descBank,
    countries: {'US'},
    aliases: ['zelle'],
    launch: _zelle,
  ),
  const PaymentMethodType(
    id: 'apple_cash',
    displayName: 'Apple Cash',
    initials: 'AC',
    brandColor: 0xFF111111,
    handleKinds: _phoneOrEmail,
    capability: PaymentCapability.recipientOnly,
    descriptionKey: 'payment_desc_apple_cash',
    countries: {'US'},
    currencies: {'USD'},
    platforms: {PaymentPlatform.ios},
    aliases: ['apple cash', 'apple pay cash', 'apple pay'],
    launch: _appleCash,
  ),

  // Rest of the Americas ---------------------------------------------------
  _wallet(
    'interac',
    'Interac e-Transfer',
    'IN',
    0xFFFDB913,
    {'CA'},
    kinds: _phoneOrEmail,
    desc: _descBank,
    aliases: ['interac', 'e-transfer', 'etransfer'],
  ),
  PaymentMethodType(
    id: 'pix',
    displayName: 'Pix',
    initials: 'PX',
    brandColor: 0xFF32BCAD,
    handleKinds: const [HandleKind.pixKey],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: const {'BR'},
    currencies: const {'BRL'},
    aliases: const ['pix', 'chave pix'],
    launch: _pix,
    qr: _pixQr,
  ),
  _wallet(
    'spei',
    'SPEI (CLABE)',
    'SP',
    0xFF1F4E79,
    {'MX'},
    kinds: const [HandleKind.clabe, HandleKind.phone],
    desc: _descBank,
    aliases: ['spei', 'clabe', 'dimo'],
  ),
  _wallet(
    'mercado_pago',
    'Mercado Pago',
    'MP',
    0xFF00B1EA,
    {'AR', 'MX', 'CL', 'CO', 'PE', 'UY', 'BR'},
    kinds: const [HandleKind.accountDetails],
    desc: _descApp,
    aliases: ['mercado pago', 'mercadopago'],
  ),
  _wallet('nequi', 'Nequi', 'NQ', 0xFF200020, {'CO'}, aliases: ['nequi']),
  _wallet(
    'bre_b',
    'Bre-B',
    'BB',
    0xFF0B3D91,
    {'CO'},
    kinds: const [HandleKind.phoneOrEmail, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['bre-b', 'breb', 'llave'],
  ),
  _wallet('yape', 'Yape', 'YA', 0xFF742284, {'PE'}, aliases: ['yape']),
  _wallet('plin', 'Plin', 'PL', 0xFF00C1D4, {'PE'}, aliases: ['plin']),
  _wallet(
    'mach',
    'MACH',
    'MA',
    0xFF6E2CF4,
    {'CL'},
    desc: _descApp,
    aliases: ['mach'],
  ),

  // UK & Ireland -----------------------------------------------------------
  PaymentMethodType(
    id: 'monzo',
    displayName: 'Monzo',
    initials: 'MZ',
    brandColor: 0xFFFF4F40,
    handleKinds: const [HandleKind.username],
    capability: PaymentCapability.prefill,
    descriptionKey: _descApp,
    countries: const {'GB'},
    currencies: const {'GBP'},
    aliases: const ['monzo', 'monzo.me'],
    linkHosts: const ['monzo.me'],
    launch: _monzo,
  ),

  // Euro area ----------------------------------------------------------------
  PaymentMethodType(
    id: 'sepa_qr',
    displayName: 'SEPA transfer (EPC QR)',
    initials: 'EU',
    brandColor: 0xFF003399,
    handleKinds: const [HandleKind.iban],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: sepaEurCountries,
    currencies: const {'EUR'},
    aliases: const ['sepa', 'girocode', 'epc qr'],
    launch: _qrCopy(),
    qr: _epcQr,
  ),
  _wallet(
    'wero',
    'Wero',
    'WE',
    0xFF1D1D1B,
    {'DE', 'FR', 'BE', 'LU', 'NL'},
    kinds: _phoneOrEmail,
    desc: _descBank,
    aliases: ['wero', 'paylib'],
  ),
  _wallet(
    'lydia',
    'Lydia',
    'LY',
    0xFF0078FF,
    {'FR'},
    desc: _descApp,
    aliases: ['lydia'],
  ),
  _wallet(
    'payconiq',
    'Payconiq',
    'PQ',
    0xFFFF4785,
    {'BE', 'LU'},
    desc: _descApp,
    aliases: ['payconiq'],
  ),
  _wallet(
    'tikkie',
    'Tikkie',
    'TK',
    0xFF2B5EE8,
    {'NL'},
    kinds: const [HandleKind.url, HandleKind.iban],
    desc: _descApp,
    aliases: ['tikkie', 'ideal'],
  ),
  _wallet(
    'bizum',
    'Bizum',
    'BZ',
    0xFF05C3DD,
    {'ES'},
    desc: _descBank,
    aliases: ['bizum'],
  ),
  _wallet(
    'mb_way',
    'MB WAY',
    'MB',
    0xFFD8232A,
    {'PT'},
    desc: _descBank,
    aliases: ['mb way', 'mbway'],
  ),
  _wallet(
    'satispay',
    'Satispay',
    'SA',
    0xFFF94C43,
    {'IT'},
    desc: _descApp,
    aliases: ['satispay'],
  ),
  _wallet(
    'twint',
    'TWINT',
    'TW',
    0xFF000000,
    {'CH'},
    desc: _descApp,
    aliases: ['twint'],
  ),

  // Nordics ------------------------------------------------------------------
  PaymentMethodType(
    id: 'swish',
    displayName: 'Swish',
    initials: 'SW',
    brandColor: 0xFFEE2D24,
    handleKinds: _phone,
    capability: PaymentCapability.prefill,
    descriptionKey: _descApp,
    countries: const {'SE'},
    currencies: const {'SEK'},
    aliases: const ['swish'],
    launch: _swish,
  ),
  _wallet(
    'vipps',
    'Vipps',
    'VI',
    0xFFFF5B24,
    {'NO'},
    desc: _descApp,
    aliases: ['vipps'],
  ),
  _wallet(
    'mobilepay',
    'MobilePay',
    'MP',
    0xFF5A78FF,
    {'DK', 'FI'},
    desc: _descApp,
    aliases: ['mobilepay', 'mobile pay'],
  ),
  _wallet(
    'aur',
    'Aur',
    'AU',
    0xFF00C389,
    {'IS'},
    desc: _descApp,
    aliases: ['aur'],
  ),

  // Central & Eastern Europe -------------------------------------------------
  _wallet(
    'blik',
    'BLIK',
    'BL',
    0xFF000000,
    {'PL'},
    desc: _descBank,
    aliases: ['blik'],
  ),
  PaymentMethodType(
    id: 'cz_qr_platba',
    displayName: 'QR Platba',
    initials: 'QR',
    brandColor: 0xFF1B4F9C,
    handleKinds: const [HandleKind.iban],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: const {'CZ', 'SK'},
    currencies: const {'CZK', 'EUR'},
    aliases: const ['qr platba', 'spayd'],
    launch: _qrCopy(),
    qr: _spaydQr,
  ),
  _wallet(
    'tr_fast',
    'FAST / IBAN',
    'TR',
    0xFFE30A17,
    {'TR'},
    kinds: const [HandleKind.iban, HandleKind.phone],
    desc: _descBank,
    aliases: ['fast', 'havale'],
  ),
  _wallet(
    'papara',
    'Papara',
    'PA',
    0xFF000000,
    {'TR'},
    kinds: const [HandleKind.accountDetails],
    desc: _descApp,
    aliases: ['papara'],
  ),
  _wallet(
    'sbp',
    'SBP (Faster Payments)',
    'СБП',
    0xFF1D1346,
    {'RU'},
    desc: _descBank,
    aliases: ['sbp', 'сбп'],
  ),
  _wallet(
    'monobank',
    'monobank',
    'MO',
    0xFF000000,
    {'UA'},
    kinds: const [HandleKind.url, HandleKind.accountDetails],
    desc: _descApp,
    aliases: ['monobank', 'mono'],
  ),

  // Middle East & North Africa -----------------------------------------------
  PaymentMethodType(
    id: 'instapay',
    displayName: 'InstaPay',
    initials: 'IP',
    brandColor: 0xFF4A148C,
    logoAsset: 'assets/payments/instapay.png',
    handleKinds: const [HandleKind.url, HandleKind.accountDetails],
    capability: PaymentCapability.recipientOnly,
    descriptionKey: _descBank,
    countries: const {'EG'},
    aliases: const ['instapay', 'insta pay', 'ipa'],
  ),
  _wallet(
    'vodafone_cash',
    'Vodafone Cash',
    'VC',
    0xFFE60000,
    {'EG'},
    aliases: ['vodafone cash', 'vodafone', 'vf cash'],
  ),
  _wallet(
    'sarie',
    'Instant transfer (sarie)',
    'SR',
    0xFF00A651,
    {'SA'},
    kinds: const [HandleKind.phone, HandleKind.iban],
    desc: _descBank,
    aliases: ['sarie', 'saudi instant'],
  ),
  _wallet(
    'stc_bank',
    'STC Bank',
    'STC',
    0xFF4F008C,
    {'SA', 'BH', 'KW'},
    aliases: ['stc pay', 'stcpay', 'stc bank'],
  ),
  _wallet('urpay', 'urpay', 'UR', 0xFF00B2A9, {'SA'}, aliases: ['urpay']),
  _wallet(
    'aani',
    'Aani',
    'AA',
    0xFF00704A,
    {'AE'},
    kinds: const [HandleKind.phone, HandleKind.iban],
    desc: _descBank,
    aliases: ['aani'],
  ),
  _wallet(
    'careem_pay',
    'Careem Pay',
    'CP',
    0xFF00E784,
    {'AE', 'SA', 'JO', 'PK'},
    aliases: ['careem pay', 'careem'],
  ),
  _wallet(
    'wamd',
    'WAMD',
    'WA',
    0xFF00539B,
    {'KW'},
    desc: _descBank,
    aliases: ['wamd'],
  ),
  _wallet(
    'fawran',
    'Fawran',
    'FA',
    0xFF8A1538,
    {'QA'},
    desc: _descBank,
    aliases: ['fawran'],
  ),
  _wallet(
    'benefitpay',
    'BenefitPay',
    'BP',
    0xFFD71920,
    {'BH'},
    desc: _descBank,
    aliases: ['benefitpay', 'benefit pay', 'fawri'],
  ),
  _wallet(
    'cliq',
    'CliQ',
    'CQ',
    0xFF00A3E0,
    {'JO'},
    kinds: const [HandleKind.phone, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['cliq'],
  ),
  _wallet(
    'whish',
    'Whish Money',
    'WH',
    0xFFE4002B,
    {'LB'},
    aliases: ['whish', 'omt'],
  ),
  _wallet('d17', 'D17', 'D17', 0xFF0067B1, {'TN'}, aliases: ['d17', 'e-dinar']),
  _wallet(
    'baridimob',
    'BaridiMob',
    'BM',
    0xFFFFCC00,
    {'DZ'},
    kinds: const [HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['baridimob', 'ccp'],
  ),
  _wallet(
    'zaincash',
    'ZainCash',
    'ZC',
    0xFF000000,
    {'IQ'},
    aliases: ['zaincash', 'zain cash'],
  ),
  _wallet(
    'fib',
    'FIB',
    'FIB',
    0xFF00A19A,
    {'IQ'},
    desc: _descBank,
    aliases: ['fib', 'first iraqi bank'],
  ),

  // South Asia -----------------------------------------------------------------
  PaymentMethodType(
    id: 'upi',
    displayName: 'UPI',
    initials: 'UPI',
    brandColor: 0xFF097939,
    handleKinds: const [HandleKind.upiVpa],
    capability: PaymentCapability.prefill,
    descriptionKey: _descBank,
    countries: const {'IN'},
    currencies: const {'INR'},
    platforms: const {PaymentPlatform.android, PaymentPlatform.ios},
    aliases: const ['upi', 'gpay', 'google pay', 'phonepe', 'paytm', 'bhim'],
    launch: _upi,
    qr: _upiQr,
  ),
  _wallet(
    'raast',
    'Raast',
    'RA',
    0xFF00A859,
    {'PK'},
    kinds: const [HandleKind.phone, HandleKind.iban],
    desc: _descBank,
    aliases: ['raast'],
  ),
  _wallet(
    'jazzcash',
    'JazzCash',
    'JC',
    0xFFED1C24,
    {'PK'},
    aliases: ['jazzcash', 'jazz cash'],
  ),
  _wallet(
    'easypaisa',
    'Easypaisa',
    'EP',
    0xFF3BB54A,
    {'PK'},
    aliases: ['easypaisa', 'easy paisa'],
  ),
  _wallet('bkash', 'bKash', 'bK', 0xFFE2136E, {'BD'}, aliases: ['bkash']),
  _wallet('nagad', 'Nagad', 'NG', 0xFFF6921E, {'BD'}, aliases: ['nagad']),

  // East & South-East Asia -------------------------------------------------
  PaymentMethodType(
    id: 'promptpay',
    displayName: 'PromptPay',
    initials: 'PP',
    brandColor: 0xFF1A3C6E,
    handleKinds: const [HandleKind.promptPayId],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: const {'TH'},
    currencies: const {'THB'},
    aliases: const ['promptpay', 'prompt pay', 'พร้อมเพย์'],
    launch: _qrCopy(),
    qr: _promptPayQr,
  ),
  PaymentMethodType(
    id: 'paynow',
    displayName: 'PayNow',
    initials: 'PN',
    brandColor: 0xFF7C2A90,
    handleKinds: const [HandleKind.payNowProxy],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: const {'SG'},
    currencies: const {'SGD'},
    aliases: const ['paynow', 'pay now'],
    launch: _qrCopy(),
    qr: _payNowQr,
  ),
  _wallet(
    'duitnow',
    'DuitNow',
    'DN',
    0xFFED1C24,
    {'MY'},
    kinds: const [HandleKind.phone, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['duitnow', 'duit now'],
  ),
  _wallet(
    'tng',
    "Touch 'n Go eWallet",
    'TNG',
    0xFF005ABB,
    {'MY'},
    aliases: ['touch n go', "touch 'n go", 'tng'],
  ),
  _wallet(
    'gopay',
    'GoPay',
    'GP',
    0xFF00AED6,
    {'ID'},
    aliases: ['gopay', 'go pay'],
  ),
  _wallet('ovo', 'OVO', 'OVO', 0xFF4C3494, {'ID'}, aliases: ['ovo']),
  _wallet('dana', 'DANA', 'DA', 0xFF118EEA, {'ID'}, aliases: ['dana']),
  _wallet('gcash', 'GCash', 'GC', 0xFF007DFE, {'PH'}, aliases: ['gcash']),
  _wallet(
    'maya',
    'Maya',
    'MY',
    0xFF00D26A,
    {'PH'},
    aliases: ['maya', 'paymaya'],
  ),
  PaymentMethodType(
    id: 'vietqr',
    displayName: 'VietQR',
    initials: 'VQ',
    brandColor: 0xFF00539F,
    handleKinds: const [HandleKind.vietQrAccount],
    capability: PaymentCapability.qr,
    descriptionKey: _descQr,
    countries: const {'VN'},
    currencies: const {'VND'},
    aliases: const ['vietqr', 'napas'],
    launch: _qrCopy(),
    qr: _vietQr,
  ),
  _wallet('momo', 'MoMo', 'MM', 0xFFA50064, {'VN'}, aliases: ['momo']),
  _wallet(
    'paypay',
    'PayPay',
    'PP',
    0xFFFF0033,
    {'JP'},
    kinds: const [HandleKind.username, HandleKind.phone],
    desc: _descApp,
    aliases: ['paypay'],
  ),
  PaymentMethodType(
    id: 'toss',
    displayName: 'Toss',
    initials: 'TS',
    brandColor: 0xFF0064FF,
    handleKinds: const [HandleKind.username, HandleKind.accountDetails],
    capability: PaymentCapability.recipientOnly,
    descriptionKey: _descApp,
    countries: const {'KR'},
    aliases: const ['toss', 'toss.me'],
    linkHosts: const ['toss.me'],
    launch: _profileLink('https://toss.me'),
  ),
  _wallet(
    'kakaopay',
    'KakaoPay',
    'KP',
    0xFFFFEB00,
    {'KR'},
    kinds: const [HandleKind.accountDetails],
    desc: _descApp,
    aliases: ['kakaopay', 'kakao pay'],
  ),
  _wallet(
    'wechat_pay',
    'WeChat Pay',
    'WX',
    0xFF07C160,
    {'CN'},
    kinds: const [HandleKind.username, HandleKind.phone],
    desc: _descApp,
    aliases: ['wechat', 'wechat pay', '微信'],
  ),
  _wallet(
    'alipay',
    'Alipay',
    'AP',
    0xFF1677FF,
    {'CN', 'HK'},
    kinds: const [HandleKind.phoneOrEmail],
    desc: _descApp,
    aliases: ['alipay', '支付宝'],
  ),
  _wallet(
    'fps',
    'FPS',
    'FPS',
    0xFF0B4EA2,
    {'HK'},
    kinds: const [HandleKind.phoneOrEmail, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['fps', '轉數快'],
  ),
  _wallet(
    'payme',
    'PayMe',
    'PM',
    0xFFDB0011,
    {'HK'},
    kinds: const [HandleKind.url, HandleKind.username],
    desc: _descApp,
    aliases: ['payme'],
  ),
  _wallet(
    'line_pay',
    'LINE Pay',
    'LP',
    0xFF06C755,
    {'TW', 'TH'},
    kinds: const [HandleKind.username, HandleKind.phone],
    desc: _descApp,
    aliases: ['line pay', 'linepay'],
  ),
  _wallet(
    'jkopay',
    'JKOPAY',
    'JK',
    0xFFE60012,
    {'TW'},
    kinds: const [HandleKind.username, HandleKind.phone],
    desc: _descApp,
    aliases: ['jkopay', '街口'],
  ),

  // Oceania --------------------------------------------------------------------
  _wallet(
    'payid',
    'PayID (Osko)',
    'ID',
    0xFF00A6A6,
    {'AU'},
    kinds: const [HandleKind.phoneOrEmail, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['payid', 'osko'],
  ),

  // Africa ---------------------------------------------------------------------
  _wallet(
    'mpesa',
    'M-Pesa',
    'MP',
    0xFF4CAF50,
    {'KE', 'TZ'},
    aliases: ['m-pesa', 'mpesa', 'm pesa'],
  ),
  _wallet('opay', 'OPay', 'OP', 0xFF1DCF9F, {'NG'}, aliases: ['opay']),
  _wallet('palmpay', 'PalmPay', 'PP', 0xFF6C2BD9, {'NG'}, aliases: ['palmpay']),
  _wallet(
    'mtn_momo',
    'MTN MoMo',
    'MTN',
    0xFFFFCB05,
    {'GH', 'UG', 'RW', 'CI', 'CM', 'ZM'},
    aliases: ['mtn momo', 'momo mtn', 'mtn mobile money'],
  ),
  _wallet(
    'telecel_cash',
    'Telecel Cash',
    'TC',
    0xFFE4002B,
    {'GH'},
    aliases: ['telecel cash', 'vodafone cash ghana'],
  ),
  _wallet(
    'payshap',
    'PayShap',
    'PS',
    0xFF00A3AD,
    {'ZA'},
    kinds: const [HandleKind.phone, HandleKind.accountDetails],
    desc: _descBank,
    aliases: ['payshap', 'shapid'],
  ),
];

final Map<String, PaymentMethodType> _byId = {
  for (final t in paymentMethodRegistry) t.id: t,
};

/// The registry entry for [id], or null.
PaymentMethodType? paymentMethodById(String? id) =>
    id == null ? null : _byId[id.trim().toLowerCase()];

/// The catch-all "Other" method.
PaymentMethodType get otherPaymentMethod => _byId['other']!;
