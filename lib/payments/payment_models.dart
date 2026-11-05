/// Value types shared by the payment-method registry. Pure Dart.
library;

import '../domain/money.dart';
import 'bank_formats.dart';
import 'emv_qr.dart';

/// Platforms a method can be offered on.
enum PaymentPlatform { android, ios, macos, web, windows, linux }

/// What a method's link can do for the payer (used in docs and UI badges).
enum PaymentCapability {
  /// Opens the provider with recipient and amount filled in.
  prefill,

  /// Opens the provider on the recipient; payer types the amount.
  recipientOnly,

  /// No public link: copy the handle and open the app by hand.
  copy,

  /// A scannable QR / copy-paste code carries recipient and amount.
  qr,
}

/// The kind of identifier a recipient stores for a method.
enum HandleKind {
  username,
  cashtag,
  phone,
  email,
  phoneOrEmail,
  iban,
  upiVpa,
  pixKey,
  promptPayId,
  payNowProxy,
  clabe,
  vietQrAccount,
  url,
  accountDetails,
}

final _username = RegExp(r'^@?[A-Za-z0-9][A-Za-z0-9._\-]{1,39}$');
final _cashtag = RegExp(r'^\$?(?=[A-Za-z0-9_]*[A-Za-z])[A-Za-z0-9_]{1,20}$');
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _phoneChars = RegExp(r'^\+?[0-9][0-9 ()\-.]{4,22}$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _uen = RegExp(r'^(\d{8,9}[A-Z]|[TSR]\d{2}[A-Z]{2}\d{4}[A-Z])$');
final _sgMobile = RegExp(r'^(\+?65)?[89]\d{7}$');
final _vietQr = RegExp(r'^(\d{6})[\s:/|\-]+([0-9A-Za-z]{4,19})$');

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Validation and normalisation per [HandleKind].
extension HandleKindRules on HandleKind {
  /// Translation key for the field label.
  String get labelKey => switch (this) {
    HandleKind.username => 'payment_handle_username',
    HandleKind.cashtag => 'payment_handle_cashtag',
    HandleKind.phone => 'payment_handle_phone',
    HandleKind.email => 'payment_handle_email',
    HandleKind.phoneOrEmail => 'payment_handle_phone_or_email',
    HandleKind.iban => 'payment_handle_iban',
    HandleKind.upiVpa => 'payment_handle_upi',
    HandleKind.pixKey => 'payment_handle_pix',
    HandleKind.promptPayId => 'payment_handle_promptpay',
    HandleKind.payNowProxy => 'payment_handle_paynow',
    HandleKind.clabe => 'payment_handle_clabe',
    HandleKind.vietQrAccount => 'payment_handle_vietqr',
    HandleKind.url => 'payment_handle_link',
    HandleKind.accountDetails => 'payment_handle_account_details',
  };

  /// True when [raw] is acceptable for this kind.
  bool validate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return false;
    switch (this) {
      case HandleKind.username:
        return _username.hasMatch(v);
      case HandleKind.cashtag:
        return _cashtag.hasMatch(v);
      case HandleKind.phone:
        final d = _digits(v);
        return _phoneChars.hasMatch(v) && d.length >= 6 && d.length <= 15;
      case HandleKind.email:
        return _email.hasMatch(v);
      case HandleKind.phoneOrEmail:
        return HandleKind.phone.validate(v) || HandleKind.email.validate(v);
      case HandleKind.iban:
        return isValidIban(v);
      case HandleKind.upiVpa:
        return upiVpaPattern.hasMatch(v);
      case HandleKind.pixKey:
        return isValidPixKey(v);
      case HandleKind.promptPayId:
        return RegExp(r'^[0-9 \-+]+$').hasMatch(v) &&
            promptPayProxyFor(v) != null;
      case HandleKind.payNowProxy:
        final c = v.replaceAll(RegExp(r'[\s-]'), '');
        return _sgMobile.hasMatch(c) || _uen.hasMatch(c.toUpperCase());
      case HandleKind.clabe:
        return isValidClabe(v);
      case HandleKind.vietQrAccount:
        return _vietQr.hasMatch(v);
      case HandleKind.url:
        final uri = Uri.tryParse(v);
        return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.contains('.');
      case HandleKind.accountDetails:
        return v.length <= 500;
    }
  }

  /// Canonical form used in links and copies.
  String normalize(String raw) {
    final v = raw.trim();
    switch (this) {
      case HandleKind.username:
        return v.startsWith('@') ? v.substring(1) : v;
      case HandleKind.cashtag:
        return v.startsWith(r'$') ? v : '\$$v';
      case HandleKind.phone:
        final plus = v.startsWith('+') ? '+' : '';
        return '$plus${_digits(v)}';
      case HandleKind.email:
        return v.toLowerCase();
      case HandleKind.phoneOrEmail:
        return HandleKind.email.validate(v)
            ? HandleKind.email.normalize(v)
            : HandleKind.phone.normalize(v);
      case HandleKind.iban:
        return compactIban(v);
      case HandleKind.clabe:
        return _digits(v);
      case HandleKind.promptPayId:
        return _digits(v);
      case HandleKind.payNowProxy:
        return v.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
      case HandleKind.pixKey:
        return normalizePixKey(v);
      case HandleKind.upiVpa:
      case HandleKind.vietQrAccount:
      case HandleKind.url:
      case HandleKind.accountDetails:
        return v;
    }
  }
}

