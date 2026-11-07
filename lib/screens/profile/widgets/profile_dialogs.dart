import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'package:url_launcher/url_launcher.dart';

/// v3 sheets for Help and contact, Privacy and data, Sign out and Delete
/// account.
class ProfileDialogs {
  ProfileDialogs._();

  static Widget _title(BuildContext context, String text) => Text(
    text,
    style: AppTypography.headlineLarge.copyWith(
      color: context.palette.textPrimary,
    ),
  );

  static Widget _body(BuildContext context, String text) => Text(
    text,
    style: AppTypography.bodyLarge.copyWith(
      color: context.palette.textSecondary,
      height: 1.5,
    ),
  );

  static Future<void> showContactUs(BuildContext context) async {
    const email = AppLinks.supportEmail;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    await PremiumBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(sheetContext, 'prof_help_title'.tr()),
            const SizedBox(height: 8),
            _body(sheetContext, 'prof_help_body'.tr()),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: email,
                  queryParameters: {
                    'subject': 'support_request_split_bill_app'.tr(),
                  },
                );
                final opened = await canLaunchUrl(uri) && await launchUrl(uri);
                if (!opened && rootContext.mounted) {
                  AppToast.show(
                    rootContext,
                    message: 'prof_mail_unavailable'.tr(),
                    type: AppToastType.warning,
                  );
                }
              },
              icon: const Icon(AppIcons.mail),
              label: Text('send_email'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: email));
                Navigator.of(sheetContext).pop();
                AppToast.show(
                  rootContext,
                  message: 'prof_email_copied'.tr(),
                  type: AppToastType.success,
                );
              },
              child: Text('copy_email_address'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  /// Privacy policy, terms, export, sign out and delete account.
  static Future<void> showPrivacyAndData(
    BuildContext context, {
    required VoidCallback onExport,
  }) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Future<void> open(String url) async {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && rootContext.mounted) {
        AppToast.show(
          rootContext,
          message: 'could_not_open_legal_link'.tr(),
          type: AppToastType.error,
        );
      }
    }

    return PremiumBottomSheet.show<void>(
      context: context,
      padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 24),
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _title(sheetContext, 'prof_privacy_data'.tr()),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _body(sheetContext, 'prof_privacy_data_body'.tr()),
            ),
            const SizedBox(height: 16),
            SettingsCard(
              children: [
                SettingsRow(
                  title: 'prof_privacy_policy'.tr(),
                  trailing: Icon(
                    AppIcons.openExternal,
                    size: 18,
                    color: sheetContext.palette.textTertiary,
                  ),
                  showChevron: false,
                  onTap: () => open(AppLinks.privacyPolicyUrl),
                ),
                SettingsRow(
                  title: 'prof_terms'.tr(),
                  trailing: Icon(
                    AppIcons.openExternal,
                    size: 18,
                    color: sheetContext.palette.textTertiary,
                  ),
                  showChevron: false,
                  onTap: () => open(AppLinks.termsOfUseUrl),
                ),
                SettingsRow(
                  title: 'prof_export_my_data'.tr(),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onExport();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SettingsCard(
              children: [
                SettingsRow(
                  key: const ValueKey('privacy-sign-out'),
                  title: 'prof_sign_out'.tr(),
                  showChevron: false,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showLogout(rootContext);
                  },
                ),
                SettingsRow(
                  key: const ValueKey('privacy-delete-account'),
                  title: 'prof_delete_account'.tr(),
                  destructive: true,
                  showChevron: false,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showDeleteAccount(rootContext);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _blockingProgress(BuildContext rootContext, String text) {
    return showDialog<void>(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  static void showLogout(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;
    PremiumBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(sheetContext, 'prof_sign_out_title'.tr()),
            const SizedBox(height: 8),
            _body(sheetContext, 'prof_sign_out_body'.tr()),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('confirm-sign-out'),
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                AppHaptics.light();
                _blockingProgress(rootContext, 'signing_out'.tr());
                try {
                  await AuthService().signOut();
                  rootNavigator.popUntil((route) => route.isFirst);
                } catch (_) {
                  if (rootNavigator.canPop()) rootNavigator.pop();
                  if (rootContext.mounted) {
                    AppToast.show(
                      rootContext,
                      message: 'prof_sign_out_failed'.tr(),
                      type: AppToastType.error,
                    );
                  }
                }
              },
              child: Text('prof_sign_out'.tr()),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: Text('common_cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteAccount(BuildContext context) {
    PremiumBottomSheet.show<void>(
      context: context,
      isScrollable: true,
      child: const _DeleteAccountSheet(),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete(bool requiresPassword) async {
    if (requiresPassword && _passwordController.text.trim().isEmpty) {
      setState(() {
        _passwordError = 'enter_current_password_to_continue'.tr();
      });
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;
    final password = _passwordController.text.trim();
    Navigator.of(context).pop();
    AppHaptics.warning();
    ProfileDialogs._blockingProgress(rootContext, 'deleting_account'.tr());

    try {
      await AuthService().deleteAccount(
        password: requiresPassword ? password : null,
      );
      rootNavigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (rootNavigator.canPop()) rootNavigator.pop();
      if (rootContext.mounted) {
        AppToast.show(
          rootContext,
          message: e is String && e.isNotEmpty ? e : 'prof_delete_failed'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = FirebaseAuth.instance.currentUser;
    final providers =
        user?.providerData
            .map((provider) => provider.providerId)
            .where((id) => id.isNotEmpty)
            .toSet() ??
        <String>{};
    final requiresPassword =
        providers.contains('password') &&
        !providers.contains('google.com') &&
        !providers.contains('apple.com');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileDialogs._title(context, 'prof_delete_title'.tr()),
        const SizedBox(height: 8),
        ProfileDialogs._body(context, 'prof_delete_body'.tr()),
        if (requiresPassword) ...[
          const SizedBox(height: 16),
          Text(
            'delete_account_requires_password'.tr(),
            style: AppTypography.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _hidePassword,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'current_password'.tr(),
              errorText: _passwordError,
              suffixIcon: IconButton(
                tooltip: _hidePassword
                    ? 'prof_show_password'.tr()
                    : 'prof_hide_password'.tr(),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(
                  _hidePassword
                      ? AppIcons.eyeOff
                      : AppIcons.eye,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('confirm-delete-account'),
          style: FilledButton.styleFrom(
            backgroundColor: p.error,
            foregroundColor: p.onError,
          ),
          onPressed: () => _delete(requiresPassword),
          child: Text('prof_delete_confirm'.tr()),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('prof_keep_account'.tr()),
        ),
      ],
    );
  }
}
