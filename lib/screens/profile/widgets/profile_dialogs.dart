import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/services/auth_service.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileDialogs {
  static Future<void> showContactUs(BuildContext context) async {
    const String email = "omar.mahmoud1@yahoo.com";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Contact Support",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
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
                                'subject': 'Support Request - Split Bill App',
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
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
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
                        onPressed: () => Navigator.pop(context),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        content: Text('are_you_sure_you_want_to_logout').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel', style: TextStyle(color: Colors.grey)).tr(),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('delete_account',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ).tr(),
          ],
        ),
        content: Text('this_action_is_extremely_destructive_and_irreversible_you_will_lose_all_your_bills_and_data_forever_n_nyou_ll_be_asked_to_sign_in_again_to_confirm_this_action_n_nare_you_absolutely_sure',
          style: TextStyle(fontSize: 14),
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('no_keep_it',
              style: TextStyle(color: Colors.grey),
            ).tr(),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close confirmation dialog first
              Navigator.pop(context);

              // Store navigator reference BEFORE async operations
              final navigator = Navigator.of(context);

              // Show loading dialog using root navigator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => PopScope(
                      canPop: false,
                      child: AlertDialog(
                        content: Row(
                          children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text('deleting_account').tr(),
                      ],
                    ),
                  ),
                ),
              );

              try {
                await AuthService().deleteAccount();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                navigator.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().contains('cancelled')
                            ? 'Deletion cancelled'
                            : 'Error deleting account: $e',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
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
      ),
    );
  }
}
