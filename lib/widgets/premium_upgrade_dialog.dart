import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:easy_localization/easy_localization.dart';

/// Bottom sheet for purchasing premium upgrade
class PremiumUpgradeDialog extends StatefulWidget {
  const PremiumUpgradeDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumUpgradeDialog(),
    );
  }

  @override
  State<PremiumUpgradeDialog> createState() => _PremiumUpgradeDialogState();
}

class _PremiumUpgradeDialogState extends State<PremiumUpgradeDialog> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  Package? _premiumPackage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackage();
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
      setState(() {
        _errorMessage = 'Failed to load pricing';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    if (_premiumPackage == null) return;

    // --- PARENTAL GATE START ---
    // Simple Math Challenge to ensure purchaser is capable/authorized
    bool passedGate = await _showParentalGate();
    if (!passedGate) return;
    // --- PARENTAL GATE END ---

    setState(() => _isPurchasing = true);

    final success = await RevenueCatService.purchasePremium(_premiumPackage!);

    if (!mounted) return;

    setState(() => _isPurchasing = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('welcome_to_premium').tr(),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Shows a simple math challenge to verify the user is human/adult-ish
  /// Returns true if answer is correct.
  Future<bool> _showParentalGate() async {
    int a = DateTime.now().millisecond % 10 + 2; // Random-ish number 2-11
    int b = DateTime.now().second % 10 + 2; // Random-ish number 2-11
    int answer = a + b;

    TextEditingController controller = TextEditingController();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('parental_gate').tr(),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('to_continue_with_the_purchase_please_solve_this').tr(),
                const SizedBox(height: 16),
                Text(
                  "$a + $b = ?",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(hintText: 'enter_result'.tr()),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('incorrect_answer_purchase_cancelled').tr(),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('confirm').tr(),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);

    final success = await RevenueCatService.restorePurchases();

    if (!mounted) return;

    setState(() => _isPurchasing = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('premium_restored').tr(),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_previous_purchase_found').tr(),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Premium Header with Gold Gradient
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('go_premium',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ).tr(),
                          const SizedBox(height: 8),
                          Text('unlock_unlimited_scans_and_ad_free_experience',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ).tr(),
                        ],
                      ),
                    ),

                    // Features
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('what_s_included',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ).tr(),
                          const SizedBox(height: 16),
                          _buildFeature(
                            Icons.qr_code_scanner_rounded,
                            'Unlimited Scans',
                            'Scan as many receipts as you need',
                            const Color(0xFF00B365),
                          ),
                          const SizedBox(height: 12),
                          _buildFeature(
                            Icons.block_rounded,
                            'Zero Ads',
                            'No banner or video ads ever',
                            Colors.red,
                          ),
                          const SizedBox(height: 12),
                          _buildFeature(
                            Icons.all_inclusive_rounded,
                            'Lifetime Access',
                            'Pay once, own it forever',
                            Colors.purple,
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // Pricing & Purchase
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    else if (_premiumPackage != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _premiumPackage!.storeProduct.priceString,
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00B365),
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('one_time_payment_no_subscriptions',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ).tr(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isPurchasing
                                    ? null
                                    : _handlePurchase,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00B365),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text('upgrade_to_premium',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ).tr(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _isPurchasing ? null : _handleRestore,
                              child: Text('restore_previous_purchase',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ).tr(),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (_isPurchasing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('processing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ).tr(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeature(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
