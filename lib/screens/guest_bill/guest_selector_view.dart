import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';

import 'guest_bill_model.dart';
import 'widgets/guest_breakdown.dart';
import 'widgets/guest_chrome.dart';

/// "Which one are you?": the group-link name picker (v3 guest state 1).
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
    final guests = bill.guests;
    final meta = [
      if (bill.date != null)
        MaterialLocalizations.of(context).formatShortMonthDay(bill.date!),
      guestAmount(bill.displayTotalMinor, bill.currency),
      'guest_people_count'.tr(
        namedArgs: {'count': bill.participants.length.toString()},
      ),
    ].map((part) => '\u2068$part\u2069').join(' · ');

    return SingleChildScrollView(
      key: const ValueKey('SelectorView'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'guest_shared_by'.tr(
                    namedArgs: {'host': guestHostName(bill)},
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  header: true,
                  child: Text(
                    guestStoreName(bill),
                    style: AppTypography.displaySmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 8),
            child: Semantics(
              header: true,
              child: Text(
                'guest_which_one'.tr(),
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 15,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GuestCard(
              child: Column(
                children: [
                  for (var i = 0; i < guests.length; i++)
                    _NameRow(
                      participant: guests[i],
                      currency: bill.currency,
                      first: i == 0,
                      onTap: () => onParticipantSelected(guests[i].id),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
            child: Text(
              'guest_privacy_note'.tr(),
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.participant,
    required this.currency,
    required this.first,
    required this.onTap,
  });

  final GuestParticipant participant;
  final String currency;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final trailing = switch (participant.status) {
      GuestPayStatus.paid => 'guest_status_paid'.tr(),
      GuestPayStatus.review => 'guest_status_review'.tr(),
      GuestPayStatus.pending => guestAmount(
        participant.outstandingMinor,
        currency,
        symbol: false,
      ),
    };
    final name = participant.name.isEmpty ? 'guest'.tr() : participant.name;
    return Semantics(
      button: true,
      label: '$name, $trailing',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            border: first
                ? null
                : Border(top: BorderSide(color: p.borderSubtle)),
          ),
          child: Row(
            children: [
              GuestAvatar(id: participant.id, initial: participant.initial),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                trailing,
                textDirection: participant.status == GuestPayStatus.pending
                    ? TextDirection.ltr
                    : null,
                style: AppTypography.amountSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
