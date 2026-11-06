import 'dart:io' show Platform;

import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'package:split_bill_app/widgets/sign_up_modal.dart';
import 'package:url_launcher/url_launcher.dart';

/// Maps an [AuthService] error (it throws English strings built from
/// FirebaseAuthException codes) onto a localized, friendly message key.
@visibleForTesting
String authErrorMessageKey(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('badly formatted') || text.contains('invalid-email')) {
    return 'acct_err_invalid_email';
  }
  if (text.contains('been disabled')) return 'acct_err_user_disabled';
  if (text.contains('no user found') ||
      text.contains('incorrect password') ||
      text.contains('could not be verified')) {
    return 'acct_err_wrong_credentials';
  }
  if (text.contains('already in use')) return 'acct_err_email_in_use';
  if (text.contains('too weak')) return 'acct_err_weak_password';
  if (text.contains('too many')) return 'acct_err_too_many';
  if (text.contains('network')) return 'acct_err_network';
  if (text.contains('another sign-in method')) return 'acct_err_other_method';
  if (text.contains('google')) return 'acct_err_google';
  if (text.contains('apple')) return 'acct_err_apple';
  return 'acct_err_generic';
}

/// v3 sign in: Apple (iOS), Google, then email + password; account creation
/// in [SignUpModal].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.showAppleOverride});

  /// Test hook: force the Apple button on or off.
  @visibleForTesting
  final bool? showAppleOverride;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AuthService? _authServiceInstance;
  AuthService get _authService => _authServiceInstance ??= AuthService();
  bool _isLoading = false;
  bool _hidePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _showApple =>
      widget.showAppleOverride ?? (!kIsWeb && Platform.isIOS);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toAuthWrapper() {
    if (!mounted) return;
    // AuthWrapper (the root) reacts to the sign-in itself; keep it, and the
    // update check above it, in the tree.
    AuthFlow.backToRoot(context, reload: false);
  }

  void _showError(Object error) {
    if (!mounted) return;
    AppToast.show(
      context,
      message: authErrorMessageKey(error).tr(),
      type: AppToastType.error,
    );
  }

  Future<void> _runSignIn(Future<Object?> Function() signIn) async {
    AppHaptics.light();
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await signIn();
      if (result == null) return; // cancelled by the user
      AppHaptics.success();
      _toAuthWrapper();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      AppToast.show(
        context,
        message: 'please_enter_email_and_password'.tr(),
        type: AppToastType.warning,
      );
      return;
    }
    await _runSignIn(
      () => _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      AppToast.show(
        context,
        message: 'please_enter_your_email_first'.tr(),
        type: AppToastType.warning,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'password_reset_email_sent_check_your_inbox'.tr(),
        type: AppToastType.success,
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showSignUp() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    String? createdEmail;
    await SignUpModal.show(
      context,
      onSignUp: (name, email, password) async {
        try {
          await _authService.signUpWithEmail(
            email: email,
            password: password,
            name: name,
          );
          createdEmail = email;
        } catch (e) {
          final toastContext = navigator.context;
          if (!toastContext.mounted) rethrow;
          AppToast.show(
            toastContext,
            message: authErrorMessageKey(e).tr(),
            type: AppToastType.error,
          );
          rethrow;
        }
      },
    );
    final email = createdEmail;
    final successContext = navigator.context;
    if (email == null || !successContext.mounted) return;
    // AuthWrapper already moved on to phone setup underneath; the success
    // screen sits on top and simply closes.
    await SuccessScreen.show<void>(
      successContext,
      title: 'acct_created_title'.tr(),
      message: 'acct_created_message'.tr(namedArgs: {'email': email}),
      primaryLabel: 'common_continue'.tr(),
      onPrimary: () => navigator.pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: LoadingStateWidget(message: 'signing_in'.tr()));
    }
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 72,
                  ),
                  child: IntrinsicHeight(
                    child: AutofillGroup(child: _buildForm(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'acct_welcome'.tr(),
            style: AppTypography.displaySmall.copyWith(
              color: p.textPrimary,
              fontSize: 34,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'acct_welcome_sub'.tr(),
          style: AppTypography.bodyLarge.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 32),
        if (_showApple) ...[
          FilledButton.icon(
            key: const ValueKey('sign-in-apple'),
            onPressed: () => _runSignIn(_authService.signInWithApple),
            icon: const Icon(Icons.apple, size: 20),
            label: Text('acct_continue_apple'.tr()),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          key: const ValueKey('sign-in-google'),
          onPressed: () => _runSignIn(_authService.signInWithGoogle),
          icon: Image.asset(
            'assets/images/google_logo.png',
            width: 18,
            height: 18,
            excludeFromSemantics: true,
          ),
          label: Text('acct_continue_google'.tr()),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: Divider(color: p.hairline)),
            Flexible(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'acct_or_with_email'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(child: Divider(color: p.hairline)),
          ],
        ),
        const SizedBox(height: 18),
        V3FieldLabel('acct_email_label'.tr()),
        TextField(
          key: const ValueKey('login-email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          textDirection: ui.TextDirection.ltr,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        const SizedBox(height: 14),
        V3FieldLabel('password'.tr()),
        TextField(
          key: const ValueKey('login-password'),
          controller: _passwordController,
          obscureText: _hidePassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _signInWithEmail(),
          decoration: InputDecoration(
            suffixIcon: IconButton(
              tooltip:
                  (_hidePassword ? 'acct_show_password' : 'acct_hide_password')
                      .tr(),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _forgotPassword,
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            child: Text('forgot_password'.tr()),
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          key: const ValueKey('sign-in-email'),
          onPressed: _signInWithEmail,
          child: Text('acct_sign_in_email'.tr()),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('sign-up'),
          onPressed: _showSignUp,
          style: TextButton.styleFrom(foregroundColor: p.textPrimary),
          child: Text('acct_new_here'.tr()),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        const AuthLegalFooter(),
        TextButton(
          onPressed: () => ProfileDialogs.showContactUs(context),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: Text('need_help_reach_out_to_us'.tr()),
        ),
      ],
    );
  }
}

/// "By continuing you accept the Terms and Privacy Policy." with both
/// links tappable.
class AuthLegalFooter extends StatefulWidget {
  const AuthLegalFooter({super.key});

  @override
  State<AuthLegalFooter> createState() => _AuthLegalFooterState();
}

class _AuthLegalFooterState extends State<AuthLegalFooter> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.termsOfUseUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(AppLinks.privacyPolicyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened && mounted) {
      AppToast.show(
        context,
        message: 'could_not_open_legal_link'.tr(),
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const termsMark = '\u0001';
    const privacyMark = '\u0002';
    final template = 'acct_legal_line'.tr(
      namedArgs: {'terms': termsMark, 'privacy': privacyMark},
    );
    final link = AppTypography.bodySmall.copyWith(
      color: p.textPrimary,
      fontSize: 12,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final char in template.characters) {
      if (char == termsMark || char == privacyMark) {
        flush();
        final isTerms = char == termsMark;
        spans.add(
          TextSpan(
            text: (isTerms ? 'acct_legal_terms' : 'acct_legal_privacy').tr(),
            style: link,
            recognizer: isTerms ? _terms : _privacy,
            semanticsLabel:
                (isTerms ? 'acct_legal_terms' : 'acct_legal_privacy').tr(),
          ),
        );
      } else {
        buffer.write(char);
      }
    }
    flush();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text.rich(
        TextSpan(
          style: AppTypography.bodySmall.copyWith(
            color: p.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
          children: spans,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
