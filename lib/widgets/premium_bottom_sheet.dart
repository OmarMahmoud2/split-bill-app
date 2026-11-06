import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// A standardized premium bottom sheet container that is bottom-anchored,
/// responsive, and keyboard-aware.
class PremiumBottomSheet extends StatelessWidget {
  const PremiumBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
    this.showPullHandle = true,
    this.isScrollable = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showPullHandle;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.sheetRadius,
        // v3: the one soft shadow sheets cast, light mode only.
        boxShadow: p.sheetShadow,
      ),
      // Transparent Material so ListTiles and InkWells inside the sheet
      // paint their ripples above the decorated background.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding.add(EdgeInsets.only(bottom: bottomInset)),
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
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: p.borderStrong,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
      ),
    );
  }

  /// Helper to show the premium bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
    bool isScrollControlled = true,
    bool showPullHandle = true,
    bool isScrollable = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: context.palette.scrim,
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
