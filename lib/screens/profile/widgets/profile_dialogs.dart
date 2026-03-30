import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileDialogs {
  static Future<void> showContactUs(BuildContext context) async {
    const String email = "omar.mahmoud1@yahoo.com";
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'contact_support'.tr(),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, anim1, anim2) {
        return Stack(
          children: [
            // Glassmorphic Background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

            // Dialog Content
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Animation
                      SizedBox(
                        height: 120,
                        child: Lottie.asset(
                          'assets/animations/support.json',
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.support_agent_rounded,
                              size: 80,
                              color: Colors.blueAccent,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('we_re_here_to_help',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          decoration: TextDecoration.none,
                          fontFamily: '.SF Pro Text',
                        ),
                        textAlign: TextAlign.center,
                      ).tr(),
                      const SizedBox(height: 8),
                      Text('have_a_question_or_feedback_nreach_out_to_us_anytime',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal,
                          fontFamily: '.SF Pro Text',
                        ),
                        textAlign: TextAlign.center,
                      ).tr(),
                      const SizedBox(height: 24),

                      // Email Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final Uri emailLaunchUri = Uri(
                              scheme: 'mailto',
                              path: email,
                              queryParameters: {
                                'subject': 'support_request_split_bill_app'.tr(),
                              },
                            );
                            if (await canLaunchUrl(emailLaunchUri)) {
                              await launchUrl(emailLaunchUri);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.email_rounded, color: Colors.white),
                                SizedBox(width: 12),
                                Text('send_email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ).tr(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Copy Email Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(text: email));
                            Navigator.of(dialogContext).pop();
                            messenger?.showSnackBar(
                              SnackBar(
                                content: Text('email_copied_to_clipboard').tr(),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text('copy_email_address',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ).tr(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Cancel Button
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text('maybe_later',
                          style: TextStyle(color: Colors.grey),
                        ).tr(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  static void showLogout(BuildContext context) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        content: Text('are_you_sure_you_want_to_logout').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common_cancel', style: TextStyle(color: Colors.grey)).tr(),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              showDialog(
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
                        Expanded(child: Text('signing_out').tr()),
                      ],
                    ),
                  ),
                ),
              );

              try {
                await AuthService().signOut();
                rootNavigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              } catch (e) {
                if (rootNavigator.canPop()) {
                  rootNavigator.pop();
                }
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ).tr(),
          ),
        ],
      ),
    );
  }

  static void showDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;
    final messenger = ScaffoldMessenger.maybeOf(rootContext);
    
    final providers = user?.providerData
            .map((provider) => provider.providerId)
            .where((providerId) => providerId.isNotEmpty)
            .toSet() ??
        <String>{};
        
    final requiresPassword =
        providers.contains('password') &&
        !providers.contains('google.com') &&
        !providers.contains('apple.com');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Text('delete_account',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ).tr(),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('delete_account_warning_message',
            style: const TextStyle(fontSize: 14),
          ).tr(),
          if (requiresPassword) ...[
            const SizedBox(height: 16),
            Text('delete_account_requires_password',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ).tr(),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _hidePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'current_password'.tr(),
                errorText: _passwordError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _hidePassword = !_hidePassword;
                  }),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('no_keep_it',
            style: const TextStyle(color: Colors.grey),
          ).tr(),
        ),
        ElevatedButton(
          onPressed: () async {
            if (requiresPassword &&
                _passwordController.text.trim().isEmpty) {
              setState(() {
                _passwordError = 'enter_current_password_to_continue'.tr();
              });
              return;
            }

            Navigator.of(context).pop();
            showDialog(
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
                      Expanded(child: Text('deleting_account').tr()),
                    ],
                  ),
                ),
              ),
            );

            try {
              await AuthService().deleteAccount(
                password: requiresPassword
                    ? _passwordController.text.trim()
                    : null,
              );

              rootNavigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (route) => false,
              );
            } catch (e) {
              if (rootNavigator.canPop()) {
                rootNavigator.pop();
              }
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('yes_delete').tr(),
        ),
      ],
    );
  }
}
