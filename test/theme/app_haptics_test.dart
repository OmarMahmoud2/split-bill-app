import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method.startsWith('HapticFeedback')) calls.add(call);
          return null;
        });
  });

  tearDown(() {
    AppHaptics.enabled = true;
    AppHaptics.debugIsWebOverride = null;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> fireAll() async {
    await AppHaptics.light();
    await AppHaptics.selection();
    await AppHaptics.success();
    await AppHaptics.warning();
    await AppHaptics.error();
  }

  test('iOS maps each semantic haptic to HapticFeedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await fireAll();
    expect(calls.map((c) => c.arguments).toList(), [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('Android error uses vibrate', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await AppHaptics.error();
    expect(calls.single.method, 'HapticFeedback.vibrate');
  });

  test('no-op when disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppHaptics.enabled = false;
    await fireAll();
    expect(calls, isEmpty);
  });

  test('no-op on web', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AppHaptics.debugIsWebOverride = true;
    await fireAll();
    expect(calls, isEmpty);
  });

  test('AppSettingsProvider.hapticsEnabled defaults on, persists, and '
      'drives AppHaptics', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsProvider();
    expect(settings.hapticsEnabled, isTrue);

    await settings.updateHapticsEnabled(false);
    expect(settings.hapticsEnabled, isFalse);
    expect(AppHaptics.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hapticsEnabledPreferenceKey), isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await AppHaptics.success();
    expect(calls, isEmpty);
    settings.dispose();
  });
}
