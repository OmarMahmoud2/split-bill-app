import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';

class _Device {
  _Device({this.installed = const {}, this.openFails = const {}});

  final Set<String> installed;
  final Set<String> openFails;
  final opened = <String>[];
  final copied = <String>[];

  PaymentLauncher get launcher => PaymentLauncher(
    canOpen: (uri) async => installed.contains(uri.scheme),
    open: (uri) async {
      if (openFails.contains(uri.scheme)) return false;
      opened.add(uri.toString());
      return true;
    },
    copy: (text) async => copied.add(text),
  );
}

PaymentLaunch _launch(String id, String handle, int minor, String cur) =>
    paymentMethodById(
      id,
    )!.buildLaunch(PaymentRequest(handle: handle, amount: Money(minor, cur)));

void main() {
  test('opens the app when installed', () async {
    final d = _Device(installed: {'venmo'});
    final outcome = await d.launcher.run(_launch('venmo', 'omar', 500, 'USD'));
    expect(outcome, PaymentLaunchOutcome.openedPrefilled);
    expect(d.opened.single, startsWith('venmo://'));
    expect(d.copied, isEmpty);
  });

  test('uses the web fallback when the app is missing', () async {
    final d = _Device();
    final outcome = await d.launcher.run(_launch('venmo', 'omar', 500, 'USD'));
    expect(outcome, PaymentLaunchOutcome.openedPrefilled);
    expect(d.opened.single, startsWith('https://venmo.com/'));
  });

  test('recipient-only links copy the amount first', () async {
    final d = _Device();
    final outcome = await d.launcher.run(
      _launch('revolut', 'omar', 990, 'EUR'),
    );
    expect(outcome, PaymentLaunchOutcome.openedAmountCopied);
    expect(d.copied, ['9.90']);
  });

  test('falls back to copying when nothing opens', () async {
    final d = _Device(openFails: {'swish'});
    final outcome = await d.launcher.run(
      _launch('swish', '0701234567', 1000, 'SEK'),
    );
    expect(outcome, PaymentLaunchOutcome.copied);
    expect(d.copied, ['0701234567']);
  });

  test('copy instructions copy and open the provider site', () async {
    final d = _Device();
    final outcome = await d.launcher.run(
      _launch('wise', 'omar@example.com', 100, 'GBP'),
    );
    expect(outcome, PaymentLaunchOutcome.copied);
    expect(d.copied, ['omar@example.com']);
    expect(d.opened, ['https://wise.com/send']);
  });
}
