import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic haptics mapped onto [HapticFeedback] for iOS and Android.
///
/// | call        | iOS / Android                                    | use for |
/// |-------------|--------------------------------------------------|---------|
/// | [light]     | lightImpact                                      | taps on important controls |
/// | [selection] | selectionClick                                   | avatar hop, picker ticks, toggles |
/// | [tick]      | selectionClick                                   | roulette slice passing the pointer |
/// | [heavy]     | heavyImpact                                      | roulette landing |
/// | [success]   | mediumImpact                                     | bill saved, balance settled |
/// | [warning]   | heavyImpact                                      | destructive confirm, limits |
/// | [error]     | heavyImpact (iOS) / vibrate (Android)            | failed action |
///
/// No-op on web, on desktop, and when the user turned haptics off
/// ([enabled], which `AppSettingsProvider.hapticsEnabled` keeps in sync).
/// Haptics also stay on under Reduce Motion, per the motion spec.
class AppHaptics {
  AppHaptics._();

  /// Mirrors the user setting; `AppSettingsProvider` writes it.
  static bool enabled = true;

  /// Test hook: overrides the web check.
  @visibleForTesting
  static bool? debugIsWebOverride;

  static bool get _isWeb => debugIsWebOverride ?? kIsWeb;

  static bool get _supported {
    if (!enabled || _isWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> light() async {
    if (_supported) await HapticFeedback.lightImpact();
  }

  static Future<void> selection() async {
    if (_supported) await HapticFeedback.selectionClick();
  }

  /// One tick of a spinning wheel or slider.
  static Future<void> tick() async {
    if (_supported) await HapticFeedback.selectionClick();
  }

  /// A heavy thud, e.g. the roulette landing on a person.
  static Future<void> heavy() async {
    if (_supported) await HapticFeedback.heavyImpact();
  }

  static Future<void> success() async {
    if (_supported) await HapticFeedback.mediumImpact();
  }

  static Future<void> warning() async {
    if (_supported) await HapticFeedback.heavyImpact();
  }

  static Future<void> error() async {
    if (!_supported) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await HapticFeedback.vibrate();
    } else {
      await HapticFeedback.heavyImpact();
    }
  }
}