/// Pix keys: CPF (11 digits), CNPJ (14), email, phone (+55...) or random
/// EVP key (UUID).
bool isValidPixKey(String raw) {
  final v = raw.trim();
  if (_email.hasMatch(v) || _uuid.hasMatch(v)) return true;
  if (v.startsWith('+')) {
    return RegExp(r'^\+55\d{10,11}$').hasMatch('+${_digits(v)}');
  }
  final d = _digits(v);
  if (!RegExp(r'^[0-9.\-/ ]+$').hasMatch(v)) return false;
  return d.length == 11 || d.length == 14;
}

/// Canonical Pix key: lower-case email/UUID, +55 phone, bare CPF/CNPJ digits.
String normalizePixKey(String raw) {
  final v = raw.trim();
  if (_email.hasMatch(v) || _uuid.hasMatch(v)) return v.toLowerCase();
  if (v.startsWith('+')) return '+${_digits(v)}';
  return _digits(v);
}

/// Splits a VietQR handle "970436 0123456789" into (bin, account).
(String, String)? parseVietQrAccount(String raw) {
  final m = _vietQr.firstMatch(raw.trim());
  if (m == null) return null;
  return (m.group(1)!, m.group(2)!);
}

/// Everything a link builder needs to know about one payment.
class PaymentRequest {
  const PaymentRequest({
    required this.handle,
    this.amount,
    this.note,
    this.recipientName,
    this.message,
  });

  /// The recipient's stored handle (username, phone, IBAN...), raw.
  final String handle;

  /// What the payer owes; null for an open amount.
  final Money? amount;

  /// Short reference such as the bill or restaurant name.
  final String? note;

  /// Recipient's display name (needed by QR standards that carry a name).
  final String? recipientName;

  /// A ready, localized message (e.g. for Apple Cash in Messages). When
  /// null, an English default is built from [amount] and [note].
  final String? message;

  /// Major-unit amount with the currency's decimals ("16.38", "1200").
  String? get amountString {
    final a = amount;
    if (a == null || a.minor <= 0) return null;
    final decimals = currencyDecimals(a.currency);
    if (decimals == 0) return a.minor.toString();
    final abs = a.minor.toString().padLeft(decimals + 1, '0');
    return '${abs.substring(0, abs.length - decimals)}.'
        '${abs.substring(abs.length - decimals)}';
  }

  /// "EGP 16.38", or empty when there is no amount.
  String get displayAmount {
    final s = amountString;
    return s == null ? '' : '${amount!.currency} $s';
  }

  String? get currency => amount?.currency;
}

/// What the UI should do when the payer taps a method.
sealed class PaymentLaunch {
  const PaymentLaunch({
    required this.instructionKey,
    this.instructionArgs = const {},
  });

  /// Translation key describing what happens (see assets/translations).
  final String instructionKey;

  /// Named arguments for [instructionKey] (app, amount, handle).
  final Map<String, String> instructionArgs;
}

/// Open [uri] (app deep link or universal link), else [webFallback], else
/// fall back to [fallback] (copy).
final class DeepLinkLaunch extends PaymentLaunch {
  const DeepLinkLaunch({
    required this.uri,
    required this.fallback,
    required this.prefillsAmount,
    this.webFallback,
    this.clipboardText,
    required super.instructionKey,
    super.instructionArgs,
  });

  final Uri uri;
  final Uri? webFallback;

  /// Whether the provider receives the amount through the link.
  final bool prefillsAmount;

  /// Copy this before launching (the amount, when the link can't carry it).
  final String? clipboardText;

  /// Used when neither [uri] nor [webFallback] can be opened.
  final CopyInstruction fallback;
}

/// Copy [text] and, optionally, open [openUri] (the provider's app or site).
final class CopyInstruction extends PaymentLaunch {
  const CopyInstruction({
    required this.text,
    this.openUri,
    required super.instructionKey,
    super.instructionArgs,
  });

  final String text;
  final Uri? openUri;
}
