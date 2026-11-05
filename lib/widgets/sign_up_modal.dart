import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Email sign-up sheet. [onSignUp] performs the sign-up and throws on
/// failure (the caller shows the error); the sheet closes on success.
class SignUpModal extends StatefulWidget {
  final Future<void> Function(String name, String email, String password)
  onSignUp;

  const SignUpModal({super.key, required this.onSignUp});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String name, String email, String password)
    onSignUp,
  }) {
    return PremiumBottomSheet.show(
      context: context,
      isScrollable: true,
      child: SignUpModal(onSignUp: onSignUp),
    );
  }

  /// Field validation, shared with tests. Returns a translation key.
  @visibleForTesting
  static String? validateField(String kind, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'required';
    if (kind == 'email' && !_emailPattern.hasMatch(v)) {
      return 'acct_err_invalid_email';
    }
    if (kind == 'password' && (value ?? '').length < 6) {
      return 'acct_err_weak_password';
    }
    return null;
  }

  @override
  State<SignUpModal> createState() => _SignUpModalState();
}

class _SignUpModalState extends State<SignUpModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      AppHaptics.error();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await widget.onSignUp(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      AppHaptics.success();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validate(String kind, String? value) {
    final key = SignUpModal.validateField(kind, value);
    return key?.tr();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                'acct_signup_title'.tr(),
                style: AppTypography.headlineLarge.copyWith(
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'acct_signup_sub'.tr(),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 20),
            V3FieldLabel('acct_name_label'.tr()),
            TextFormField(
              key: const ValueKey('signup-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              validator: (v) => _validate('name', v),
            ),
            const SizedBox(height: 14),
            V3FieldLabel('acct_email_label'.tr()),
            TextFormField(
              key: const ValueKey('signup-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              textDirection: ui.TextDirection.ltr,
              decoration: const InputDecoration(hintText: 'you@example.com'),
              validator: (v) => _validate('email', v),
            ),
            const SizedBox(height: 14),
            V3FieldLabel('password'.tr()),
            TextFormField(
              key: const ValueKey('signup-password'),
              controller: _passwordController,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              onFieldSubmitted: (_) => _handleSignUp(),
              decoration: InputDecoration(
                helperText: 'acct_password_rule'.tr(),
                suffixIcon: IconButton(
                  tooltip:
                      (_hidePassword
                              ? 'acct_show_password'
                              : 'acct_hide_password')
                          .tr(),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (v) => _validate('password', v),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('signup-submit'),
              onPressed: _isLoading ? null : _handleSignUp,
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onInverseSurface,
                      ),
                    )
                  : Text('create_account'.tr()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
