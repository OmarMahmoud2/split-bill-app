/// Maps scan failures to friendly, actionable error copy.
///
/// Pure: returns translation keys, never exception text, so it can be unit
/// tested and the UI can never leak `e.toString()`.
library;

import 'package:flutter/services.dart';
import 'package:split_bill_app/services/receipt_service.dart';

/// What a button on a scan error card does.
enum ScanErrorAction {
  /// Take a new photo with the camera.
  retakePhoto,

  /// Pick a photo from the library.
  choosePhoto,

  /// Open manual entry.
  typeItIn,

  /// Send the same photo again (new request id).
  tryAgain,

  /// Open the app's page in system Settings.
  openSettings,

  /// Show the points / premium sheet.
  getCredits,
}

/// Why a scan could not even start (permissions).
enum ScanAccessProblem { cameraDenied, photosDenied }

class ScanErrorContent {
  const ScanErrorContent({
    required this.titleKey,
    required this.messageKeys,
    required this.primary,
    this.secondary,
    this.offline = false,
  });

  final String titleKey;

  /// Sentences shown in order, joined with a space.
  final List<String> messageKeys;
  final ScanErrorAction primary;
  final ScanErrorAction? secondary;

  /// Render with the shared offline preset.
  final bool offline;

  /// Translated message, using [translate] for each key.
  String message(String Function(String key) translate) =>
      messageKeys.map(translate).join(' ');

  @override
  String toString() =>
      'ScanErrorContent($titleKey, $messageKeys, $primary, $secondary)';
}

/// Translation key for an [action]'s button label.
String scanErrorActionLabelKey(ScanErrorAction action) => switch (action) {
  ScanErrorAction.retakePhoto => 'bf_scan_retake',
  ScanErrorAction.choosePhoto => 'bf_scan_choose_photo',
  ScanErrorAction.typeItIn => 'bf_scan_type_it_in',
  ScanErrorAction.tryAgain => 'feedback_try_again',
  ScanErrorAction.openSettings => 'bf_scan_open_settings',
  ScanErrorAction.getCredits => 'bf_scan_get_credits',
};

/// The sentence explaining a 422 rejection, from the backend `errorCode`.
String _notAReceiptReasonKey(String? errorCode) {
  final code = (errorCode ?? '').toLowerCase();
  if (code.contains('dark')) return 'bf_scan_err_too_dark';
  if (code.contains('blur')) return 'bf_scan_err_blurry';
  if (code.contains('cut') || code.contains('partial')) {
    return 'bf_scan_err_cut_off';
  }
  if (code.contains('not_a_receipt') ||
      code.contains('not_receipt') ||
      code.contains('no_receipt')) {
    return 'bf_scan_err_not_a_receipt_msg';
  }
  return 'bf_scan_err_not_receipt_msg';
}

/// Copy and next steps for a typed scan failure.
ScanErrorContent scanErrorContentFor(ReceiptScanException e) {
  final refund = e.refunded ? const ['bf_scan_err_refunded'] : const <String>[];
  switch (e.failure) {
    case ReceiptScanFailure.notAReceipt:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_not_receipt_title',
        messageKeys: [_notAReceiptReasonKey(e.errorCode), ...refund],
        primary: ScanErrorAction.retakePhoto,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.tooLarge:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_too_large_title',
        messageKeys: ['bf_scan_err_too_large_msg', ...refund],
        primary: ScanErrorAction.retakePhoto,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.unsupportedFormat:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_format_title',
        messageKeys: ['bf_scan_err_format_msg', ...refund],
        primary: ScanErrorAction.choosePhoto,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.timeout:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_timeout_title',
        messageKeys: ['bf_scan_err_timeout_msg', ...refund],
        primary: ScanErrorAction.tryAgain,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.offline:
      return const ScanErrorContent(
        titleKey: 'feedback_offline_title',
        messageKeys: ['bf_scan_err_offline_msg'],
        primary: ScanErrorAction.tryAgain,
        secondary: ScanErrorAction.typeItIn,
        offline: true,
      );
    case ReceiptScanFailure.noCredits:
      return const ScanErrorContent(
        titleKey: 'bf_scan_err_credits_title',
        messageKeys: ['bf_scan_err_credits_msg'],
        primary: ScanErrorAction.getCredits,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.rateLimited:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_rate_title',
        messageKeys: ['bf_scan_err_rate_msg', ...refund],
        primary: ScanErrorAction.tryAgain,
        secondary: ScanErrorAction.typeItIn,
      );
    case ReceiptScanFailure.unknown:
      return ScanErrorContent(
        titleKey: 'bf_scan_err_unknown_title',
        messageKeys: ['bf_scan_err_unknown_msg', ...refund],
        primary: ScanErrorAction.tryAgain,
        secondary: ScanErrorAction.typeItIn,
      );
  }
}

/// Copy for any error thrown while scanning: typed failures map through
/// [scanErrorContentFor], anything else is treated as unknown.
ScanErrorContent scanErrorContentForError(Object error) {
  if (error is ReceiptScanException) return scanErrorContentFor(error);
  return scanErrorContentFor(
    const ReceiptScanException(ReceiptScanFailure.unknown),
  );
}

/// Detects image_picker's permission errors
/// (`camera_access_denied` / `photo_access_denied`).
ScanAccessProblem? scanAccessProblemOf(Object error) {
  if (error is! PlatformException) return null;
  final code = error.code.toLowerCase();
  if (code.contains('camera') && code.contains('denied')) {
    return ScanAccessProblem.cameraDenied;
  }
  if (code.contains('photo') && code.contains('denied')) {
    return ScanAccessProblem.photosDenied;
  }
  return null;
}

/// Copy for a permission problem. Without [canOpenSettings] (platforms where
/// we cannot deep-link to Settings) the other source becomes the only button.
ScanErrorContent scanAccessContentFor(
  ScanAccessProblem problem, {
  required bool canOpenSettings,
}) {
  final camera = problem == ScanAccessProblem.cameraDenied;
  final other = camera
      ? ScanErrorAction.choosePhoto
      : ScanErrorAction.retakePhoto;
  return ScanErrorContent(
    titleKey: camera ? 'bf_scan_err_camera_title' : 'bf_scan_err_photos_title',
    messageKeys: [camera ? 'bf_scan_err_camera_msg' : 'bf_scan_err_photos_msg'],
    primary: canOpenSettings ? ScanErrorAction.openSettings : other,
    secondary: canOpenSettings ? other : ScanErrorAction.typeItIn,
  );
}
