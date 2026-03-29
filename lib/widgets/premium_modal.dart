import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class PremiumModal extends StatefulWidget {
  const PremiumModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PremiumModal(),
    );
  }

  @override
  State<PremiumModal> createState() => _PremiumModalState();
}

class _PremiumModalState extends State<PremiumModal>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isPurchasing = false;
  Package? _premiumPackage;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _loadPackage();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadPackage() async {
    setState(() => _isLoading = true);
    try {
      final package = await RevenueCatService.getPremiumPackage();
      setState(() {
        _premiumPackage = package;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_premiumPackage == null) return;

    // Parental Gate
    final passed = await _showParentalGate();
    if (!passed) return;

    // Identify User with RevenueCat
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await RevenueCatService.syncCurrentUser();
      } catch (e) {
        debugPrint("RevenueCat Identify Error: $e");
      }
    }

    setState(() => _isPurchasing = true);
    final success = await RevenueCatService.purchasePremium(_premiumPackage!);

    if (mounted) {
      setState(() => _isPurchasing = false);
      if (success) {
        Navigator.pop(context, true);
        _showSuccessConfetti();
      }
    }
  }

  // Reuse logic from previous dialog
  Future<bool> _showParentalGate() async {
    int a = DateTime.now().millisecond % 10 + 2;
    int b = DateTime.now().second % 10 + 2;
    int answer = a + b;
    TextEditingController controller = TextEditingController();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text('parental_gate').tr(),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('quick_check_solve_this_to_continue').tr(),
                const SizedBox(height: 16),
                Text(
                  "$a + $b = ?",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'answer'.tr(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('common_cancel').tr(),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim() == answer.toString()) {
                    Navigator.pop(context, true);
                  } else {
                    Navigator.pop(context, false);
                  }
                },
                child: Text('verify').tr(),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);
    final success = await RevenueCatService.restorePurchases();
    if (mounted) {
      setState(() => _isPurchasing = false);
      if (success) {
        Navigator.pop(context, true);
        _showSuccessConfetti();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('no_previous_purchase_found').tr()),
        );
      }
    }
  }

  void _showSuccessConfetti() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('welcome_to_premium').tr(),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glassmorphic Card
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 700,
                ),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF1A1A1A,
                  ).withValues(alpha: 0.95), // Dark Premium Theme
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Image / Animation
                      SizedBox(
                        height: 120, // Reduced height (was 200)
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Gold Gradient Background
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            // Lottie / Icon
                            Align(
                              alignment: Alignment.center,
                              child: Lottie.asset(
                                'assets/animations/premium.json',
                                height: 80, // Reduced icon size
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Close Button
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text('upgrade_to_pro',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ).tr(),
                            const SizedBox(height: 8),
                            Text('unlock_the_full_power_of_split_bill',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ).tr(),
                            const SizedBox(height: 32),

                            // Features
                            _buildPremiumFeature(
                              Icons.bolt_rounded,
                              "Unlimited Scans",
                              "No limits, scan receipts forever.",
                            ),
                            const SizedBox(height: 12),
                            _buildPremiumFeature(
                              Icons.block_flipped,
                              "Remove Ads",
                              "Enjoy a distraction-free experience.",
                            ),
                            const SizedBox(height: 12),
                            _buildPremiumFeature(
                              Icons.diamond_outlined,
                              "Support Development",
                              "Help us verify your receipts faster.",
                            ),

                            const SizedBox(height: 24),

                            // Price & Button
                            if (_isLoading)
                              const CircularProgressIndicator(
                                color: Color(0xFFFFD700),
                              )
                            else if (_premiumPackage != null)
                              Column(
                                children: [
                                  Text(
                                    _premiumPackage!.storeProduct.priceString,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFD700),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('one_time_payment_lifetime_access',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                  ).tr(),
                                  const SizedBox(height: 20),

                                  // Shimmering Button
                                  AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, child) {
                                      return Container(
                                        width: double.infinity,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: const [
                                              Color(0xFFFFD700),
                                              Color(0xFFFFE57F),
                                              Color(0xFFFFD700),
                                            ],
                                            stops: const [0.0, 0.5, 1.0],
                                            begin: Alignment(
                                              -1.0 +
                                                  (_shimmerController.value *
                                                      2),
                                              -0.5,
                                            ),
                                            end: Alignment(
                                              1.0 +
                                                  (_shimmerController.value *
                                                      2),
                                              0.5,
                                            ),
                                            tileMode: TileMode.clamp,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFFD700,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isPurchasing
                                              ? null
                                              : _handlePurchase,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isPurchasing
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.black,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text('unlock_premium_now',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18,
                                                  ),
                                                ).tr(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            else
                              Text('pricing_unavailable',
                                style: TextStyle(color: Colors.redAccent),
                              ).tr(),

                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _handleRestore,
                              child: Text('restore_purchase',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ).tr(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
