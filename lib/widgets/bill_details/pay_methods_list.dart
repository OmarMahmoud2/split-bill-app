import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// One "PAY OMAR WITH" row: a stored method resolved against the registry
/// and the launch built for this participant's share.
class PayMethodEntry {
  const PayMethodEntry({required this.method, required this.launch});

  final StoredPaymentMethod method;
  final PaymentLaunch launch;

  PaymentMethodType get type => method.type;
  String get name => method.label;
  String get initials => type.initials;

  /// The provider opens with the amount already filled in.
  bool get prefillsAmount {
    final l = launch;
    return l is DeepLinkLaunch && l.prefillsAmount;
  }

  /// Same method and handle (entries are rebuilt on every frame).
  bool sameAs(PayMethodEntry other) =>
      type.id == other.type.id && handle == other.handle;

  /// What the payer needs if the app does not open: the stored handle.
  String get handle => method.value.trim();
}

/// Builds the rows for paying [shareMinor] of [currency] with the host's
/// saved [methods]. Methods that cannot work on [platform] (Apple Cash off
/// iOS) are left out; duplicates (same type and handle) are merged.
List<PayMethodEntry> buildPayMethodEntries({
  required List<StoredPaymentMethod> methods,
  required int shareMinor,
  required String currency,
  String? note,
  String? recipientName,
  String? message,
  PaymentPlatform? platform,
}) {
  final seen = <String>{};
  final out = <PayMethodEntry>[];
  for (final m in methods) {
    if (m.value.trim().isEmpty) continue;
    if (platform != null && !m.type.isAvailableOn(platform)) continue;
    if (!seen.add('${m.type.id}|${m.value.trim().toLowerCase()}')) continue;
    final launch = m.type.buildLaunch(
      PaymentRequest(
        handle: m.value,
        amount: shareMinor > 0 ? Money(shareMinor, currency) : null,
        note: note,
        recipientName: recipientName,
        message: message,
      ),
    );
    out.add(PayMethodEntry(method: m, launch: launch));
  }
  return out;
}

/// The host's methods: their public profile first (current), else the
/// `paymentMethods` map copied onto the bill when it was created.
List<StoredPaymentMethod> payMethodsFor({
  Map<String, dynamic>? hostProfile,
  Map<String, dynamic>? bill,
}) {
  final fromProfile = parseStoredPaymentMethods(hostProfile);
  if (fromProfile.isNotEmpty) return fromProfile;
  final map = bill?['paymentMethods'];
  if (map is Map) return parseBillPaymentMethods(map);
  final list = bill?['customPaymentMethods'];
  if (list is List) {
    return parseStoredPaymentMethods({'customPaymentMethods': list});
  }
  return const [];
}

/// The "PAY OMAR WITH" card. Presentational: [onOpen] does the launch.
class PayMethodsList extends StatelessWidget {
  const PayMethodsList({
    super.key,
    required this.entries,
    required this.onOpen,
    this.loading = false,
    this.busyEntry,
  });

  final List<PayMethodEntry> entries;
  final ValueChanged<PayMethodEntry> onOpen;

  /// Show skeleton rows while the host's methods load.
  final bool loading;

  /// Row currently opening (shows a small spinner instead of "Open").
  final PayMethodEntry? busyEntry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decoration = BoxDecoration(
      color: p.surface,
      borderRadius: AppRadii.cardRadius,
      border: Border.all(color: p.hairline),
    );
    if (loading) {
      return Container(
        decoration: decoration,
        child: const SkeletonShimmer(
          child: Column(children: [SkeletonListTile(), SkeletonListTile()]),
        ),
      );
    }
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.allLg,
        decoration: decoration,
        child: Text(
          'bf_bill_pay_none'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++)
              _PayMethodRow(
                entry: entries[i],
                showDivider: i > 0,
                busy: busyEntry != null && busyEntry!.sameAs(entries[i]),
                onTap: () => onOpen(entries[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PayMethodRow extends StatelessWidget {
  const _PayMethodRow({
    required this.entry,
    required this.showDivider,
    required this.busy,
    required this.onTap,
  });

  final PayMethodEntry entry;
  final bool showDivider;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subtitle = entry.type.id == 'apple_cash'
        ? 'bd2_apple_cash_hint'.tr()
        : entry.prefillsAmount
        ? 'bf_bill_pay_amount_filled'.tr()
        : entry.handle;
    return Semantics(
      button: true,
      label: 'bf_bill_pay_open_semantics'.tr(namedArgs: {'app': entry.name}),
      excludeSemantics: true,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(top: BorderSide(color: p.borderSubtle))
                : null,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.initials,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 44,
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.accent,
                          ),
                        )
                      : Text(
                          'bf_bill_pay_open'.tr(),
                          style: AppTypography.labelLarge.copyWith(
                            color: p.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
