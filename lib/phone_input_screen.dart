import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/auth_wrapper.dart' show AuthFlow;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:split_bill_app/services/permission_flow.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/services/user_preferences_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Optional phone step ("Let friends find you"). Saving claims the number in
/// `phoneClaims` (unique per account); "Not now" records
/// `phonePromptSkippedAt` so setup is complete without a phone. Either way
/// the user continues to Home through the [PermissionGate].
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key, this.onContinue, this.onSkip});

  /// Test hooks: replace the Firestore writes and navigation.
  @visibleForTesting
  final Future<void> Function(String phone, String isoCode)? onContinue;
  @visibleForTesting
  final Future<void> Function()? onSkip;

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  String? _fullPhoneNumber; // E.164, e.g. +201012345678
  String _isoCode = 'EG';
  bool _isLoading = false;
  Key _fieldKey = UniqueKey();

  /// Fields written once for a new account, with or without a phone.
  Map<String, dynamic> _baseFields(
    User user,
    Map<String, dynamic>? existing,
    String localeCode,
  ) => {
    'photoUrl': user.photoURL,
    'displayName': user.displayName ?? '',
    'email': user.email,
    // Welcome grant: 7 points, once, never reset.
    if (existing == null || !existing.containsKey('points')) 'points': 7,
    'localeCode': localeCode,
    'currencyCode':
        existing?['currencyCode'] ?? UserPreferencesService.defaultCurrencyCode,
  };

  void _goHome() {
    // AuthWrapper re-reads the user doc and shows the permission gate and
    // Home itself; replacing the root route would drop the update check.
    AuthFlow.backToRoot(context);
  }

  Future<void> _savePhone() async {
    final phone = _fullPhoneNumber;
    if (phone == null || phone.isEmpty) {
      AppToast.show(
        context,
        message: 'please_enter_a_valid_phone_number'.tr(),
        type: AppToastType.warning,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (widget.onContinue != null) {
        await widget.onContinue!(phone, _isoCode);
        return;
      }
      final localeCode = Localizations.localeOf(context).languageCode;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Claim the number (fails if another account already owns it).
      final claimed = await PublicProfileService.claimPhone(phone);
      if (!claimed) {
        if (mounted) await _showNumberTaken(phone);
        return;
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final existing = (await userRef.get()).data();
      await userRef.set({
        ..._baseFields(user, existing, localeCode),
        'phoneNumber': phone,
        'isoCode': _isoCode,
      }, SetOptions(merge: true));
      await PublicProfileService.syncFromUserDoc(force: true);

      if (!mounted) return;
      AppToast.show(
        context,
        message: 'acct_phone_saved'.tr(),
        type: AppToastType.success,
      );
      _goHome();
    } catch (e) {
      debugPrint('Phone setup failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'acct_setup_error'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _skip() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (widget.onSkip != null) {
        await widget.onSkip!();
        return;
      }
      final localeCode = Localizations.localeOf(context).languageCode;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final existing = (await userRef.get()).data();
      await userRef.set({
        ..._baseFields(user, existing, localeCode),
        'phonePromptSkippedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await PublicProfileService.syncFromUserDoc(force: true);
      if (mounted) _goHome();
    } catch (e) {
      debugPrint('Skipping phone setup failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'acct_setup_error'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNumberTaken(String phone) async {
    AppHaptics.warning();
    await PremiumBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) {
          final p = sheetContext.palette;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'acct_phone_taken_title'.tr(),
                style: AppTypography.headlineLarge.copyWith(
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'acct_phone_taken_body'.tr(namedArgs: {'phone': phone}),
                style: AppTypography.bodyLarge.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _fullPhoneNumber = null;
                    _fieldKey = UniqueKey(); // clears the field
                  });
                },
                child: Text('try_different_number'.tr()),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _skip();
                },
                style: TextButton.styleFrom(foregroundColor: p.textPrimary),
                child: Text('acct_not_now'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canPop)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: V3IconButton.back(context),
                      ),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        'acct_phone_title'.tr(),
                        style: AppTypography.displaySmall.copyWith(
                          color: p.textPrimary,
                          fontSize: 30,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'acct_phone_body'.tr(),
                      style: AppTypography.bodyLarge.copyWith(
                        color: p.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 26),
                    V3FieldLabel('acct_phone_label'.tr()),
                    // Phone numbers are always entered left to right.
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: IntlPhoneField(
                        key: _fieldKey,
                        initialCountryCode: _isoCode,
                        disableLengthCheck: false,
                        invalidNumberMessage:
                            'please_enter_a_valid_phone_number'.tr(),
                        decoration: InputDecoration(
                          hintText: '10 1234 5678',
                          counterText: '',
                        ),
                        onChanged: (phone) => setState(() {
                          _fullPhoneNumber = phone.completeNumber;
                          _isoCode = phone.countryISOCode;
                        }),
                        onCountryChanged: (country) =>
                            setState(() => _isoCode = country.code),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('phone-save'),
                      onPressed: _isLoading ? null : _savePhone,
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.onInverseSurface,
                              ),
                            )
                          : Text('acct_phone_save'.tr()),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const ValueKey('phone-not-now'),
                      onPressed: _isLoading ? null : _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: p.textPrimary,
                      ),
                      child: Text('acct_not_now'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
