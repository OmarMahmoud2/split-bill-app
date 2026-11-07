import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Translation key for a [ThemeMode] label.
String themeModeLabelKey(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'prof_theme_system',
  ThemeMode.light => 'theme_mode_light',
  ThemeMode.dark => 'theme_mode_dark',
};

/// Applies [option] app-wide: provider (synced to the profile) and
/// EasyLocalization.
Future<void> applyLocaleOption(
  BuildContext context,
  LocaleOption option,
) async {
  final settings = context.read<AppSettingsProvider>();
  final localization = EasyLocalization.of(context);
  AppHaptics.selection();
  await settings.updateLocale(option.locale);
  await localization?.setLocale(option.locale);
}

/// Appearance (System / Light / Dark) and the 22 app languages.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<AppSettingsProvider>();
    final current = settings.locale.languageCode;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            V3TopBar(
              title: 'prof_appearance'.tr(),
              leading: V3IconButton.back(context),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
              child: Row(
                children: [
                  for (final mode in const [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark,
                  ]) ...[
                    if (mode != ThemeMode.system) const SizedBox(width: 10),
                    Expanded(
                      child: _ThemeOption(
                        mode: mode,
                        selected: settings.themeMode == mode,
                        onTap: () {
                          AppHaptics.selection();
                          settings.updateThemeMode(mode);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SettingsSectionLabel(
              'prof_language_count'.tr(
                namedArgs: {'count': '${supportedLocaleOptions.length}'},
              ),
            ),
            SettingsCard(
              children: [
                for (final option in supportedLocaleOptions)
                  _LanguageRow(
                    option: option,
                    selected: option.code == current,
                    onTap: () => applyLocaleOption(context, option),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const light = AppPalette.light;
    const dark = AppPalette.dark;
    final Widget preview = switch (mode) {
      ThemeMode.system => Row(
        children: [
          Expanded(child: ColoredBox(color: light.canvas)),
          Expanded(child: ColoredBox(color: dark.canvas)),
        ],
      ),
      ThemeMode.light => DecoratedBox(
        decoration: BoxDecoration(
          color: light.canvas,
          border: Border.all(color: light.hairline),
          borderRadius: AppRadii.rowRadius,
        ),
      ),
      ThemeMode.dark => ColoredBox(color: dark.canvas),
    };
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: themeModeLabelKey(mode).tr(),
      excludeSemantics: true,
      child: Material(
        key: ValueKey('appearance-${mode.name}'),
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: selected ? p.textPrimary : p.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: AppRadii.rowRadius,
                  child: SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: preview,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  themeModeLabelKey(mode).tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LocaleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final showEnglish = option.englishName != option.nativeName;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SettingsRow(
        key: ValueKey('language-${option.code}'),
        title: option.nativeName,
        value: showEnglish ? option.englishName : null,
        showChevron: false,
        trailing: selected
            ? Icon(AppIcons.check, size: 20, color: p.accent)
            : const SizedBox(width: 20),
        onTap: onTap,
      ),
    );
  }
}
