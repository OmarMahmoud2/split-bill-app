import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/services/export_service.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

enum ExportScope { group, all, range }

enum ExportFormat { pdf, csv }

/// Pro export of bills as a PDF report or a CSV (Tools.dc.html "Export").
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    this.groupId,
    this.groupName,
    @visibleForTesting this.debugIsPro,
    @visibleForTesting this.debugLoadBills,
  });

  /// When set, the first option exports this group's bills (bills carrying
  /// a matching `groupId`).
  final String? groupId;
  final String? groupName;

  /// Skips the Firestore Pro check.
  final bool? debugIsPro;

  /// Replaces the Firestore bill query.
  final Future<List<ExportBill>> Function()? debugLoadBills;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late ExportScope _scope = widget.groupId != null
      ? ExportScope.group
      : ExportScope.all;
  ExportFormat _format = ExportFormat.pdf;
  bool _includeReceipts = true;
  DateTimeRange? _range;
  bool? _isPro;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPro();
  }

  Future<void> _loadPro() async {
    if (widget.debugIsPro != null) {
      setState(() => _isPro = widget.debugIsPro);
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(
          () => _isPro = RevenueCatService.isUserActivePremium(doc.data()),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isPro = false);
    }
  }

  String _fmtDate(DateTime d) =>
      DateFormat.yMMMd(context.locale.toString()).format(d);

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange:
          _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null && mounted) {
      setState(() {
        _range = picked;
        _scope = ExportScope.range;
      });
    }
  }

  Future<List<ExportBill>> _loadBills() async {
    if (widget.debugLoadBills != null) return widget.debugLoadBills!();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('bills')
        .where('participants_uids', arrayContains: user.uid)
        .get();
    return [
      for (final doc in snap.docs)
        ExportBill.fromFirestore(
          doc.id,
          doc.data(),
          uid: user.uid,
          fallbackTitle: 'exp_untitled'.tr(),
        ),
    ];
  }

  ExportLabels _labels(List<ExportBill> bills) {
    String period = '';
    if (_scope == ExportScope.range && _range != null) {
      period = 'exp_period'.tr(
        namedArgs: {
          'from': _fmtDate(_range!.start),
          'to': _fmtDate(_range!.end),
        },
      );
    } else if (bills.isNotEmpty) {
      final sorted = ExportService.sortBills(bills);
      period = 'exp_period'.tr(
        namedArgs: {
          'from': _fmtDate(sorted.last.date),
          'to': _fmtDate(sorted.first.date),
        },
      );
    }
    final title = _scope == ExportScope.group && widget.groupName != null
        ? widget.groupName!
        : 'exp_report_title'.tr();
    return ExportLabels(
      date: 'exp_col_date'.tr(),
      title: 'exp_col_title'.tr(),
      group: 'exp_col_group'.tr(),
      currency: 'exp_col_currency'.tr(),
      total: 'exp_col_total'.tr(),
      yourShare: 'exp_col_share'.tr(),
      status: 'exp_col_status'.tr(),
      paid: 'exp_paid'.tr(),
      unpaid: 'exp_unpaid'.tr(),
      reportTitle: title,
      totalsHeading: 'exp_totals'.tr(),
      billsHeading: 'exp_bills'.tr(),
      receiptsHeading: 'exp_receipt'.tr(),
      periodLabel: period,
      generatedLabel: 'exp_generated'.tr(
        namedArgs: {'date': _fmtDate(DateTime.now())},
      ),
    );
  }

  Future<pw.Font?> _font(String asset) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) {
      return null;
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_isPro != true) {
      AppHaptics.light();
      final upgraded = await PremiumModal.show(context);
      if (upgraded != true || !mounted) return;
      setState(() => _isPro = true);
    }
    if (_scope == ExportScope.range && _range == null) {
      await _pickRange();
      if (_range == null || !mounted) return;
    }
    final locale = context.locale.toString();
    final rtl = Directionality.of(context) == ui.TextDirection.rtl;
    setState(() => _busy = true);
    AppHaptics.light();
    try {
      var bills = await _loadBills();
      if (_scope == ExportScope.group) {
        bills = bills.where((b) => b.groupId == widget.groupId).toList();
      } else if (_scope == ExportScope.range) {
        bills = ExportService.inRange(bills, _range!.start, _range!.end);
      }
      if (!mounted) return;
      if (bills.isEmpty) {
        AppToast.show(context, message: 'exp_nothing'.tr());
        return;
      }
      final labels = _labels(bills);
      final stamp = isoDate(DateTime.now());
      final dir = await getTemporaryDirectory();
      late final File file;
      if (_format == ExportFormat.csv) {
        file = File('${dir.path}/split-bill-$stamp.csv');
        await file.writeAsString(ExportService.buildCsv(bills, labels));
      } else {
        final receipts = <String, Uint8List>{};
        if (_includeReceipts) {
          for (final b in bills) {
            final path = b.receiptPath;
            if (path == null) continue;
            final f = File(path);
            if (await f.exists()) receipts[b.id] = await f.readAsBytes();
          }
        }
        final bytes = await ExportService.buildPdf(
          bills: bills,
          labels: labels,
          formatAmount: (m, c) => formatMoneyMinor(m, c, locale: locale),
          formatDate: _fmtDate,
          receipts: receipts,
          font: await _font('assets/fonts/Inter/Inter-Regular.ttf'),
          boldFont: await _font('assets/fonts/Inter/Inter-Bold.ttf'),
          rtl: rtl,
        );
        file = File('${dir.path}/split-bill-$stamp.pdf');
        await file.writeAsBytes(bytes);
      }
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: labels.reportTitle,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'exp_done'.tr(),
        type: AppToastType.success,
      );
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'exp_failed'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 8),
    child: Text(
      text,
      style: AppTypography.titleSmall.copyWith(
        color: context.palette.textPrimary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rangeText = _range == null
        ? 'exp_pick_range'.tr()
        : 'exp_period'.tr(
            namedArgs: {
              'from': _fmtDate(_range!.start),
              'to': _fmtDate(_range!.end),
            },
          );
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            V3TopBar(
              leading: V3IconButton.back(context),
              title: 'exp_title'.tr(),
              trailing: _isPro == false ? const ProBadge() : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 24),
                children: [
                  _caption('exp_what'.tr()),
                  if (widget.groupId != null) ...[
                    V3RadioTile(
                      key: const ValueKey('exp-scope-group'),
                      selected: _scope == ExportScope.group,
                      onTap: () => setState(() => _scope = ExportScope.group),
                      child: Text(
                        'exp_group_all'.tr(
                          namedArgs: {'group': widget.groupName ?? ''},
                        ),
                        style: AppTypography.bodyLarge.copyWith(
                          color: p.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ] else
                    V3RadioTile(
                      key: const ValueKey('exp-scope-all'),
                      selected: _scope == ExportScope.all,
                      onTap: () => setState(() => _scope = ExportScope.all),
                      child: Text(
                        'exp_all_bills'.tr(),
                        style: AppTypography.bodyLarge.copyWith(
                          color: p.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  V3RadioTile(
                    key: const ValueKey('exp-scope-range'),
                    selected: _scope == ExportScope.range,
                    onTap: () {
                      setState(() => _scope = ExportScope.range);
                      if (_range == null) _pickRange();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'exp_range'.tr(),
                          style: AppTypography.bodyLarge.copyWith(
                            color: p.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (_scope == ExportScope.range)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _pickRange,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(rangeText),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _caption('exp_format'.tr()),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _FormatCard(
                          key: const ValueKey('exp-format-pdf'),
                          title: 'exp_pdf'.tr(),
                          subtitle: 'exp_pdf_sub'.tr(),
                          selected: _format == ExportFormat.pdf,
                          onTap: () =>
                              setState(() => _format = ExportFormat.pdf),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FormatCard(
                          key: const ValueKey('exp-format-csv'),
                          title: 'exp_csv'.tr(),
                          subtitle: 'exp_csv_sub'.tr(),
                          selected: _format == ExportFormat.csv,
                          onTap: () =>
                              setState(() => _format = ExportFormat.csv),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.durationFor(context, AppMotion.medium),
                    child: _format == ExportFormat.pdf
                        ? Padding(
                            key: const ValueKey('exp-receipts'),
                            padding: const EdgeInsets.only(top: 18),
                            child: SettingsCard(
                              margin: EdgeInsets.zero,
                              children: [
                                SettingsSwitchRow(
                                  title: 'exp_receipts_toggle'.tr(),
                                  subtitle: 'exp_receipts_note'.tr(),
                                  value: _includeReceipts,
                                  onChanged: (v) =>
                                      setState(() => _includeReceipts = v),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (_isPro == false) ...[
                    const SizedBox(height: 16),
                    Text(
                      'exp_pro_note'.tr(),
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('exp-create'),
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onInverseSurface,
                            semanticsLabel: 'exp_creating'.tr(),
                          ),
                        )
                      : Text(
                          _format == ExportFormat.pdf
                              ? 'exp_create_pdf'.tr()
                              : 'exp_create_csv'.tr(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: selected ? p.textPrimary : p.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: p.textSecondary,
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
