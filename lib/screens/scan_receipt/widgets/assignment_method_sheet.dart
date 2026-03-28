import 'package:flutter/material.dart';

class AssignmentMethodSheet extends StatelessWidget {
  final VoidCallback onVoiceCommand;
  final VoidCallback onManualAssignment;

  const AssignmentMethodSheet({
    super.key,
    required this.onVoiceCommand,
    required this.onManualAssignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "How to assign items?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildMethodOption(
            icon: Icons.mic_rounded,
            title: "Voice Command",
            subtitle: "Just say who ate what! (Cost: 1 Credit)",
            color: Colors.blueAccent,
            onTap: () {
              Navigator.pop(context);
              onVoiceCommand();
            },
          ),
          const SizedBox(height: 16),
          _buildMethodOption(
            icon: Icons.touch_app_rounded,
            title: "Manual Assignment",
            subtitle: "Tap to assign items manually (Free)",
            color: Colors.grey.shade700,
            onTap: () {
              Navigator.pop(context);
              onManualAssignment();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
