import 'package:split_bill_app/widgets/layout/app_background.dart';
import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/services/analytics_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/bill_flow/share_links.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';
import 'package:url_launcher/url_launcher.dart';

/// One person to send a link to.
class ShareTarget {
  const ShareTarget({
    required this.id,
    required this.name,
    required this.shareMinor,
    this.photoUrl,
    this.phoneNumber,
    this.isHost = false,
    this.isAppUser = false,
  });

  final String id;
  final String name;
  final int shareMinor;
  final String? photoUrl;
  final String? phoneNumber;
  final bool isHost;

  /// Has the app: already notified there.
  final bool isAppUser;

  Map<String, dynamic> get asParticipant => {
    'id': id,
    'name': name,
    'photoUrl': photoUrl,
  };
}

/// "Mona, your share is EGP 16.38" + the personal link. Pure, for tests.
String personalShareText({
  required ShareTarget target,
  required String billId,
  required String currency,
  required String store,
  String Function(String key, Map<String, String> args)? tr,
}) {
  final t = tr ?? (k, a) => k.tr(namedArgs: a);
  final amount = formatMoneyMinor(target.shareMinor, currency);
  final link = personalBillUrl(billId, participantId: target.id);
  final first = target.name.trim().split(RegExp(r'\s+')).first;
  return t('bf_share_person_text', {
    'name': first,
    'amount': amount,
    'store': store,
    'link': link,
  });
}

/// The group-chat message: one line per person plus the table link.
String groupShareText({
  required List<ShareTarget> targets,
  required String billId,
  required String currency,
  required String store,
  String Function(String key, Map<String, String> args)? tr,
}) {
  final t = tr ?? (k, a) => k.tr(namedArgs: a);
  final lines = [
    t('bf_share_group_title', {'store': store}),
    for (final p in targets.where((p) => !p.isHost))
      t('bf_share_group_line', {
        'name': p.name,
        'amount': formatMoneyMinor(p.shareMinor, currency),
        'link': personalBillUrl(billId, participantId: p.id),
      }),
  ];
  return lines.join('\n');
}

/// Share step after saving (Split.dc.html, last board): a personal link
/// per person (WhatsApp / Messages / copy), and one QR for the table.
class BillShareScreen extends StatelessWidget {
  const BillShareScreen({
    super.key,
    required this.billId,
    required this.storeName,
    required this.currency,
    required this.targets,
    this.onDone,
  });

  final String billId;
  final String storeName;
  final String currency;
  final List<ShareTarget> targets;

  /// Defaults to popping to the first route.
  final VoidCallback? onDone;

  List<ShareTarget> get _others => targets.where((t) => !t.isHost).toList();

