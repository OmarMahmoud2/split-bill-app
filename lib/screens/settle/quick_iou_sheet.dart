/// Quick IOU: "Ali owes me 20, no bill needed".
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/screens/groups/member_picker.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// Parses "20", "20.5" or "20,50" into minor units; null when invalid or
/// not positive.
int? parseAmountMinor(String text, String currency) {
  final cleaned = text.trim().replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite || v <= 0) return null;
  final minor = toMinorUnits(v, currency);
  return minor > 0 ? minor : null;
}

Future<bool?> showQuickIouSheet(
  BuildContext context, {
  required List<GroupMember> people,
  GroupMember? initialPerson,
}) => showLedgerSheet<bool>(
  context,
  builder: (_) => QuickIouSheet(people: people, initialPerson: initialPerson),
);

class QuickIouSheet extends StatefulWidget {
  const QuickIouSheet({super.key, required this.people, this.initialPerson});

  /// People to pick from (friends with a balance, group members).
  final List<GroupMember> people;
  final GroupMember? initialPerson;

  @override
  State<QuickIouSheet> createState() => _QuickIouSheetState();
}

class _QuickIouSheetState extends State<QuickIouSheet> {
  bool _theyOweMe = true;
  late final List<GroupMember> _people = [
    ?widget.initialPerson,
    ...widget.people.where((p) => p.id != widget.initialPerson?.id),
  ];
  late GroupMember? _person = widget.initialPerson;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _currency;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _code => _currency ?? normalizeCurrency(preferredCurrency(context));

  Future<void> _addPerson() async {
    final m = await pickMemberFromContacts(context);
    if (m == null || !mounted) return;
    setState(() {
      if (!_people.any((p) => p.id == m.id)) _people.insert(0, m);
      _person = _people.firstWhere((p) => p.id == m.id);
    });
  }

  Future<void> _save() async {
    final me = LedgerMe.current();
    final person = _person;
    final minor = parseAmountMinor(_amount.text, _code);
    if (me == null || person == null || minor == null) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    final iou = PaymentRecord(
      id: '',
      kind: PaymentKind.iou,
      from: _theyOweMe ? person.id : me.uid,
      to: _theyOweMe ? me.uid : person.id,
      fromName: _theyOweMe ? person.name : me.name,
      toName: _theyOweMe ? me.name : person.name,
      amountMinor: minor,
      currency: _code,
      method: 'iou',
      note: note.isEmpty ? null : note,
      createdBy: me.uid,
    );
    try {
      await LedgerRepository.instance.recordPayment(iou);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(
        context,
        message: 'iou_save_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: _save,
      );
      return;
    }
    if (!mounted) return;
    final amount = moneyLabel(context, minor, _code);
    AppToast.show(
      context,
      message: _theyOweMe
          ? 'iou_saved_they_owe'.tr(namedArgs: {'name': person.name, 'amount': amount})
          : 'iou_saved_i_owe'.tr(namedArgs: {'name': person.name, 'amount': amount}),
      type: AppToastType.success,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final minor = parseAmountMinor(_amount.text, _code);
    final person = _person;
    final ready = person != null && minor != null && !_saving;
    final amount = minor == null ? '' : moneyLabel(context, minor, _code);
    final cta = person == null || minor == null
        ? 'iou_save'.tr()
        : _theyOweMe
        ? 'iou_cta_they_owe'.tr(namedArgs: {'name': person.name, 'amount': amount})
        : 'iou_cta_i_owe'.tr(namedArgs: {'name': person.name, 'amount': amount});

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('iou_title'.tr(), style: AppTypography.headlineSmall.copyWith(color: p.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          LedgerSegmented<bool>(
            segments: [(true, 'iou_they_owe_me'.tr()), (false, 'iou_i_owe_them'.tr())],
            selected: _theyOweMe,
            onChanged: (v) => setState(() => _theyOweMe = v),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in _people)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Semantics(
                      button: true,
                      selected: m.id == person?.id,
                      label: m.name,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _person = m);
                        },
                        child: SizedBox(
                          width: 60,
                          child: Column(
                            children: [
                              m.id == person?.id
                                  ? AvatarHop(child: LedgerAvatar(id: m.id, name: m.name, photoUrl: m.photoUrl, size: 48, selected: true))
                                  : LedgerAvatar(id: m.id, name: m.name, photoUrl: m.photoUrl, size: 52),
                              const SizedBox(height: 4),
                              Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: 'iou_add_person'.tr(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _addPerson,
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.borderStrong)),
                            child: Icon(Icons.person_add_alt_rounded, color: p.textPrimary, size: 22),
                          ),
                          const SizedBox(height: 4),
                          Text('iou_add_short'.tr(), maxLines: 1, style: AppTypography.caption.copyWith(color: p.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => CurrencySelectionSheet.show(
                  context: context,
                  selectedCode: _code,
                  onSelected: (c) => setState(() => _currency = normalizeCurrency(c)),
                ),
                child: Text(_code, semanticsLabel: 'iou_change_currency'.tr(namedArgs: {'code': _code})),
              ),
              IntrinsicWidth(
                child: TextField(
                  controller: _amount,
                  autofocus: false,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  textAlign: TextAlign.center,
                  style: AppTypography.amountHero.copyWith(color: p.textPrimary, fontSize: 48),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintStyle: AppTypography.amountHero.copyWith(color: p.textDisabled, fontSize: 48),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          TextField(
            controller: _note,
            maxLength: 200,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'iou_note_hint'.tr(),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: ready ? _save : null, child: Text(cta)),
        ],
      ),
    );
  }
}
