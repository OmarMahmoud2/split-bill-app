/// New group or trip: type, name, main currency, budget, dates, simplify
/// debts and members.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/screens/groups/group_detail_screen.dart';
import 'package:split_bill_app/screens/groups/member_picker.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, this.initialType = GroupType.trip});
  final GroupType initialType;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  late GroupType _type = widget.initialType;
  final _name = TextEditingController();
  final _budget = TextEditingController();
  String? _currency;
  DateTimeRange? _dates;
  bool _simplify = true;
  List<GroupMember> _members = [];
  bool _saving = false;
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _me ??= LedgerMe.current();
    if (_me != null && _members.isEmpty) _members = [_me!.asMember];
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  String get _code => _currency ?? normalizeCurrency(preferredCurrency(context));

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _dates,
    );
    if (r != null) setState(() => _dates = r);
  }

  Future<void> _create() async {
    final me = _me;
    final name = _name.text.trim();
    if (me == null || name.isEmpty) return;
    final budgetText = _budget.text.trim();
    final budget = budgetText.isEmpty ? null : parseAmountMinor(budgetText, _code);
    if (budgetText.isNotEmpty && budget == null) {
      AppToast.show(context, message: 'groups_budget_invalid'.tr(), type: AppToastType.warning);
      return;
    }
    setState(() => _saving = true);
    final String id;
    try {
      id = await LedgerRepository.instance.createGroup(
        GroupDraft(
          name: name,
          type: _type,
          currency: _code,
          members: _members,
          budgetMinor: budget,
          startDate: _dates?.start,
          endDate: _dates?.end,
          simplifyDebts: _simplify,
        ),
        creator: me.asMember,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(
        context,
        message: 'groups_create_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: _create,
      );
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await SuccessScreen.show<void>(
      nav.context,
      title: 'groups_created_title'.tr(namedArgs: {'name': name}),
      message: plainMemberCount(_members.length),
      primaryLabel: 'groups_invite_friends'.tr(),
      onPrimary: () => SharePlus.instance.share(
        ShareParams(
          text: 'groups_invite_text'.tr(
            namedArgs: {'name': me.name, 'group': name, 'link': AppLinks.appStoreUrl},
          ),
        ),
      ),
      secondaryLabel: 'groups_open_group'.tr(),
      onSecondary: () => nav.pushReplacement(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final df = DateFormat.MMMd(context.locale.toLanguageTag());
    final ready = _name.text.trim().isNotEmpty && !_saving;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            LedgerTopBar(title: 'groups_new_title'.tr(), close: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _label('groups_type'.tr()),
                  Row(
                    children: [
                      for (final t in GroupType.values) ...[
                        if (t != GroupType.values.first) const SizedBox(width: 8),
                        Expanded(
                          child: LedgerCard(
                            onTap: () {
                              AppHaptics.selection();
                              setState(() => _type = t);
                            },
                            borderColor: t == _type ? p.textPrimary : p.border,
                            borderWidth: t == _type ? 2 : AppRadii.hairline,
                            semanticsLabel: t.labelKey.tr(),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: ExcludeSemantics(
                              child: Column(
                                children: [
                                  Icon(groupTypeIcon(t), size: 20, color: p.textPrimary),
                                  const SizedBox(height: 4),
                                  Text(t.labelKey.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.labelMedium.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('groups_name'.tr()),
                  TextField(
                    controller: _name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'groups_name_hint_${_type.name}'.tr(), counterText: ''),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('groups_main_currency'.tr()),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: AppRadii.rowShape(p.borderStrong),
                                minimumSize: const Size.fromHeight(52),
                                alignment: AlignmentDirectional.centerStart,
                              ),
                              onPressed: () => CurrencySelectionSheet.show(
                                context: context,
                                selectedCode: _code,
                                onSelected: (c) => setState(() => _currency = normalizeCurrency(c)),
                              ),
                              child: Text(_code),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('groups_budget_optional'.tr()),
                            TextField(
                              controller: _budget,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: const InputDecoration(hintText: '0'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('groups_dates_optional'.tr()),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: AppRadii.rowShape(p.borderStrong),
                      minimumSize: const Size.fromHeight(52),
                      alignment: AlignmentDirectional.centerStart,
                    ),
                    onPressed: _pickDates,
                    child: Text(
                      _dates == null
                          ? 'groups_pick_dates'.tr()
                          : '${df.format(_dates!.start)} – ${df.format(_dates!.end)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  LedgerCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _simplify,
                      onChanged: (v) {
                        AppHaptics.selection();
                        setState(() => _simplify = v);
                      },
                      title: Text('groups_simplify_debts'.tr(), style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text('groups_simplify_debts_sub'.tr(), style: AppTypography.bodySmall.copyWith(color: p.textSecondary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('groups_members'.tr()),
                  MemberPickerField(
                    members: _members,
                    lockedIds: {?_me?.uid},
                    onChanged: (m) => setState(() => _members = m),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ready ? _create : null,
                  child: Text('groups_create_and_invite'.tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: AppTypography.labelMedium.copyWith(color: context.palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

IconData groupTypeIcon(GroupType t) => switch (t) {
  GroupType.trip => Icons.flight_takeoff_rounded,
  GroupType.home => Icons.home_rounded,
  GroupType.couple => Icons.favorite_rounded,
  GroupType.other => Icons.group_rounded,
};

String plainMemberCount(int n) => n == 1
    ? 'groups_one_person'.tr()
    : 'groups_n_people'.tr(namedArgs: {'count': '$n'});
