import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/config/app_links.dart' as links;
import 'package:split_bill_app/main.dart';

void main() {
  testWidgets('startup error shows support email and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      FirebaseStartupErrorApp(
        error: StateError('boom'),
        onRetry: () async {
          retries++;
          return StateError('still down');
        },
      ),
    );
    // Translations are not loaded in this test: the English fallback shows.
    expect(find.text('We could not start Evens'), findsOneWidget);
    expect(find.text(links.AppLinks.supportEmail), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(retries, 1);
    // Still failing: the screen stays and the button is back.
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('no retry button without a retry callback', (tester) async {
    await tester.pumpWidget(FirebaseStartupErrorApp(error: StateError('x')));
    expect(find.text('Try again'), findsNothing);
  });
}
