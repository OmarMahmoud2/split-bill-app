import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/notification_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Admin: send one push notification to a single user (v3 "Notification"
/// board): audience, title, message, a live preview and one ink CTA.
class SendNotificationSheet extends StatefulWidget {
  final String targetUid;
  final String? targetToken;
  final String userName;

  /// Injected for tests; defaults to [NotificationService.sendNotification].
  final Future<bool> Function({
    required String targetUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  })?
  sender;

  /// Called with the title after a successful send (audit logging).
  final void Function(String title)? onSent;

  const SendNotificationSheet({
    super.key,
    required this.targetUid,
    this.targetToken,
    required this.userName,
    this.sender,
    this.onSent,
  });

  @override
  State<SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends State<SendNotificationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refresh);
    _bodyController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  bool get _hasToken =>
      widget.targetToken != null && widget.targetToken!.isNotEmpty;

  Future<void> _handleSend() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      AppToast.show(
        context,
        message: 'please_fill_all_fields'.tr(),
        type: AppToastType.warning,
      );
      return;
    }

    if (!_hasToken) {
      AppToast.show(
        context,
        message: 'user_missing_fcm_token'.tr(),
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _isSending = true);
    AppHaptics.light();

    try {
      final send = widget.sender ?? NotificationService().sendNotification;
      final ok = await send(
        targetUid: widget.targetUid,
        title: title,
        body: body,
        data: {
          'type': 'admin_message',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
      if (!mounted) return;
      if (!ok) throw StateError('send failed');
      widget.onSent?.call(title);
      // The toast lives in the root overlay, so it outlives the sheet.
      AppToast.show(
        context,
        message: 'notification_sent_successfully'.tr(),
        type: AppToastType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'error_sending_notification'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'adm3_notification_title'.tr(),
            style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: 18),
        V3FieldLabel('adm3_audience'.tr()),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.rowRadius,
            border: Border.all(color: p.borderStrong),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.userName,
                  style: AppTypography.bodyLarge.copyWith(color: p.textPrimary),
                ),
              ),
              Text(
                _hasToken
                    ? 'adm3_audience_one'.tr()
                    : 'user_missing_fcm_token'.tr(),
                style: AppTypography.bodySmall.copyWith(
                  color: _hasToken ? p.textSecondary : p.owe,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        V3FieldLabel('adm3_title_label'.tr()),
        TextField(
          key: const ValueKey('admin-notification-title'),
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: 'notification_title'.tr()),
        ),
        const SizedBox(height: 14),
        V3FieldLabel('adm3_message_label'.tr()),
        TextField(
          key: const ValueKey('admin-notification-body'),
          controller: _bodyController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(hintText: 'notification_body'.tr()),
        ),
        const SizedBox(height: 14),
        V3FieldLabel('adm3_preview'.tr()),
        Semantics(
          label: 'adm3_preview'.tr(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: p.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'notification_title'.tr() : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: title.isEmpty ? p.textTertiary : p.textPrimary,
                        ),
                      ),
                      Text(
                        body.isEmpty ? 'notification_body'.tr() : body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: p.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('admin-notification-send'),
          onPressed: _isSending ? null : _handleSend,
          child: _isSending
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.onInverseSurface,
                  ),
                )
              : Text('adm3_send_to'.tr(namedArgs: {'name': widget.userName})),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
