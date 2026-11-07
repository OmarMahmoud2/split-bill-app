import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Text for the "adds up" note under the method card. Pure, for tests.
///
/// Returns a translation key and its named args.
(String, Map<String, String>) splitMethodNote(BillComputation c) {
  final draft = c.draft;
  String money(int minor) => formatMoneyMinor(minor, draft.currency);
  for (final issue in c.issues) {
    switch (issue) {
      case ExactMismatchIssue(:final remainingMinor):
        return remainingMinor > 0
            ? ('bf_split_exact_left', {'amount': money(remainingMinor)})
            : ('bf_split_exact_over', {'amount': money(-remainingMinor)});
      case PercentMismatchIssue(:final sum):
        final left = 100 - sum;
        return left > 0
            ? ('bf_split_percent_left', {'percent': _pct(left)})
            : ('bf_split_percent_over', {'percent': _pct(-left)});
      case NoSharesIssue():
        return ('bf_split_shares_none', const {});
      case DiscountTooLargeIssue():
        return ('bf_split_discount_too_large', const {});
      default:
        break;
    }
  }
  final leftover = splitLeftoverMinor(c);
  final total = money(c.grandTotalMinor);
  if (leftover > 0) {
    return (
      'bf_split_adds_up_leftover',
      {'total': total, 'amount': money(leftover)},
    );
  }
  return ('bf_split_adds_up', {'total': total});
}

