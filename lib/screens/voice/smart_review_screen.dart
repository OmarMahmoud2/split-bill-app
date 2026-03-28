import 'package:flutter/material.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';

class SmartReviewScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Map<String, dynamic>> participants;
  final Map<String, List<String>> assignments; // ItemID -> List<UserID>
  final String transcript;

  const SmartReviewScreen({
    super.key,
    required this.receiptData,
    required this.participants,
    required this.assignments,
    required this.transcript,
  });

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> {
  // We need to map the AI's "ItemID -> UserIDs" to the app's internal assignment structure.
  // We'll calculate totals locally for display.

  late List<dynamic> _items;
  late Map<String, List<String>> _currentAssignments;

  @override
  void initState() {
    super.initState();
    _items = widget.receiptData['items'] ?? [];
    _currentAssignments = Map.from(widget.assignments);
  }

  String _getUserName(String userId) {
    if (userId == "host") return "Me";
    try {
      final person = widget.participants.firstWhere((p) {
        final data = p['data'];
        return (data['uid'] ?? "") == userId;
      });
      return person['data']['displayName'] ?? "Unknown";
    } catch (e) {
      return "Unknown";
    }
  }

  void _confirmAndContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SplitBillScreen(
          receiptData: widget.receiptData,
          initialParticipants: widget.participants,
          initialAssignments: widget.assignments,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppHeader(
        title: "Smart Review",
        subtitle: "Confirm Assignments",
      ),
      body: Column(
        children: [
          // Transcript Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You said:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "\"${widget.transcript}\"",
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final String itemId =
                    "$index"; // Assuming index-based ID for now
                final assignedUserIds = _currentAssignments[itemId] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              "\$${item['price']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (assignedUserIds.isEmpty)
                          const Text(
                            "Unassigned",
                            style: TextStyle(color: Colors.redAccent),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: assignedUserIds
                                .map(
                                  (uid) => Chip(
                                    label: Text(_getUserName(uid)),
                                    backgroundColor: Colors.blue.shade50,
                                    labelStyle: TextStyle(
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _confirmAndContinue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Confirm Assignments",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