  Future<void> _open(BuildContext context, Uri uri, String text) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok) {
      AppHaptics.light();
      AnalyticsService.instance.billShared('link');
      return;
    }
    if (!context.mounted) return;
    await _share(context, text);
  }

  Future<void> _share(BuildContext context, String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      AnalyticsService.instance.billShared('system_share');
    } catch (_) {
      if (!context.mounted) return;
      await _copy(context, text);
    }
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    AnalyticsService.instance.billShared('link');
    AppHaptics.success();
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: 'bf_share_copied'.tr(),
      type: AppToastType.success,
    );
  }

  void _send(BuildContext context, ShareTarget t) {
    final text = personalShareText(
      target: t,
      billId: billId,
      currency: currency,
      store: storeName,
    );
    final phone = t.phoneNumber?.trim() ?? '';
    if (phone.isNotEmpty) {
      _open(context, whatsAppUri(text, phone: phone), text);
    } else {
      _share(context, text);
    }
  }

  void _message(BuildContext context, ShareTarget t) {
    final text = personalShareText(
      target: t,
      billId: billId,
      currency: currency,
      store: storeName,
    );
    _open(context, smsUri(text, phone: t.phoneNumber), text);
  }

  void _openGroupMessage(BuildContext context) {
    final text = groupShareText(
      targets: targets,
      billId: billId,
      currency: currency,
      store: storeName,
    );
    _open(context, smsUri(text), text);
  }

  void _showQr(BuildContext context) {
    final p = context.palette;
    final url = personalBillUrl(billId);
    AppHaptics.light();
    showLedgerSheet<void>(
      context,
      title: 'bf_share_qr_title'.tr(),
      subtitle: 'bf_share_qr_body'.tr(),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              image: true,
              label: 'bf_share_qr_semantics'.tr(),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  // QR codes must stay dark-on-light to scan.
                  color: AppPalette.light.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: p.hairline),
                ),
                child: QrImageView(
                  data: url,
                  size: 220,
                  backgroundColor: AppPalette.light.surface,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppPalette.light.textPrimary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppPalette.light.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AssignPillButton(
              label: 'bf_share_copy_link'.tr(),
              secondary: true,
              onPressed: () => _copy(ctx, url),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final others = _others;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AdaptiveBody.form(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      40,
                      20,
                      16,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.successFill,
                            color: p.accent,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'bf_share_title'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMedium.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'bf_share_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 15,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: ShareOptionTile(
                              key: const ValueKey('share_tile_message'),
                              glyph: AppIcons.messageDuo,
                              label: 'bf_share_tile_message'.tr(),
                              onTap: () => _openGroupMessage(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ShareOptionTile(
                              key: const ValueKey('share_tile_copy'),
                              glyph: AppIcons.linkDuo,
                              label: 'bf_share_copy_link'.tr(),
                              onTap: () =>
                                  _copy(context, personalBillUrl(billId)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ShareOptionTile(
                              key: const ValueKey('share_qr_card'),
                              glyph: AppIcons.qrDuo,
                              label: 'bf_share_tile_qr'.tr(),
                              onTap: () => _showQr(context),
                            ),
                          ),
                        ],
                      ),
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 4,
                            bottom: 10,
                          ),
                          child: Row(
                            children: [
                              AppDuoIcon(
                                AppIcons.sendDuo,
                                size: 20,
                                color: p.accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'bf_share_tile_each'.tr(),
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (others.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: AppRadii.cardRadius,
                            border: Border.all(color: p.hairline),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < others.length; i++)
                                StaggeredEntrance(
                                  index: i,
                                  child: ShareTargetRow(
                                    key: ValueKey('share_row_${others[i].id}'),
                                    target: others[i],
                                    currency: currency,
                                    first: i == 0,
                                    onSend: () => _send(context, others[i]),
                                    onMessage: () =>
                                        _message(context, others[i]),
                                    onCopy: () => _copy(
                                      context,
                                      personalBillUrl(
                                        billId,
                                        participantId: others[i].id,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (others.isNotEmpty)
                        AssignPillButton(
                          key: const ValueKey('share_all'),
                          label: 'bf_share_all'.tr(),
                          onPressed: () => _share(
                            context,
                            groupShareText(
                              targets: targets,
                              billId: billId,
                              currency: currency,
                              store: storeName,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: TextButton(
                          key: const ValueKey('share_done'),
                          onPressed:
                              onDone ??
                              () => Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst),
                          style: TextButton.styleFrom(
                            foregroundColor: p.textPrimary,
                          ),
                          child: Text(
                            'bf_share_done'.tr(),
                            style: AppTypography.labelLarge.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
    );
  }
}

class ShareTargetRow extends StatelessWidget {
  const ShareTargetRow({
    super.key,
    required this.target,
    required this.currency,
    required this.first,
    required this.onSend,
    required this.onMessage,
    required this.onCopy,
  });

  final ShareTarget target;
  final String currency;
  final bool first;
  final VoidCallback onSend;
  final VoidCallback onMessage;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasPhone = (target.phoneNumber?.trim() ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Row(
        children: [
          PersonAvatar(participant: target.asParticipant, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    MoneyText(
                      minor: target.shareMinor,
                      currency: currency,
                      tone: MoneyTone.neutral,
                      size: MoneySize.small,
                      style: TextStyle(color: p.textSecondary),
                    ),
                    if (target.isAppUser) ...[
                      Text(' · ', style: TextStyle(color: p.textSecondary)),
                      Flexible(
                        child: Text(
                          'bf_share_notified'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: Center(
              child: FilledButton(
                onPressed: hasPhone ? onSend : onMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: p.inverseSurface,
                  foregroundColor: p.onInverseSurface,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.labelMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  hasPhone ? 'bf_share_whatsapp'.tr() : 'bf_share_message'.tr(),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'bf_share_copy_link'.tr(),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(AppIcons.link, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A big option tile on the share screen: duotone icon in a mint tile, label.
class ShareOptionTile extends StatelessWidget {
  const ShareOptionTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final AppDuoGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AppDuoIcon(glyph, size: 26, color: p.accent),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
