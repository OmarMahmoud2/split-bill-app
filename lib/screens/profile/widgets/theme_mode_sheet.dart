import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_palette.dart';

/// Translation key for a [ThemeMode] label.
String themeModeLabelKey(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'theme_mode_system',
  ThemeMode.light => 'theme_mode_light',
  ThemeMode.dark => 'theme_mode_dark',
};

IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.brightness_auto_rounded,
  ThemeMode.light => Icons.light_mode_rounded,
  ThemeMode.dark => Icons.dark_mode_rounded,
};

/// Bottom sheet body listing System / Light / Dark.
class ThemeModeSheet extends StatelessWidget {
  const ThemeModeSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'choose_appearance'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        for (final mode in ThemeMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThemeModeOption(
              mode: mode,
              isSelected: mode == selected,
              onTap: () => onSelected(mode),
            ),
          ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: isSelected ? palette.primarySoft : palette.surfaceVariant,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('theme-mode-${mode.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? palette.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                themeModeIcon(mode),
                color: isSelected
                    ? palette.primaryStrong
                    : palette.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      themeModeLabelKey(mode).tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (mode == ThemeMode.system) ...[
                      const SizedBox(height: 2),
                      Text(
                        'theme_mode_system_subtitle'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: palette.primary),
            ],
          ),
        ),
      ),
    );
  }
}
