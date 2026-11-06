import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payment_models.dart';

/// The localized Messages note for Apple Cash ("Paying you EGP 16.38 for Sea
/// Breeze via Apple Cash"), so the prefill follows the payer's language
/// instead of the English default inside the link builder.
String applePaymentMessage({required String displayAmount, String? note}) {
  final n = note?.trim() ?? '';
  if (n.isEmpty) {
    return 'payment_apple_cash_message_plain'.tr(
      namedArgs: {'amount': displayAmount},
    );
  }
  return 'payment_apple_cash_message'.tr(
    namedArgs: {'amount': displayAmount, 'bill': n},
  );
}

/// A [PaymentRequest] carrying the localized [PaymentRequest.message].
PaymentRequest localizedPaymentRequest({
  required String handle,
  Money? amount,
  String? note,
  String? recipientName,
}) {
  final base = PaymentRequest(
    handle: handle,
    amount: amount,
    note: note,
    recipientName: recipientName,
  );
  return PaymentRequest(
    handle: handle,
    amount: amount,
    note: note,
    recipientName: recipientName,
    message: applePaymentMessage(displayAmount: base.displayAmount, note: note),
  );
}
