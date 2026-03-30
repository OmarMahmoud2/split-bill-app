import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/notification_service.dart';

class SendNotificationSheet extends StatefulWidget {
  final String targetUid;
  final String? targetToken;
  final String userName;

  const SendNotificationSheet({
    super.key,
    required this.targetUid,
    this.targetToken,
    required this.userName,
  });

  @override
  State<SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends State<SendNotificationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isSending = false;

  Future<void> _handleSend() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_fill_all_fields'.tr())),
      );
      return;
    }

    if (widget.targetToken == null || widget.targetToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('user_missing_fcm_token'.tr())),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await NotificationService().sendNotification(
        targetToken: widget.targetToken!,
        targetUid: widget.targetUid,
        title: title,
        body: body,
        data: {
          'type': 'admin_message',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('notification_sent_successfully'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_sending_notification'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'send_notification_to'.tr(namedArgs: {'name': widget.userName}),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 24),

        // Title
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'notification_title'.tr(),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Body
        TextField(
          controller: _bodyController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'notification_body'.tr(),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _isSending ? null : _handleSend,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: _isSending
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Text(
                  'send_notification'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
