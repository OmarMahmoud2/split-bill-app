import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/account/notification_permission_screen.dart';
import 'package:split_bill_app/theme/theme.dart';

/// App Tracking Transparency explainer (iOS, only while ATT is
/// undetermined). It states plainly what tracking changes, offers no
/// reward for allowing it, and its single "Continue" leads straight to the
/// system dialog (App Review guideline 5.1.2).
class TrackingPermissionScreen extends StatefulWidget {
  const TrackingPermissionScreen({
    super.key,
    required this.onRequest,
    required this.onDone,
  });

  /// Shows the ATT system dialog.
  final Future<void> Function() onRequest;
  final VoidCallback onDone;

  @override
  State<TrackingPermissionScreen> createState() =>
      _TrackingPermissionScreenState();
}

class _TrackingPermissionScreenState extends State<TrackingPermissionScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    AppHaptics.light();
    try {
      await widget.onRequest();
    } catch (e) {
      debugPrint('Tracking authorization unavailable: $e');
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );

    return PermissionExplainerScaffold(
      illustration: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            point(
              AppIcons.playCircle,
              'acct_att_point_optional'.tr(),
            ),
            point(AppIcons.lock, 'acct_att_point_data'.tr()),
          ],
        ),
      ),
      title: 'acct_att_title'.tr(),
      body: 'acct_att_body'.tr(),
      primary: FilledButton(
        key: const ValueKey('att-continue'),
        onPressed: _busy ? null : _continue,
        child: Text('common_continue'.tr()),
      ),
    );
  }
}
