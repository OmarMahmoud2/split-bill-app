/// Design tokens: import this one file to get colors, spacing, radii,
/// typography and the ThemeData builders.
///
/// ```dart
/// import 'package:split_bill_app/theme/theme.dart';
///
/// final p = context.palette;
/// Container(color: p.surface, child: Text('Hi', style: TextStyle(color: p.textPrimary)));
/// ```
library;

export 'app_colors.dart';
export 'app_haptics.dart';
export 'app_motion.dart';
export 'app_palette.dart';
export 'app_spacing.dart';
export 'app_typography.dart';
export '../utils/app_theme.dart';
