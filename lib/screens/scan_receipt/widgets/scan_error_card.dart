import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/scan_receipt/scan_error_content.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/theme/app_icons.dart';

/// A friendly scan error card ("We couldn't read this receipt. Your credit
/// was refunded." + Retake photo / Type it in), built on [ErrorState.inline].
class ScanErrorCard extends StatelessWidget {
  const ScanErrorCard({
    super.key,
    required this.content,
    required this.onAction,
  });

  final ScanErrorContent content;
  final ValueChanged<ScanErrorAction> onAction;

  @override
  Widget build(BuildContext context) {
    final secondary = content.secondary;
    return ErrorState.inline(
      key: const ValueKey('scan-error-card'),
      title: content.titleKey.tr(),
      message: content.message((k) => k.tr()),
      icon: content.offline
          ? AppIcons.wifiOff
          : AppIcons.error,
      retryLabel: scanErrorActionLabelKey(content.primary).tr(),
      onRetry: () => onAction(content.primary),
      secondaryLabel: secondary == null
          ? null
          : scanErrorActionLabelKey(secondary).tr(),
      onSecondary: secondary == null ? null : () => onAction(secondary),
    );
  }
}
