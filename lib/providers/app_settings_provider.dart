import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({UserPreferencesService? preferencesService})
    : _preferencesService = preferencesService ?? UserPreferencesService();

  final UserPreferencesService _preferencesService;

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale(UserPreferencesService.defaultLocaleCode);
  String _currencyCode = UserPreferencesService.defaultCurrencyCode;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;

  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get currencyCode => _currencyCode;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadLocalPreferences();
    await _bindUser(FirebaseAuth.instance.currentUser);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_bindUser);
  }

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _preferencesService.parseThemeMode(prefs.getString('themeMode'));
    _locale = Locale(
      prefs.getString('localeCode') ?? UserPreferencesService.defaultLocaleCode,
    );
    _currencyCode =
        prefs.getString('currencyCode') ??
        UserPreferencesService.defaultCurrencyCode;
    notifyListeners();
  }

  Future<void> _saveLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      _preferencesService.serializeThemeMode(_themeMode),
    );
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

    await _preferencesService.ensureDefaults(user);

    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data() ?? {};
          _themeMode = _preferencesService.parseThemeMode(
            data['themeMode'] as String?,
          );
          _locale = Locale(
            (data['localeCode'] as String?) ??
                UserPreferencesService.defaultLocaleCode,
          );
          _currencyCode =
              (data['currencyCode'] as String?) ??
              UserPreferencesService.defaultCurrencyCode;
          _saveLocalPreferences();
          notifyListeners();
        });
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveLocalPreferences();
    await _preferencesService.updatePreference(
      'themeMode',
      _preferencesService.serializeThemeMode(mode),
    );
  }

  Future<void> updateLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _saveLocalPreferences();
    await _preferencesService.updatePreference('localeCode', locale.languageCode);
  }

  Future<void> updateCurrencyCode(String currencyCode) async {
    _currencyCode = currencyCode;
    notifyListeners();
    await _saveLocalPreferences();
    await _preferencesService.updatePreference('currencyCode', currencyCode);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
