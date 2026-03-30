import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:split_bill_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // This allows the test to run even if there are infinite animations (like your gradient and particles)
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Automated Screenshot Capture', (WidgetTester tester) async {
    // 1. Launch the app
    app.main();
    
    // 2. Wait for Splash Screen & initial loading to finish
    await tester.pump(const Duration(seconds: 3));

    // 3. Find Onboarding PageView and take screenshots of the beautifully animated screens
    final pageView = find.byType(PageView);
    
    if (pageView.evaluate().isNotEmpty) {
      // Page 1
      await binding.takeScreenshot('01_Onboarding_Welcome');
      
      // Swipe to Page 2
      await tester.drag(pageView, const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600)); // wait for transition
      await binding.takeScreenshot('02_Onboarding_Split');
      
      // Swipe to Page 3
      await tester.drag(pageView, const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await binding.takeScreenshot('03_Onboarding_Track');

      // Swipe to Page 4
      await tester.drag(pageView, const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 600));

      // Locate the Skip button (TextButton)
      final textButtons = find.byType(TextButton);
      if (textButtons.evaluate().isNotEmpty) {
        // Tap Skip to transition to Login Screen
        await tester.tap(textButtons.first);
        await tester.pump(const Duration(seconds: 2)); // wait for fade transition
        
        // Screenshot Login Screen
        await binding.takeScreenshot('04_Login_Screen');
      }
    } else {
      // If we are already logged in or on another screen
      await binding.takeScreenshot('01_App_Screen');
      
      // Example of interacting with HomeScreen if user was logged in:
      // final fab = find.byType(FloatingActionButton);
      // if (fab.evaluate().isNotEmpty) {
      //   await tester.tap(fab);
      //   await tester.pump(const Duration(seconds: 1));
      //   await binding.takeScreenshot('02_Add_Bill_Actions');
      // }
    }
  });
}
