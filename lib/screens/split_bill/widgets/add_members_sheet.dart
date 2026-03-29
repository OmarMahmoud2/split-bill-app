import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AddMembersSheet extends StatelessWidget {
  final VoidCallback onScanQR;
  final VoidCallback onPickContacts;
  final VoidCallback? onPickGroups;

  const AddMembersSheet({
    super.key,
    required this.onScanQR,
    required this.onPickContacts,
    this.onPickGroups,
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
          Text('add_people',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ).tr(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAddOption(
                Icons.qr_code_scanner_rounded,
                'scan_qr'.tr(),
                Colors.blueAccent,
                onScanQR,
              ),
              _buildAddOption(
                Icons.contacts_rounded,
                'contacts'.tr(),
                Colors.purpleAccent,
                onPickContacts,
              ),
              if (onPickGroups != null)
                _buildAddOption(
                  Icons.groups_rounded,
                  'groups'.tr(),
                  Colors.orangeAccent,
                  onPickGroups!,
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAddOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
