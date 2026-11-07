import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/reminder_prefs.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// "Reminders you control": friendly nudges, trip-end prompt, monthly
/// summary and quiet hours, saved to `users/{uid}.reminderPrefs` on every
/// change.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    this.currencyCode = 'USD',
    @visibleForTesting this.debugLoad,
    @visibleForTesting this.debugSave,
    @visibleForTesting this.debugUserName,
  });

  /// Used for the sample amount in the preview.
  final String currencyCode;
  final Future<ReminderPrefs> Function()? debugLoad;
  final Future<void> Function(ReminderPrefs prefs)? debugSave;
  final String? debugUserName;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderPrefs? _prefs;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final prefs = await (widget.debugLoad ?? ReminderPrefsService.load)();
      if (mounted) setState(() => _prefs = prefs);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _update(ReminderPrefs next) async {
    final previous = _prefs;
    if (previous == null || previous == next) return;
    setState(() => _prefs = next);
    try {
      await (widget.debugSave ?? ReminderPrefsService.save)(next);
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'rem_saved'.tr(),
        type: AppToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      AppToast.show(
        context,
        message: 'rem_save_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  String get _locale => context.locale.toLanguageTag();

  Future<void> _pickWhen(ReminderPrefs prefs) async {
    var weekday = prefs.weekday;
    var hour = prefs.hour;
    final result = await PremiumBottomSheet.show<(int, int)>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setSheet) {
          final p = context.palette;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'rem_when'.tr(),
                style: AppTypography.headlineMedium.copyWith(
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'rem_when_sub'.tr(),
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              V3FieldLabel('rem_day'.tr()),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    V3ChoiceChip(
                      key: ValueKey('rem-day-$d'),
                      label: ReminderPrefs.weekdayLabel(d, locale: _locale),
                      selected: d == weekday,
                      onTap: () => setSheet(() => weekday = d),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              V3FieldLabel('rem_time'.tr()),
              OutlinedButton(
                key: const ValueKey('rem-hour'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: hour, minute: 0),
                  );
                  if (picked != null) setSheet(() => hour = picked.hour);
                },
                child: Text(ReminderPrefs.hourLabel(hour, locale: _locale)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('rem-when-done'),
                onPressed: () => Navigator.of(context).pop((weekday, hour)),
                child: Text('rem_done'.tr()),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    await _update(prefs.copyWith(weekday: result.$1, hour: result.$2));
  }

  Future<void> _pickQuietHours(ReminderPrefs prefs) async {
    final q = prefs.quietHours;
    final start = await showTimePicker(
      context: context,
      helpText: 'rem_quiet_start'.tr(),
      initialTime: TimeOfDay(hour: q.start.hour, minute: q.start.minute),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'rem_quiet_end'.tr(),
      initialTime: TimeOfDay(hour: q.end.hour, minute: q.end.minute),
    );
    if (end == null || !mounted) return;
    await _update(
      prefs.copyWith(
        quietHours: QuietHours(
          start: ClockTime(start.hour, start.minute),
          end: ClockTime(end.hour, end.minute),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V3TopBar(
              title: 'rem_title'.tr(),
              leading: V3IconButton.back(context),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loadError != null) {
      return ErrorState(onRetry: _load);
    }
    final prefs = _prefs;
    if (prefs == null) {
      return const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
        child: SkeletonShimmer(
          child: Column(
            children: [
              SkeletonCard(lines: [0.7, 0.5, 0.8, 0.6]),
            ],
          ),
        ),
      );
    }
    final p = context.palette;
    final name =
        widget.debugUserName ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'user'.tr();
    return ListView(
      padding: const EdgeInsets.only(top: 18, bottom: 40),
      children: [
        SettingsCard(
          children: [
            SettingsSwitchRow(
              key: const ValueKey('rem-enabled'),
              title: 'rem_nudge'.tr(),
              subtitle: 'rem_nudge_sub'.tr(),
              value: prefs.enabled,
              onChanged: (v) => _update(prefs.copyWith(enabled: v)),
            ),
            SettingsRow(
              key: const ValueKey('rem-when'),
              title: 'rem_when'.tr(),
              subtitle: 'rem_when_sub'.tr(),
              value: prefs.summary(offLabel: 'rem_off'.tr(), locale: _locale),
              onTap: prefs.enabled ? () => _pickWhen(prefs) : null,
              showChevron: false,
            ),
            SettingsSwitchRow(
              key: const ValueKey('rem-trip'),
              title: 'rem_trip_end'.tr(),
              subtitle: 'rem_trip_end_sub'.tr(),
              value: prefs.tripEndPrompt,
              onChanged: (v) => _update(prefs.copyWith(tripEndPrompt: v)),
            ),
            SettingsSwitchRow(
              key: const ValueKey('rem-monthly'),
              title: 'rem_monthly'.tr(),
              subtitle: 'rem_monthly_sub'.tr(),
              value: prefs.monthlySummary,
              onChanged: (v) => _update(prefs.copyWith(monthlySummary: v)),
            ),
            SettingsRow(
              key: const ValueKey('rem-quiet'),
              title: 'rem_quiet'.tr(),
              subtitle: 'rem_quiet_sub'.tr(),
              value: prefs.quietHours.label,
              onTap: () => _pickQuietHours(prefs),
              showChevron: false,
            ),
          ],
        ),
        SettingsSectionLabel('rem_preview'.tr()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            container: true,
            label: 'rem_preview'.tr(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: p.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      AppIcons.bell,
                      size: 20,
                      color: p.onAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'rem_preview_title'.tr(
                            namedArgs: {
                              'name': name,
                              'amount': formatMoneyMinor(
                                4100,
                                widget.currencyCode,
                              ),
                            },
                          ),
                          style: AppTypography.labelMedium.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          'rem_preview_body'.tr(),
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
