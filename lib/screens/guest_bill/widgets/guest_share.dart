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
    this.horizontal = false,
    this.large = false,
  });

  final GuestBill bill;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// One scrolling row (phones with many people) instead of wrapping.
  final bool horizontal;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget chip(GuestParticipant g, bool gap) => Padding(
      padding: EdgeInsetsDirectional.only(end: gap ? 10 : 0),
      child: _Chip(
        participant: g,
        selected: g.id == selectedId,
        large: large,
        onTap: () => onSelect(g.id),
      ),
    );
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
        if (horizontal)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final g in bill.guests) chip(g, true)]),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final g in bill.guests) chip(g, false)],
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
    required this.large,
  });

  final GuestParticipant participant;
  final bool selected;
  final bool large;
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
            constraints: BoxConstraints(
              minHeight: large ? 60 : 48,
              maxWidth: 220,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 14, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuestAvatar(
                    id: participant.id,
                    name: name,
                    size: large ? 38 : 30,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: large ? 16 : 14,
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
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _Dashes(color),
  );
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

/// "Unpaid" / "Sent to Omar" / "Paid" pill.
class GuestStatusPill extends StatelessWidget {
  const GuestStatusPill({super.key, required this.status, required this.host});

  final GuestPayStatus status;
  final String host;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}

/// The amount the guest still owes (or owed), by status.
Color guestAmountColor(BuildContext context, GuestPayStatus status) {
  final p = context.palette;
  return switch (status) {
    GuestPayStatus.pending => p.owe,
    GuestPayStatus.review => p.textPrimary,
    GuestPayStatus.paid => p.success,
  };
}

/// The share card: "Sara, you owe Omar", the big amount, a status pill, a
/// dashed divider and the item lines.
class GuestShareCard extends StatefulWidget {
  const GuestShareCard({
    super.key,
    required this.bill,
    required this.me,
    this.collapseAfter,
    this.showAmount = true,
  });

  final GuestBill bill;
  final GuestParticipant me;

  /// Fold the lines after this many behind a "Show all N items" toggle.
  final int? collapseAfter;

  /// Desktop shows the amount + status in the side panel instead.
  final bool showAmount;

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
  State<GuestShareCard> createState() => _GuestShareCardState();
}

class _GuestShareCardState extends State<GuestShareCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final me = widget.me;
    final p = context.palette;
    final breakdown = bill.breakdownFor(me.id);
    final host = guestHostName(bill);
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    final status = me.status;
    final amount = status == GuestPayStatus.pending
        ? bill.dueMinorFor(me.id)
        : breakdown.totalMinor;
    final amountColor = guestAmountColor(context, status);
    final lines = GuestShareCard.rows(bill, breakdown);
    final limit = widget.collapseAfter;
    final folded = limit != null && lines.length > limit && !_expanded;
    final shown = folded ? limit : lines.length;
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
                    if (widget.showAmount) const SizedBox(height: 2),
                    // Amounts read left to right in every locale.
                    if (widget.showAmount)
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
              if (widget.showAmount) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: GuestStatusPill(status: status, host: host),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _DashedLine(color: p.borderStrong),
          const SizedBox(height: 12),
          for (var i = 0; i < shown; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            GuestAmountRow(
              label: lines[i].$1,
              amount: guestAmount(lines[i].$2, breakdown.currency),
              muted: lines[i].$3,
            ),
          ],
          if (limit != null && lines.length > limit)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: p.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? 'guest3_show_less'.tr()
                      : 'guest3_show_all'.tr(
                          namedArgs: {'count': lines.length.toString()},
                        ),
                ),
              ),
            ),
          // Part already paid (e.g. the bill grew after they paid): show the
          // sum, so "you owe" matches the lines above it.
          if (status == GuestPayStatus.pending && me.paidMinor > 0) ...[
            const SizedBox(height: 12),
            _DashedLine(color: p.borderStrong),
            const SizedBox(height: 12),
            GuestAmountRow(
              label: 'guest2_your_share'.tr(),
              amount: guestAmount(breakdown.totalMinor, breakdown.currency),
            ),
            const SizedBox(height: 8),
            GuestAmountRow(
              label: 'guest2_already_paid'.tr(),
              amount: '−${guestAmount(me.paidMinor, breakdown.currency)}',
              muted: true,
            ),
            const SizedBox(height: 8),
            GuestAmountRow(
              label: 'guest2_left_to_pay'.tr(),
              amount: guestAmount(amount, breakdown.currency),
              bold: true,
            ),
          ],
        ],
      ),
    );
  }
}
