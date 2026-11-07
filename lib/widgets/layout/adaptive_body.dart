import 'package:flutter/material.dart';

/// Max content widths for wide screens (iPad, landscape, desktop web).
abstract final class AdaptiveWidth {
  /// Forms, sheets, auth, onboarding.
  static const double form = 560;

  /// Lists and detail pages.
  static const double list = 720;
}

/// Centers [child] with a max width on wide screens; at or below that width
/// it returns the child unchanged, so phone layouts are untouched.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    super.key,
    required this.child,
    this.maxWidth = AdaptiveWidth.list,
  });

  const AdaptiveBody.form({super.key, required this.child})
    : maxWidth = AdaptiveWidth.form;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth <= maxWidth) return child;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    },
  );
}
