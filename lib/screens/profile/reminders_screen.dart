import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/reminder_prefs.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
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
    final result = await showLedgerSheet<(int, int)>(
      context,
      title: 'rem_when'.tr(),
      subtitle: 'rem_when_sub'.tr(),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              SizedBox(
                height: 150,
                child: _TimeWheel(
                  key: const ValueKey('rem-hour'),
                  initial: TimeOfDay(hour: hour, minute: 0),
                  onChanged: (t) => hour = t.hour,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('rem-when-done'),
                onPressed: () => Navigator.of(context).pop((weekday, hour)),
                child: Text('rem_done'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _update(prefs.copyWith(weekday: result.$1, hour: result.$2));
  }

  Future<TimeOfDay?> _pickTime(String title, ClockTime initial) {
    var value = TimeOfDay(hour: initial.hour, minute: initial.minute);
    return showLedgerSheet<TimeOfDay>(
      context,
      title: title,
      builder: (context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 170,
              child: _TimeWheel(initial: value, onChanged: (t) => value = t),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(value),
              child: Text('rem_done'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickQuietHours(ReminderPrefs prefs) async {
    final q = prefs.quietHours;
    final start = await _pickTime('rem_quiet_start'.tr(), q.start);
    if (start == null || !mounted) return;
    final end = await _pickTime('rem_quiet_end'.tr(), q.end);
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

  Widget _tile(BuildContext context, IconData icon) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: p.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: AdaptiveBody.form(
        child: SafeArea(
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
              leading: _tile(context, AppIcons.bell),
              title: 'rem_nudge'.tr(),
              subtitle: 'rem_nudge_sub'.tr(),
              value: prefs.enabled,
              onChanged: (v) => _update(prefs.copyWith(enabled: v)),
            ),
            SettingsRow(
              key: const ValueKey('rem-when'),
              leading: _tile(context, AppIcons.clock),
              title: 'rem_when'.tr(),
              subtitle: 'rem_when_sub'.tr(),
              value: prefs.summary(offLabel: 'rem_off'.tr(), locale: _locale),
              onTap: prefs.enabled ? () => _pickWhen(prefs) : null,
              showChevron: false,
            ),
            SettingsSwitchRow(
              key: const ValueKey('rem-trip'),
              leading: _tile(context, AppIcons.calendar),
              title: 'rem_trip_end'.tr(),
              subtitle: 'rem_trip_end_sub'.tr(),
              value: prefs.tripEndPrompt,
              onChanged: (v) => _update(prefs.copyWith(tripEndPrompt: v)),
            ),
            SettingsSwitchRow(
              key: const ValueKey('rem-monthly'),
              leading: _tile(context, AppIcons.chart),
              title: 'rem_monthly'.tr(),
              subtitle: 'rem_monthly_sub'.tr(),
              value: prefs.monthlySummary,
              onChanged: (v) => _update(prefs.copyWith(monthlySummary: v)),
            ),
            SettingsRow(
              key: const ValueKey('rem-quiet'),
              leading: _tile(context, AppIcons.moon),
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
                    child: Icon(AppIcons.bell, size: 20, color: p.onAccent),
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

/// Wheel time picker (iOS-style on every platform), themed from the palette.
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({super.key, required this.initial, required this.onChanged});

  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: p.isDark ? Brightness.dark : Brightness.light,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: TextStyle(
              fontFamily: AppTypography.displayFamily,
              fontSize: 21,
              color: p.textPrimary,
            ),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
          onDateTimeChanged: (d) =>
              onChanged(TimeOfDay(hour: d.hour, minute: d.minute)),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
