import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/scan_receipt/scan_error_content.dart';
import 'package:split_bill_app/services/receipt_service.dart';

void main() {
  String text(ScanErrorContent c) => c.message((k) => k);

  group('scanErrorContentFor', () {
    test('422 not a receipt: refunded, retake / type it in', () {
      final c = scanErrorContentFor(classifyScanError(422, {}));
      expect(c.titleKey, 'bf_scan_err_not_receipt_title');
      expect(c.messageKeys, [
        'bf_scan_err_not_receipt_msg',
        'bf_scan_err_refunded',
      ]);
      expect(c.primary, ScanErrorAction.retakePhoto);
      expect(c.secondary, ScanErrorAction.typeItIn);
    });

    test('422 errorCode picks the specific reason', () {
      expect(
        scanErrorContentFor(
          classifyScanError(422, {'errorCode': 'too_dark'}),
        ).messageKeys.first,
        'bf_scan_err_too_dark',
      );
      expect(
        scanErrorContentFor(
          classifyScanError(422, {'error_code': 'BLURRY_IMAGE'}),
        ).messageKeys.first,
        'bf_scan_err_blurry',
      );
      expect(
        scanErrorContentFor(
          classifyScanError(422, {'errorCode': 'not_a_receipt'}),
        ).messageKeys.first,
        'bf_scan_err_not_a_receipt_msg',
      );
      expect(
        scanErrorContentFor(
          classifyScanError(422, {'errorCode': 'receipt_cut_off'}),
        ).messageKeys.first,
        'bf_scan_err_cut_off',
      );
    });

    test('413 and 415 have their own copy', () {
      final large = scanErrorContentFor(classifyScanError(413, {}));
      expect(large.titleKey, 'bf_scan_err_too_large_title');
      expect(large.messageKeys, ['bf_scan_err_too_large_msg']);
      final format = scanErrorContentFor(classifyScanError(415, {}));
      expect(format.titleKey, 'bf_scan_err_format_title');
      expect(format.primary, ScanErrorAction.choosePhoto);
    });

    test('refund sentence only when refunded', () {
      final notRefunded = scanErrorContentFor(classifyScanError(504, {}));
      expect(notRefunded.messageKeys, ['bf_scan_err_timeout_msg']);
      final refunded = scanErrorContentFor(
        classifyScanError(504, {'refunded': true}),
      );
      expect(text(refunded), 'bf_scan_err_timeout_msg bf_scan_err_refunded');
    });

    test('timeout, offline, rate limit, credits, unknown', () {
      final timeout = scanErrorContentFor(
        const ReceiptScanException(ReceiptScanFailure.timeout),
      );
      expect(timeout.titleKey, 'bf_scan_err_timeout_title');
      expect(timeout.primary, ScanErrorAction.tryAgain);

      final offline = scanErrorContentFor(
        const ReceiptScanException(ReceiptScanFailure.offline),
      );
      expect(offline.offline, isTrue);
      expect(offline.titleKey, 'feedback_offline_title');
      expect(offline.primary, ScanErrorAction.tryAgain);

      final rate = scanErrorContentFor(classifyScanError(429, {}));
      expect(rate.titleKey, 'bf_scan_err_rate_title');

      final credits = scanErrorContentFor(classifyScanError(402, {}));
      expect(credits.titleKey, 'bf_scan_err_credits_title');
      expect(credits.primary, ScanErrorAction.getCredits);

      final unknown = scanErrorContentFor(classifyScanError(500, {}));
      expect(unknown.titleKey, 'bf_scan_err_unknown_title');
      expect(unknown.secondary, ScanErrorAction.typeItIn);
    });

    test('every failure maps to keys, never raw server text', () {
      for (final f in ReceiptScanFailure.values) {
        final c = scanErrorContentFor(
          ReceiptScanException(f, serverMessage: 'Traceback: boom'),
        );
        expect(c.titleKey, isNot(contains('boom')));
        expect(text(c), isNot(contains('boom')));
        expect(c.messageKeys, isNotEmpty);
      }
    });

    test('non-typed errors become unknown', () {
      final c = scanErrorContentForError(Exception('socket closed 0x1f'));
      expect(c.titleKey, 'bf_scan_err_unknown_title');
      expect(text(c), isNot(contains('socket')));
    });
  });

  group('access problems', () {
    test('detects image_picker permission errors', () {
      expect(
        scanAccessProblemOf(PlatformException(code: 'camera_access_denied')),
        ScanAccessProblem.cameraDenied,
      );
      expect(
        scanAccessProblemOf(PlatformException(code: 'photo_access_denied')),
        ScanAccessProblem.photosDenied,
      );
      expect(scanAccessProblemOf(PlatformException(code: 'other')), isNull);
      expect(scanAccessProblemOf(Exception('x')), isNull);
    });

    test('camera off: Open Settings + Choose photo when supported', () {
      final c = scanAccessContentFor(
        ScanAccessProblem.cameraDenied,
        canOpenSettings: true,
      );
      expect(c.titleKey, 'bf_scan_err_camera_title');
      expect(c.primary, ScanErrorAction.openSettings);
      expect(c.secondary, ScanErrorAction.choosePhoto);

      final noSettings = scanAccessContentFor(
        ScanAccessProblem.cameraDenied,
        canOpenSettings: false,
      );
      expect(noSettings.primary, ScanErrorAction.choosePhoto);
      expect(noSettings.secondary, ScanErrorAction.typeItIn);
    });

    test('action labels', () {
      expect(
        scanErrorActionLabelKey(ScanErrorAction.retakePhoto),
        'bf_scan_retake',
      );
      expect(
        scanErrorActionLabelKey(ScanErrorAction.tryAgain),
        'feedback_try_again',
      );
    });
  });
}
