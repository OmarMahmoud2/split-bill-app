/// Payment methods for settling up: registry, country ordering, link and QR
/// builders, legacy storage adapter and the device launcher.
///
/// Typical screen use:
/// ```dart
/// final methods = parseStoredPaymentMethods(hostProfile);
/// final launch = methods.first.type.buildLaunch(PaymentRequest(
///   handle: methods.first.value,
///   amount: Money(1638, 'EGP'),
///   note: 'Sea Breeze Grill',
/// ));
/// final outcome = await const PaymentLauncher().run(launch);
/// ```
library;

export 'bank_formats.dart';
export 'country_methods.dart';
export 'emv_qr.dart';
export 'legacy_payment_adapter.dart';
export 'payment_launcher.dart';
export 'payment_method_type.dart';
export 'payment_models.dart';
export 'payment_message.dart';
