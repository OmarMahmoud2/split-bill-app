import 'package:split_bill_app/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/domain/money.dart' as domain;
import 'package:split_bill_app/domain/split_methods.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/services/recurring_bill_service.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// A group the user can attach a recurring bill to.
class RecurringGroupOption {
  const RecurringGroupOption({
    required this.id,
    required this.name,
    required this.members,
  });

  final String id;
  final String name;

  /// Member id -> display name, in group order.
  final Map<String, String> members;

  factory RecurringGroupOption.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    String? currentUid,
    String youLabel = 'You',
  }) {
    final members = <String, String>{};
    final list = data['members'];
    if (list is List) {
      for (final m in list) {
        if (m is Map && m['id'] != null) {
          final mid = m['id'].toString();
          members[mid] = mid == currentUid
              ? youLabel
              : (m['name']?.toString() ?? '');
        }
      }
    }
    final ids = data['memberIds'];
    if (ids is List) {
      for (final mid in ids) {
        members.putIfAbsent(
          mid.toString(),
          () => mid.toString() == currentUid ? youLabel : '',
        );
      }
    }
    return RecurringGroupOption(
      id: id,
      name: data['name']?.toString() ?? '',
      members: members,
    );
  }
}

/// Parses a typed amount ("12,600.50", "12600,5") into minor units; null
/// when empty or invalid.
int? parseAmountMinor(String text, String currency) {
  var t = text.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  final lastComma = t.lastIndexOf(',');
  final lastDot = t.lastIndexOf('.');
  if (lastComma > lastDot) {
    // Comma is the decimal separator ("12.600,50" or "12600,5").
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '');
  }
  final value = double.tryParse(t);
  if (value == null || value <= 0) return null;
  try {
    return domain.toMinorUnits(value, currency);
  } catch (_) {
    return null;
  }
}

/// Pro: set up a bill that repeats weekly, monthly or yearly for a group.
class RecurringBillScreen extends StatefulWidget {
  const RecurringBillScreen({
    super.key,
    this.groupId,
    @visibleForTesting this.debugIsPro,
    @visibleForTesting this.debugGroups,
    @visibleForTesting this.debugSave,
  });

  /// Preselects this group.
  final String? groupId;

  final bool? debugIsPro;
  final List<RecurringGroupOption>? debugGroups;
  final Future<void> Function(String groupId, RecurringBillTemplate t)?
  debugSave;

  @override
  State<RecurringBillScreen> createState() => _RecurringBillScreenState();
}

