import 'package:flutter/material.dart';

/// A standardized premium bottom sheet container that is bottom-anchored,
/// responsive, and keyboard-aware.
class PremiumBottomSheet extends StatelessWidget {
  const PremiumBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 24),
    this.showPullHandle = true,
    this.isScrollable = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showPullHandle;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colorScheme.surface
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding.copyWith(
            bottom: padding.bottom + bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showPullHandle) ...[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isScrollable)
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: child,
                    ),
                  )
                else
                  child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper to show the premium bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(24, 12, 24, 24),
    bool isScrollControlled = true,
    bool showPullHandle = true,
    bool isScrollable = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => PremiumBottomSheet(
        padding: padding,
        showPullHandle: showPullHandle,
        isScrollable: isScrollable,
        child: child,
      ),
    );
  }
}
