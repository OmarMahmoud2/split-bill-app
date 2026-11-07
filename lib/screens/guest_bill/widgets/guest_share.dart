import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';

import '../guest_bill_model.dart';
import 'guest_breakdown.dart';
import 'guest_chrome.dart';

/// Splits a translated string whose names were wrapped in U+0001 markers
/// into spans, bolding the names.
List<InlineSpan> guestBoldSpans(String translated, TextStyle bold) {
  final parts = translated.split('\u0001');
  return [
    for (var i = 0; i < parts.length; i++)
      TextSpan(text: parts[i], style: i.isOdd ? bold : null),
  ];
}

/// Host avatar, "Omar split Dinner at Zooba with you", date · people · total.
class GuestHostLine extends StatelessWidget {
  const GuestHostLine({super.key, required this.bill});

  final GuestBill bill;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final host = guestHostName(bill);
    final meta = [
      if (bill.date != null)
        MaterialLocalizations.of(context).formatShortMonthDay(bill.date!),
      'guest_people_count'.tr(
        namedArgs: {'count': bill.participants.length.toString()},
      ),
      'guest2_total_amount'.tr(
        namedArgs: {
          'amount': guestAmount(bill.displayTotalMinor, bill.currency),
        },
      ),
    ].map((part) => '\u2068$part\u2069').join(' · ');
    final base = AppTypography.bodyMedium.copyWith(
      fontSize: 15,
      color: p.textPrimary,
    );
    return Row(
      children: [
        GuestAvatar(id: bill.hostId, name: host, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: guestBoldSpans(
                      'guest2_split_with_you'.tr(
                        namedArgs: {
                          'host': '\u0001$host\u0001',
                          'store': '\u0001${guestStoreName(bill)}\u0001',
                        },
                      ),
                      base.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Which one are you?" as avatar chips (selected = mint border).
class GuestChips extends StatelessWidget {
  const GuestChips({
    super.key,
    required this.bill,
    required this.selectedId,
    required this.onSelect,
  });

  final GuestBill bill;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'guest_which_one'.tr(),
            style: AppTypography.labelLarge.copyWith(
              fontSize: 13,
              color: p.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final g in bill.guests)
              _Chip(
                participant: g,
                selected: g.id == selectedId,
                onTap: () => onSelect(g.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.participant,
    required this.selected,
    required this.onTap,
  });

  final GuestParticipant participant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = participant.name.isEmpty ? 'guest'.tr() : participant.name;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? p.primarySoft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: p.primary, width: 2)
              : BorderSide(color: p.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, maxWidth: 220),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 14, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuestAvatar(id: participant.id, name: name, size: 30),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 14,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(double.infinity, 1), painter: _Dashes(color));
}

class _Dashes extends CustomPainter {
  _Dashes(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}

/// The share card: "Sara, you owe Omar", the big amount, a status pill, a
/// dashed divider and the item lines.
class GuestShareCard extends StatelessWidget {
  const GuestShareCard({super.key, required this.bill, required this.me});

  final GuestBill bill;
  final GuestParticipant me;

  /// (label, amount, muted) rows. Service + tax read as one muted line
  /// ("Service 12% + tax 14%") when both have a clean rate.
  static List<(String, int, bool)> rows(
    GuestBill bill,
    GuestBreakdown breakdown,
  ) {
    final lines = breakdown.lines;
    GuestLine? find(GuestLineKind kind) {
      for (final l in lines) {
        if (l.kind == kind && l.ratePercent != null) return l;
      }
      return null;
    }

    final service = find(GuestLineKind.service);
    final tax = find(GuestLineKind.tax);
    final out = <(String, int, bool)>[];
    var merged = false;
    for (final line in lines) {
      if (service != null && tax != null && (line == service || line == tax)) {
        if (!merged) {
          merged = true;
          out.add((
            'guest2_service_tax'.tr(
              namedArgs: {
                'service': service.ratePercent!,
                'tax': tax.ratePercent!,
              },
            ),
            service.amountMinor + tax.amountMinor,
            true,
          ));
        }
        continue;
      }
      out.add((guestLineLabel(line, bill), line.amountMinor, line.isMuted));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final breakdown = bill.breakdownFor(me.id);
    final host = guestHostName(bill);
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    final status = me.status;
    final amount = status == GuestPayStatus.pending
        ? bill.dueMinorFor(me.id)
        : breakdown.totalMinor;
    final (pillBg, pillFg, pillText) = switch (status) {
      GuestPayStatus.pending => (
        p.coralSoft,
        p.onCoralSoft,
        'guest2_pill_unpaid'.tr(),
      ),
      GuestPayStatus.review => (
        p.skySoft,
        p.sky,
        'guest2_pill_sent'.tr(namedArgs: {'host': host}),
      ),
      GuestPayStatus.paid => (
        p.successSoft,
        p.successStrong,
        'guest2_pill_paid'.tr(),
      ),
    };
    final amountColor = switch (status) {
      GuestPayStatus.pending => p.owe,
      GuestPayStatus.review => p.textPrimary,
      GuestPayStatus.paid => p.success,
    };
    final lines = rows(bill, breakdown);
    return GuestCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'guest2_you_owe'.tr(
                        namedArgs: {'name': name, 'host': host},
                      ),
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 13,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Amounts read left to right in every locale.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        guestAmount(amount, breakdown.currency),
                        textDirection: TextDirection.ltr,
                        style: AppTypography.amountHero.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == GuestPayStatus.paid) ...[
                        Icon(AppIcons.check, size: 14, color: pillFg),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          pillText,
                          style: AppTypography.labelMedium.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: pillFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DashedLine(color: p.borderStrong),
          const SizedBox(height: 12),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            GuestAmountRow(
              label: lines[i].$1,
              amount: guestAmount(lines[i].$2, breakdown.currency),
              muted: lines[i].$3,
            ),
          ],
        ],
      ),
    );
  }
}