class _RecurringBillScreenState extends State<RecurringBillScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  late DateTime _nextOn;
  String _currency = 'USD';
  List<RecurringGroupOption>? _groups;
  bool _groupsFailed = false;
  String? _groupId;
  bool? _isPro;
  bool _saving = false;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nextOn = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    _groupId = widget.groupId;
    try {
      _currency = Provider.of<AppSettingsProvider>(
        context,
        listen: false,
      ).currencyCode;
    } catch (_) {}
    _amount.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _groupsFailed = false);
    if (widget.debugGroups != null) {
      setState(() {
        _groups = widget.debugGroups;
        _isPro = widget.debugIsPro ?? true;
        _groupId ??= _groups!.isEmpty ? null : _groups!.first.id;
      });
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('signed out');
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db
            .collection('groups')
            .where('memberIds', arrayContains: user.uid)
            .get(),
        db.collection('users').doc(user.uid).get(),
      ]);
      final groups = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final userDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _groups = [
          for (final d in groups.docs)
            RecurringGroupOption.fromFirestore(
              d.id,
              d.data(),
              currentUid: user.uid,
              youLabel: 'rec_you'.tr(),
            ),
        ];
        _isPro = RevenueCatService.isUserActivePremium(userDoc.data());
        if (_groupId == null || !_groups!.any((g) => g.id == _groupId)) {
          _groupId = _groups!.isEmpty ? null : _groups!.first.id;
        }
      });
    } catch (e) {
      debugPrint('Recurring setup load failed: $e');
      if (mounted) setState(() => _groupsFailed = true);
    }
  }

  RecurringGroupOption? get _group {
    for (final g in _groups ?? const <RecurringGroupOption>[]) {
      if (g.id == _groupId) return g;
    }
    return null;
  }

  String _thenEvery() {
    final locale = context.locale.toString();
    return switch (_frequency) {
      RecurringFrequency.weekly => 'rec_then_weekly'.tr(
        namedArgs: {'weekday': DateFormat.EEEE(locale).format(_nextOn)},
      ),
      RecurringFrequency.monthly => 'rec_then_monthly'.tr(
        namedArgs: {'day': '${_nextOn.day}'},
      ),
      RecurringFrequency.yearly => 'rec_then_yearly'.tr(
        namedArgs: {'date': DateFormat.MMMd(locale).format(_nextOn)},
      ),
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextOn,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      AppHaptics.selection();
      setState(() => _nextOn = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_isPro != true) {
      final upgraded = await PremiumModal.show(context, placement: 'recurring');
      if (upgraded != true || !mounted) return;
      setState(() => _isPro = true);
    }
    final user = widget.debugSave == null
        ? FirebaseAuth.instance.currentUser
        : null;
    final group = _group;
    final template = RecurringBillTemplate(
      name: _name.text,
      amountMinor: parseAmountMinor(_amount.text, _currency) ?? 0,
      currency: _currency,
      frequency: _frequency,
      nextOn: _nextOn,
      createdBy: user?.uid ?? 'test',
      memberIds: group?.members.keys.toList() ?? const [],
    );
    final errors = template.validate();
    setState(() {
      _errors
        ..clear()
        ..addAll({for (final e in errors) e: e.tr()});
    });
    if (errors.isNotEmpty || group == null) {
      AppHaptics.error();
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.debugSave != null) {
        await widget.debugSave!(group.id, template);
      } else {
        await RecurringBillService().save(group.id, template);
      }
      AnalyticsService.instance.recurringCreated();
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'rec_saved'.tr(),
        type: AppToastType.success,
      );
      Navigator.of(context).maybePop(true);
    } on FirebaseException catch (e) {
      debugPrint('Recurring save failed: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        message: e.code == 'permission-denied'
            ? 'rec_not_available'.tr()
            : 'rec_save_error'.tr(),
        type: AppToastType.error,
      );
    } catch (e) {
      debugPrint('Recurring save failed: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'rec_save_error'.tr(),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _splitPreview() {
    final p = context.palette;
    final group = _group;
    final minor = parseAmountMinor(_amount.text, _currency) ?? 0;
    if (group == null || group.members.isEmpty) return const SizedBox.shrink();
    final shares = splitEqually(minor, group.members.keys.toList());
    return SettingsCard(
      margin: EdgeInsets.zero,
      divided: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'rec_split_caption'.tr(),
              style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
        ),
        for (final entry in group.members.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.value.isEmpty ? 'rec_member'.tr() : entry.value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                MoneyText(
                  minor: shares[entry.key] ?? 0,
                  currency: _currency,
                  tone: MoneyTone.neutral,
                  size: MoneySize.small,
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final locale = context.locale.toString();
    Widget body;
    if (_groupsFailed) {
      body = ErrorState(onRetry: _load);
    } else if (_groups == null) {
      body = const SkeletonShimmer(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [SkeletonCard(), SkeletonCard()]),
        ),
      );
    } else if (_groups!.isEmpty) {
      body = EmptyState(
        icon: Icons.group_outlined,
        title: 'rec_no_groups_title'.tr(),
        message: 'rec_no_groups_message'.tr(),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          V3FieldLabel('rec_name'.tr()),
          TextField(
            key: const ValueKey('rec-name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'rec_name_hint'.tr(),
              errorText: _errors['rec_error_name'],
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    V3FieldLabel('rec_amount'.tr()),
                    TextField(
                      key: const ValueKey('rec-amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: AppTypography.amount.copyWith(
                        color: p.textPrimary,
                      ),
                      decoration: InputDecoration(
                        errorText: _errors['rec_error_amount'],
                        prefixIcon: TextButton(
                          onPressed: () => CurrencySelectionSheet.show(
                            context: context,
                            selectedCode: _currency,
                            onSelected: (code) =>
                                setState(() => _currency = code),
                          ),
                          child: Text(
                            _currency,
                            semanticsLabel: 'rec_currency_a11y'.tr(
                              namedArgs: {'currency': _currency},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    V3FieldLabel('rec_group'.tr()),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('rec-group'),
                      initialValue: _groupId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        errorText: _errors['rec_error_group'],
                      ),
                      items: [
                        for (final g in _groups!)
                          DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          V3FieldLabel('rec_repeats'.tr()),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in RecurringFrequency.values)
                V3ChoiceChip(
                  key: ValueKey('rec-freq-${f.id}'),
                  label: 'rec_freq_${f.id}'.tr(),
                  selected: f == _frequency,
                  onTap: () => setState(() => _frequency = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          V3FieldLabel('rec_next_on'.tr()),
          Material(
            color: p.surface,
            shape: AppRadii.rowShape(p.border),
            child: InkWell(
              key: const ValueKey('rec-next-on'),
              borderRadius: AppRadii.rowRadius,
              onTap: _pickDate,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat.yMMMd(locale).format(_nextOn)}, ${_thenEvery()}',
                          style: AppTypography.bodyLarge.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: p.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _splitPreview(),
        ],
      );
    }

    final canSave = _groups != null && _groups!.isNotEmpty;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            V3TopBar(
              leading: V3IconButton.close(context),
              title: 'rec_title'.tr(),
              trailing: const ProBadge(),
            ),
            Expanded(child: body),
            if (canSave)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('rec-save'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onInverseSurface,
                            ),
                          )
                        : Text('rec_save'.tr()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
