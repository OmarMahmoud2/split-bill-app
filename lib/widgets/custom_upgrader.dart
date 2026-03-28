import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/config/app_links.dart';

class CustomUpgrader extends StatefulWidget {
  final Widget child;
  final Upgrader? upgrader;

  const CustomUpgrader({super.key, required this.child, this.upgrader});

  @override
  State<CustomUpgrader> createState() => _CustomUpgraderState();
}

class _CustomUpgraderState extends State<CustomUpgrader> {
  late Upgrader _upgrader;

  @override
  void initState() {
    super.initState();
    _upgrader =
        widget.upgrader ??
        Upgrader(
          debugDisplayAlways: false, // Set to true for testing
        );
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      await _upgrader.initialize();
      if (_upgrader.isUpdateAvailable()) {
        if (mounted) {
          _showCustomUpdateDialog();
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
  }

  void _showCustomUpdateDialog() {
    showGeneralDialog(
      context:
          context, // Note: might need navigatorKey context if init hasn't finished building, but usually safe in standard flow
      barrierDismissible: false,
      barrierLabel: "Update Available",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
                child: Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animation
                        SizedBox(
                          height: 140,
                          child: Lottie.asset(
                            'assets/animations/update_rocket.json', // Requires asset
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.rocket_launch_rounded,
                              size: 100,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Update Available! 🚀",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Version ${_upgrader.currentAppStoreVersion ?? 'New'} is now available.",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We've added new features and fixed some bugs to improve your experience.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Update Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final uri = Uri.parse(AppLinks.storeUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: Colors.blueAccent.withValues(alpha: 0.4),
                            ),
                            child: const Text(
                              "Update Now",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Later",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
