import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Public-repo-safe Firebase options loader.
///
/// Mobile and macOS builds should rely on local native config files:
/// - android/app/google-services.json
/// - ios/Runner/GoogleService-Info.plist
/// - macos/Runner/GoogleService-Info.plist
///
/// Web and Windows can be configured with dart-defines when needed.
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatformOrNull {
    if (kIsWeb) {
      return _webOptionsOrNull;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return _windowsOptionsOrNull;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return null;
      default:
        return null;
    }
  }

  static FirebaseOptions get currentPlatform {
    final options = currentPlatformOrNull;
    if (options == null) {
      throw UnsupportedError(
        'Firebase options are not configured for this platform. '
        'Use native Firebase config files on mobile/macOS or pass the '
        'required web/windows dart-defines.',
      );
    }
    return options;
  }

  static bool get shouldUseExplicitOptions => currentPlatformOrNull != null;

  static FirebaseOptions? get _webOptionsOrNull {
    if (_webApiKey.isEmpty ||
        _webAppId.isEmpty ||
        _webMessagingSenderId.isEmpty ||
        _webProjectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: _webApiKey,
      appId: _webAppId,
      messagingSenderId: _webMessagingSenderId,
      projectId: _webProjectId,
      authDomain: _webAuthDomain.isEmpty ? null : _webAuthDomain,
      storageBucket: _webStorageBucket.isEmpty ? null : _webStorageBucket,
      measurementId: _webMeasurementId.isEmpty ? null : _webMeasurementId,
    );
  }

  static FirebaseOptions? get _windowsOptionsOrNull {
    if (_windowsApiKey.isEmpty ||
        _windowsAppId.isEmpty ||
        _windowsMessagingSenderId.isEmpty ||
        _windowsProjectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: _windowsApiKey,
      appId: _windowsAppId,
      messagingSenderId: _windowsMessagingSenderId,
      projectId: _windowsProjectId,
      authDomain:
          _windowsAuthDomain.isEmpty ? null : _windowsAuthDomain,
      storageBucket:
          _windowsStorageBucket.isEmpty ? null : _windowsStorageBucket,
      measurementId:
          _windowsMeasurementId.isEmpty ? null : _windowsMeasurementId,
    );
  }

  static const String _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );
  static const String _webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '',
  );
  static const String _webMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String _webProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: '',
  );
  static const String _webAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String _webStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String _webMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
    defaultValue: '',
  );

  static const String _windowsApiKey = String.fromEnvironment(
    'FIREBASE_WINDOWS_API_KEY',
    defaultValue: '',
  );
  static const String _windowsAppId = String.fromEnvironment(
    'FIREBASE_WINDOWS_APP_ID',
    defaultValue: '',
  );
  static const String _windowsMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WINDOWS_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String _windowsProjectId = String.fromEnvironment(
    'FIREBASE_WINDOWS_PROJECT_ID',
    defaultValue: '',
  );
  static const String _windowsAuthDomain = String.fromEnvironment(
    'FIREBASE_WINDOWS_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String _windowsStorageBucket = String.fromEnvironment(
    'FIREBASE_WINDOWS_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String _windowsMeasurementId = String.fromEnvironment(
    'FIREBASE_WINDOWS_MEASUREMENT_ID',
    defaultValue: '',
  );
}