String _pct(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Minor units handed out by the largest-remainder rule (equal / shares),
/// i.e. what the exact proportional split could not divide evenly.
int splitLeftoverMinor(BillComputation c) {
  final draft = c.draft;
  final ids = draft.participantIds;
  if (ids.isEmpty) return 0;
  final total = c.grandTotalMinor;
  switch (draft.method) {
    case SplitMethod.equal:
      return total % ids.length;
    case SplitMethod.shares:
      final weights = [for (final id in ids) (draft.shares[id] ?? 1)];
      final sum = weights.fold<num>(0, (a, b) => a + b);
      if (sum <= 0) return 0;
      final floors = weights.fold<int>(
        0,
        (a, w) => a + (total * w / sum).floor(),
      );
      return total - floors;
    default:
      return 0;
  }
}

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
  late BillDraft _draft;
  final Map<String, TextEditingController> _exact = {};
  final Map<String, TextEditingController> _percent = {};

  List<String> get _ids => _draft.participantIds;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _draft = d.copyWith(
      method: d.method == SplitMethod.items && d.itemAssignments.isEmpty
          ? SplitMethod.equal
          : d.method,
      overrides: const {},
      clearRoulette: true,
    );
    final decimals = currencyDecimals(d.currency);
    for (final id in _ids) {
      final exact = d.exactAmounts[id];
      _exact[id] = TextEditingController(
        text: exact == null
            ? ''
            : fromMinorUnits(exact, d.currency).toStringAsFixed(decimals),
      );
      final pct = d.percentages[id];
      _percent[id] = TextEditingController(text: pct == null ? '' : _pct(pct));
    }
  }

  @override
  void dispose() {
    for (final c in [..._exact.values, ..._percent.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMethod(SplitMethod m) {
    if (m == _draft.method) return;
    AppHaptics.selection();
    setState(() {
      _draft = _draft.copyWith(method: m);
      if (m == SplitMethod.percent && _draft.percentages.isEmpty) {
        // Start from an even split the user can adjust.
        final even = 100 / _ids.length;
        final pct = {for (final id in _ids) id: even};
        _draft = _draft.copyWith(percentages: pct);
        for (final id in _ids) {
          _percent[id]!.text = _pct(double.parse(even.toStringAsFixed(2)));
        }
      }
    });
  }

  void _onExact(String id, String text) {
    final value = minorFromAny(text, _draft.currency);
    setState(() {
      _draft = _draft.copyWith(
        exactAmounts: {..._draft.exactAmounts, id: value},
      );
    });
  }

  void _onPercent(String id, String text) {
    final value = num.tryParse(text.trim().replaceAll(',', '.')) ?? 0;
    setState(() {
      _draft = _draft.copyWith(percentages: {..._draft.percentages, id: value});
    });
  }

  void _stepShares(String id, int delta) {
    final current = (_draft.shares[id] ?? 1).round();
    final next = (current + delta).clamp(0, 99);
    if (next == current) return;
    AppHaptics.selection();
    setState(() {
      _draft = _draft.copyWith(shares: {..._draft.shares, id: next});
    });
  }

  void _confirm(BillComputation c) {
    if (_draft.method != SplitMethod.items && !c.isValid) {
      AppHaptics.error();
      final (key, args) = splitMethodNote(c);
      AppToast.show(
        context,
        message: key.tr(namedArgs: args),
        type: AppToastType.error,
      );
      return;
    }
    AppHaptics.light();
    Navigator.of(context).pop(_draft);
  }

  String _nameOf(String id) {
    return (_participant(id)['name'] ?? '?').toString();
  }

  Map<String, dynamic> _participant(String id) {
    for (final p in widget.participants) {
      if (p['id']?.toString() == id) return Map<String, dynamic>.from(p);
    }
    return {'id': id};
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = computeBill(_draft);
    final method = _draft.method;
    final (noteKey, noteArgs) = splitMethodNote(c);
    final noteOk = method == SplitMethod.items || c.isValid;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: AppIcons.back,
                    label: 'bf_split_back'.tr(),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'bf_split_title'.tr(),
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
              child: SplitMethodSegments(value: method, onChanged: _setMethod),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
              child: Text(
                'bf_split_caption_${method.wireName}'.tr(),
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 16),
                children: [
                  if (method != SplitMethod.items)
                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(color: p.hairline),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < _ids.length; i++)
                            _MethodRow(
                              key: ValueKey('split_row_${_ids[i]}'),
                              first: i == 0,
                              participant: _participant(_ids[i]),
                              name: _nameOf(_ids[i]),
                              method: method,
                              amountMinor: c.shareOf(_ids[i]),
                              currency: _draft.currency,
                              shares: (_draft.shares[_ids[i]] ?? 1).round(),
                              exactController: _exact[_ids[i]]!,
                              percentController: _percent[_ids[i]]!,
                              onExact: (t) => _onExact(_ids[i], t),
                              onPercent: (t) => _onPercent(_ids[i], t),
                              onShares: (d) => _stepShares(_ids[i], d),
                            ),
                        ],
                      ),
                    ),
                  if (method != SplitMethod.items) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: noteOk ? p.accentSoft : p.oweSoft,
                          borderRadius: AppRadii.rowRadius,
                        ),
                        child: Text(
                          noteKey.tr(namedArgs: noteArgs),
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: noteOk ? p.onAccentSoft : p.oweInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: AssignPillButton(
                key: const ValueKey('split_method_confirm'),
                label: method == SplitMethod.items
                    ? 'bf_split_assign_by_item'.tr()
                    : 'bf_split_review_totals'.tr(),
                muted: !noteOk,
                onPressed: () => _confirm(c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The five-way segmented control.
class SplitMethodSegments extends StatelessWidget {
  const SplitMethodSegments({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SplitMethod value;
  final ValueChanged<SplitMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: AppRadii.rowRadius,
      ),
      child: Row(
        children: [
          for (final m in SplitMethod.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: m == value,
                child: InkWell(
                  key: ValueKey('split_seg_${m.wireName}'),
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(m),
                  child: AnimatedContainer(
                    duration: AppMotion.reduceMotion(context)
                        ? Duration.zero
                        : AppMotion.fast,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m == value ? p.surface : null,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'bf_split_seg_${m.wireName}'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: m == value ? p.textPrimary : p.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    super.key,
    required this.first,
    required this.participant,
    required this.name,
    required this.method,
    required this.amountMinor,
    required this.currency,
    required this.shares,
    required this.exactController,
    required this.percentController,
    required this.onExact,
    required this.onPercent,
    required this.onShares,
  });

  final bool first;
  final Map<String, dynamic> participant;
  final String name;
  final SplitMethod method;
  final int amountMinor;
  final String currency;
  final int shares;
  final TextEditingController exactController;
  final TextEditingController percentController;
  final ValueChanged<String> onExact;
  final ValueChanged<String> onPercent;
  final ValueChanged<int> onShares;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget? input;
    switch (method) {
      case SplitMethod.exact:
        input = _NumberField(
          controller: exactController,
          onChanged: onExact,
          hint: formatMoneyMinor(0, currency, showSymbol: false),
          semantics: 'bf_split_exact_for'.tr(namedArgs: {'name': name}),
          decimals: currencyDecimals(currency),
        );
      case SplitMethod.percent:
        input = _NumberField(
          controller: percentController,
          onChanged: onPercent,
          hint: '0',
          suffix: '%',
          semantics: 'bf_split_percent_for'.tr(namedArgs: {'name': name}),
          decimals: 2,
        );
      case SplitMethod.shares:
        input = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundIconButton(
              icon: AppIcons.remove,
              size: 36,
              label: 'bf_split_fewer_shares'.tr(namedArgs: {'name': name}),
              onTap: shares > 0 ? () => onShares(-1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$shares',
                textAlign: TextAlign.center,
                style: AppTypography.amount.copyWith(
                  fontSize: 16,
                  color: p.textPrimary,
                ),
              ),
            ),
            _RoundIconButton(
              icon: AppIcons.add,
              size: 36,
              label: 'bf_split_more_shares'.tr(namedArgs: {'name': name}),
              onTap: () => onShares(1),
            ),
          ],
        );
      case SplitMethod.equal:
      case SplitMethod.items:
        input = null;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Row(
        children: [
          PersonAvatar(participant: participant, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
          ?input,
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: MoneyText(
              minor: amountMinor,
              currency: currency,
              tone: MoneyTone.neutral,
              showSymbol: method == SplitMethod.equal,
              animate: true,
              animateFromZero: false,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.onChanged,
    required this.hint,
    required this.semantics,
    required this.decimals,
    this.suffix,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final String semantics;
  final int decimals;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 92,
      height: 44,
      child: Semantics(
        label: semantics,
        textField: true,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textAlign: TextAlign.end,
          keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: AppTypography.amount.copyWith(
            fontSize: 15,
            color: p.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            suffixText: suffix,
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.accent, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Material(
            color: p.surface,
            shape: CircleBorder(side: BorderSide(color: p.hairline)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: 18,
                  color: onTap == null ? p.textDisabled : p.textPrimary,
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
