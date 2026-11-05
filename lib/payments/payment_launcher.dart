/// Runs a [PaymentLaunch] on the device: open the app link, else the web
/// fallback, else copy. The only Flutter-dependent file in lib/payments.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'payment_models.dart';

/// What actually happened, so the screen can show the right snackbar.
enum PaymentLaunchOutcome {
  /// Provider opened with the amount filled in.
  openedPrefilled,

  /// Provider opened; the amount is on the clipboard for the payer to paste.
  openedAmountCopied,

  /// Handle/code copied (and the provider's app/site opened if it has one).
  copied,

  /// Nothing could be opened or copied.
  failed,
}

/// The current platform for [PaymentMethodType.isAvailableOn].
PaymentPlatform currentPaymentPlatform() {
  if (kIsWeb) return PaymentPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => PaymentPlatform.ios,
    TargetPlatform.macOS => PaymentPlatform.macos,
    TargetPlatform.windows => PaymentPlatform.windows,
    TargetPlatform.linux => PaymentPlatform.linux,
    _ => PaymentPlatform.android,
  };
}

/// Executes payment launches. The hooks exist for tests.
class PaymentLauncher {
  const PaymentLauncher({
    Future<bool> Function(Uri uri)? canOpen,
    Future<bool> Function(Uri uri)? open,
    Future<void> Function(String text)? copy,
  }) : _canOpen = canOpen ?? canLaunchUrl,
       _open = open ?? _openExternal,
       _copy = copy ?? _copyToClipboard;

  final Future<bool> Function(Uri uri) _canOpen;
  final Future<bool> Function(Uri uri) _open;
  final Future<void> Function(String text) _copy;

  static Future<bool> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  static Future<void> _copyToClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<bool> _tryOpen(Uri uri) async {
    try {
      // https links always open (browser at worst); app schemes need canOpen,
      // which relies on LSApplicationQueriesSchemes / Android <queries>.
      final isWeb = uri.scheme == 'https' || uri.scheme == 'http';
      if (!isWeb && !await _canOpen(uri)) return false;
      return await _open(uri);
    } on PlatformException {
      return false;
    }
  }

  /// Runs [launch] and reports what happened.
  Future<PaymentLaunchOutcome> run(PaymentLaunch launch) async {
    switch (launch) {
      case DeepLinkLaunch():
        final targets = [launch.uri, ?launch.webFallback];
        final amountText = launch.clipboardText;
        if (amountText != null && !launch.prefillsAmount) {
          await _copy(amountText);
        }
        for (final uri in targets) {
          if (await _tryOpen(uri)) {
            return launch.prefillsAmount
                ? PaymentLaunchOutcome.openedPrefilled
                : PaymentLaunchOutcome.openedAmountCopied;
          }
        }
        return run(launch.fallback);
      case CopyInstruction():
        try {
          await _copy(launch.text);
        } on PlatformException {
          return PaymentLaunchOutcome.failed;
        }
        final openUri = launch.openUri;
        if (openUri != null) await _tryOpen(openUri);
        return PaymentLaunchOutcome.copied;
    }
  }
}
