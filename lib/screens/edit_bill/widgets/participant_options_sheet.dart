import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantOptionsSheet extends StatelessWidget {
  final Map<String, dynamic> participant;
  final VoidCallback onTogglePaid;
  final VoidCallback onRemove;

  const ParticipantOptionsSheet({
    super.key,
    required this.participant,
    required this.onTogglePaid,
    required this.onRemove,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> participant,
    required VoidCallback onTogglePaid,
    required VoidCallback onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => ParticipantOptionsSheet(
        participant: participant,
        onTogglePaid: onTogglePaid,
        onRemove: onRemove,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHost = participant['isHost'] == true;
    final String status = participant['status'] ?? 'PENDING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 24),
          ),
          Text(
            participant['name'] ?? "Participant",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          _buildActionItem(
            icon: status == 'PAID'
                ? Icons.undo_rounded
                : Icons.check_circle_rounded,
            color: status == 'PAID' ? Colors.orange : Colors.green,
            label: status == 'PAID' ? "Mark as Unpaid" : "Mark as Paid",
            onTap: () {
              Navigator.pop(context);
              onTogglePaid();
            },
          ),
          if (!isHost)
            _buildActionItem(
              icon: Icons.person_remove_rounded,
              color: Colors.red,
              label: "Remove from Bill",
              onTap: () {
                Navigator.pop(context);
                _confirmRemove(context, participant, onRemove);
              },
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  void _confirmRemove(
    BuildContext context,
    Map<String, dynamic> p,
    VoidCallback onRemove,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('remove_participant').tr(),
        content: Text(
          "Are you sure you want to remove \"${p['name']}\"? Assignments will be adjusted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel').tr(),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRemove();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common_remove').tr(),
          ),
        ],
      ),
    );
  }
}
