import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// "Notifications, asked at the right moment": explains what we send, then
/// [onRequest] shows the OS prompt. "Maybe later" calls [onDefer] and never
/// touches the OS prompt, so the user can still be asked later.
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({
    super.key,
    required this.onRequest,
    required this.onDefer,
    required this.onDone,
  });

  /// Shows the system prompt; returns whether notifications are allowed.
  final Future<bool> Function() onRequest;
  final Future<void> Function() onDefer;
  final VoidCallback onDone;

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Notification permission step failed: $e');
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currency = 'USD';
    return PermissionExplainerScaffold(
      illustration: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StaggeredEntrance(
            child: SampleNotificationCard(
              title: 'acct_notif_sample_paid_title'.tr(
                namedArgs: {'amount': formatMoneyMinor(5410, currency)},
              ),
              body: 'acct_notif_sample_paid_body'.tr(),
              elevated: true,
            ),
          ),
          const SizedBox(height: 12),
          StaggeredEntrance(
            index: 1,
            child: Opacity(
              opacity: 0.7,
              child: SampleNotificationCard(
                title: 'acct_notif_sample_due_title'.tr(),
                body: 'acct_notif_sample_due_body'.tr(
                  namedArgs: {'amount': formatMoneyMinor(42000, currency)},
                ),
              ),
            ),
          ),
        ],
      ),
      title: 'acct_notif_title'.tr(),
      body: 'acct_notif_body'.tr(),
      primary: FilledButton(
        key: const ValueKey('notif-allow'),
        onPressed: _busy
            ? null
            : () => _run(() async {
                AppHaptics.light();
                await widget.onRequest();
              }),
        child: _busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.onInverseSurface,
                ),
              )
            : Text('acct_notif_cta'.tr()),
      ),
      secondary: TextButton(
        key: const ValueKey('notif-later'),
        onPressed: _busy ? null : () => _run(widget.onDefer),
        style: TextButton.styleFrom(foregroundColor: p.textSecondary),
        child: Text('acct_maybe_later'.tr()),
      ),
    );
  }
}

/// Shared layout for the permission explainers: illustration in the middle,
/// headline, body, ink primary button and a quiet secondary action.
class PermissionExplainerScaffold extends StatelessWidget {
  const PermissionExplainerScaffold({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary,
  });

  final Widget illustration;
  final String title;
  final String body;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppScaffold(
      body: AdaptiveBody.form(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                // Illustration tile: soft mint panel behind it.
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: p.accentSoft.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: illustration,
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: AppTypography.displaySmall.copyWith(
                                color: p.textPrimary,
                                fontSize: 30,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            body,
                            style: AppTypography.bodyLarge.copyWith(
                              color: p.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          primary,
                          if (secondary != null) ...[
                            const SizedBox(height: 10),
                            secondary!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A notification-shaped card used as illustration.
class SampleNotificationCard extends StatelessWidget {
  const SampleNotificationCard({
    super.key,
    required this.title,
    required this.body,
    this.elevated = false,
  });

  final String title;
  final String body;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
        boxShadow: elevated ? p.sheetShadow : p.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(AppIcons.receipt, size: 20, color: p.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: p.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  body,
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
