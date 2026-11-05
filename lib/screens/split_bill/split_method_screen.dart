import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';

/// "How to split" (Split.dc.html, first board): by item, equal, exact,
/// percent or shares. Pops the updated [BillDraft] (method + inputs), or
/// null when cancelled.
class SplitMethodScreen extends StatefulWidget {
  const SplitMethodScreen({
    super.key,
    required this.draft,
    required this.participants,
  });

  /// The bill so far; `draft.participantIds` must match [participants].
  final BillDraft draft;

  /// Legacy participant maps (`id`, `name`, `photoUrl`, `isHost`...).
  final List<Map<String, dynamic>> participants;

  static Future<BillDraft?> open(
    BuildContext context, {
    required BillDraft draft,
    required List<Map<String, dynamic>> participants,
  }) => Navigator.of(context).push<BillDraft>(
    MaterialPageRoute(
      builder: (_) =>
          SplitMethodScreen(draft: draft, participants: participants),
    ),
  );

  @override
  State<SplitMethodScreen> createState() => _SplitMethodScreenState();
}

class _SplitMethodScreenState extends State<SplitMethodScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
