import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// Shown when a bill link or notification points at a bill that is gone or
/// could not be loaded.
class BillLinkErrorScreen extends StatelessWidget {
  const BillLinkErrorScreen({super.key, this.notFound = true, this.message});

  final bool notFound;

  /// Overrides the default message (already translated).
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(),
      body: SafeArea(
        child: notFound
            ? ErrorState(
                icon: AppIcons.receipt,
                title: 'bf_bill_not_found_title'.tr(),
                message: message ?? 'bf_bill_not_found_message'.tr(),
                retryLabel: 'bf_bill_go_back'.tr(),
                onRetry: () => Navigator.of(context).maybePop(),
              )
            : ErrorState(
                title: 'bf_bill_load_error_title'.tr(),
                message: message,
                retryLabel: 'bf_bill_go_back'.tr(),
                onRetry: () => Navigator.of(context).maybePop(),
              ),
      ),
    );
  }
}
