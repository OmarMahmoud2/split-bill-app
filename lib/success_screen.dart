import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/share_link_utils.dart';
import 'home_screen.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
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
                    const Text(
                      "Success!",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Your bill has been created and sent.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    if (notifiedUsers.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "NOTIFIED VIA APP",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
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
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        n,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue,
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "MANUAL SHARE NEEDED",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 1.2,
                          ),
                        ),
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
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange[200],
                                  child: Text(
                                    name[0],
                                    style: const TextStyle(
                                      color: Colors.orange,
                                    ),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      Text(
                                        CurrencyUtils.format(
                                          amount,
                                          currencyCode: currencyCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[800],
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
                                      label: const Text("Share"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
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
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Done",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
