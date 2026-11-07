import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';

import 'guest_bill_model.dart';
import 'widgets/guest_share.dart';

/// "Which one are you?": the group-link name picker (host line + avatar
/// chips). Picking a chip opens the share page.
class GuestSelectorView extends StatelessWidget {
  const GuestSelectorView({
    super.key,
    required this.bill,
    required this.onParticipantSelected,
  });

  final GuestBill bill;
  final ValueChanged<String> onParticipantSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      key: const ValueKey('SelectorView'),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuestHostLine(bill: bill),
          const SizedBox(height: 20),
          GuestChips(
            bill: bill,
            selectedId: null,
            onSelect: onParticipantSelected,
          ),
          const SizedBox(height: 16),
          Text(
            'guest_privacy_note'.tr(),
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
