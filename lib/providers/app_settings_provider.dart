import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:ui';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/services/notification_payload.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';
import 'package:split_bill_app/services/guest_session.dart';
import 'package:split_bill_app/theme/app_haptics.dart';

/// shared_preferences key for the device-local appearance setting.
const String themeModePreferenceKey = 'themeMode';

/// shared_preferences key for the device-local haptics setting.
const String hapticsEnabledPreferenceKey = 'hapticsEnabled';

/// Parses a persisted [ThemeMode] name; unknown or missing -> system.
ThemeMode themeModeFromName(String? name) => ThemeMode.values.firstWhere(
  (mode) => mode.name == name,
  orElse: () => ThemeMode.system,
);

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({UserPreferencesService? preferencesService})
    : _preferencesService = preferencesService ?? UserPreferencesService();

  final UserPreferencesService _preferencesService;

  Locale _locale = resolveSupportedLocale(PlatformDispatcher.instance.locales);
  String _currencyCode = UserPreferencesService.defaultCurrencyCode;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticsEnabled = true;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  bool _initialized = false;

  Locale get locale => _locale;
  String get currencyCode => _currencyCode;
  ThemeMode get themeMode => _themeMode;

  /// Whether [AppHaptics] fires. Device-local, defaults to on.
  bool get hapticsEnabled => _hapticsEnabled;

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Property values only (language code, theme name); de-duplicated.
    AnalyticsService.instance
      ..setAppLocale(_locale.languageCode)
      ..setThemeMode(_themeMode.name);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadLocalPreferences();
    await _bindUser(memberOrNull(FirebaseAuth.instance.currentUser));
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _bindUser(memberOrNull(user)),
    );
  }

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocaleCode = prefs.getString('localeCode');
    _locale = savedLocaleCode == null
        ? resolveSupportedLocale(PlatformDispatcher.instance.locales)
        : findLocaleOption(savedLocaleCode).locale;
    _currencyCode =
        sanitizeCurrencyCode(prefs.getString('currencyCode')) ??
        UserPreferencesService.defaultCurrencyCode;
    _themeMode = themeModeFromName(prefs.getString(themeModePreferenceKey));
    _hapticsEnabled = prefs.getBool(hapticsEnabledPreferenceKey) ?? true;
    AppHaptics.enabled = _hapticsEnabled;
    notifyListeners();
  }

  Future<void> _saveLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localeCode', _locale.languageCode);
    await prefs.setString('currencyCode', _currencyCode);
  }

  Future<void> _bindUser(User? user) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (user == null) {
      notifyListeners();
      return;
    }

    await _preferencesService.ensureDefaults(
      user,
      localeCode: _locale.languageCode,
      currencyCode: _currencyCode,
    );

    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data() ?? {};
          _locale = findLocaleOption(
            (data['localeCode'] as String?) ?? _locale.languageCode,
          ).locale;
          _currencyCode =
              sanitizeCurrencyCode(data['currencyCode'] as String?) ??
              UserPreferencesService.defaultCurrencyCode;
          _saveLocalPreferences();
          notifyListeners();
        });
  }

  Future<void> updateLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _saveLocalPreferences();
    // The server reminder campaign reads users/{uid}.localeCode.
    await _preferencesService.updatePreference(
      'localeCode',
      normalizeLocaleCode(locale.languageCode) ??
          UserPreferencesService.defaultLocaleCode,
    );
  }

  Future<void> updateCurrencyCode(String currencyCode) async {
    _currencyCode =
        sanitizeCurrencyCode(currencyCode) ??
        UserPreferencesService.defaultCurrencyCode;
    notifyListeners();
    await _saveLocalPreferences();
    await _preferencesService.updatePreference('currencyCode', _currencyCode);
  }

  /// Appearance is a device preference: stored locally only, not synced to
  /// the user profile.
  Future<void> updateThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModePreferenceKey, mode.name);
  }

  /// Haptics are a device preference: stored locally only.
  Future<void> updateHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    AppHaptics.enabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hapticsEnabledPreferenceKey, enabled);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
