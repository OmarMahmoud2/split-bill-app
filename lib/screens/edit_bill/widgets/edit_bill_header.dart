import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/app_palette.dart';

class EditBillHeader extends StatelessWidget {
  final String storeName;
  final VoidCallback onAddMembers;

  const EditBillHeader({
    super.key,
    required this.storeName,
    required this.onAddMembers,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'editing_bill',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: palette.infoStrong,
                    letterSpacing: 1.5,
                  ),
                ).tr(),
                Text(
                  storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.inverseSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_rounded,
                color: palette.onInverseSurface,
                size: 20,
              ),
            ),
            onPressed: onAddMembers,
          ),
        ],
      ),
    );
  }
}
