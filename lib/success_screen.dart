import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/share_link_utils.dart';
import 'home_screen.dart';
import 'package:easy_localization/easy_localization.dart';

// TODO(v3-screens): replace with the reusable v3 SuccessScreen in
// lib/widgets/feedback/success_screen.dart (SuccessScreen.show), then delete
// this Lottie version.
class SuccessScreen extends StatelessWidget {
  final String storeName;
  final String billId;
  final List<String> notifiedUsers;
  final List<Map<String, dynamic>> guestUsers; // Changed from List<String>
  final String currencyCode;

  const SuccessScreen({
    super.key,
    required this.storeName,
    required this.billId,
    required this.notifiedUsers,
    required this.guestUsers,
    this.currencyCode = 'USD',
  });

  void _shareLink(
    BuildContext context,
    String name,
    double amount,
    String? participantId,
  ) async {
    final box = context.findRenderObject() as RenderBox?;

    final Rect? sharePosition = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    final url = ShareLinkUtils.buildBillShareUrl(
      billId,
      participantId: participantId,
    );

    final String message =
        "💸 Hey $name! Your share for \"$storeName\" is ${CurrencyUtils.format(amount, currencyCode: currencyCode)}.\n\n"
        "Check your items and pay here:\n$url\n\n"
        "Powered by SplitBill App 🚀";

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: "Your share for $storeName",
        sharePositionOrigin: sharePosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/success.json',
                      width: 200,
                      height: 200,
                      repeat: false,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'success',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ).tr(),
                    Text(
                      'your_bill_has_been_created_and_sent',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: p.textTertiary),
                    ).tr(),
                    const SizedBox(height: 40),

                    if (notifiedUsers.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'notified_via_app',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.info,
                            letterSpacing: 1.2,
                          ),
                        ).tr(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.infoSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: notifiedUsers
                              .map(
                                (n) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: p.info,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        n,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: p.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    if (guestUsers.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'manual_share_needed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.warning,
                            letterSpacing: 1.2,
                          ),
                        ).tr(),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: guestUsers.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final guest = guestUsers[index];
                          final name = guest['name'] as String;
                          final amount = (guest['amount'] as num).toDouble();

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: p.warningSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: p.tint(
                                    Colors.orange[200]!,
                                    Colors.orange,
                                  ),
                                  child: Text(
                                    name[0],
                                    style: TextStyle(color: p.warning),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: p.warning,
                                        ),
                                      ),
                                      Text(
                                        CurrencyUtils.format(
                                          amount,
                                          currencyCode: currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.warningStrong,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (innerContext) {
                                    return ElevatedButton.icon(
                                      onPressed: () => _shareLink(
                                        innerContext,
                                        name,
                                        amount,
                                        guest['id'],
                                      ),
                                      icon: const Icon(Icons.share, size: 16),
                                      label: Text('share').tr(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: p.warning,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (c) => const HomeScreen()),
                    (r) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: p.inverseSurface,
                    foregroundColor: p.onInverseSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'done',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ).tr(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
