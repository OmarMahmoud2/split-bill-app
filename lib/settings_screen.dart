import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final selectedLocale = findLocaleOption(settings.locale.languageCode);
    final selectedCurrency = findCurrencyOption(settings.currencyCode);

    return Scaffold(
      appBar: CustomAppHeader(title: 'settings_title'.tr()),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(title: 'settings_title'.tr()),
          const SizedBox(height: 12),
          _SettingsCard(
            title: 'app_language'.tr(),
            subtitle:
                '${selectedLocale.englishName} • ${selectedLocale.nativeName}',
            icon: Icons.language_rounded,
            onTap: () => _showLocaleSheet(context, settings),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            title: 'default_currency'.tr(),
            subtitle:
                '${selectedCurrency.code} • ${selectedCurrency.name} • ${selectedCurrency.region}',
            icon: Icons.attach_money_rounded,
            onTap: () => _showCurrencySheet(context, settings),
          ),
          const SizedBox(height: 16),
          Text(
            'settings_profile_notice'.tr(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }

  void _showLocaleSheet(BuildContext context, AppSettingsProvider settings) {
    PremiumBottomSheet.show(
      context: context,
      isScrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'app_language',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ).tr(),
          ),
          ...supportedLocaleOptions.map((option) {
            final isSelected = option.code == settings.locale.languageCode;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.grey[100],
                child: Text(
                  option.nativeName.characters.first,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                option.englishName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(option.nativeName),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                await settings.updateLocale(option.locale);
                if (context.mounted) {
                  await context.setLocale(option.locale);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            );
          }),
        ],
      ),
    );
  }

  void _showCurrencySheet(BuildContext context, AppSettingsProvider settings) {
    final searchController = TextEditingController();
    final customController = TextEditingController();

    PremiumBottomSheet.show(
      context: context,
      isScrollable: true,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final query = searchController.text.trim().toLowerCase();
          final filteredOptions = supportedCurrencyOptions
              .where((option) {
                if (query.isEmpty) return true;
                return option.code.toLowerCase().contains(query) ||
                    option.name.toLowerCase().contains(query) ||
                    option.region.toLowerCase().contains(query);
              })
              .toList(growable: false);

          Future<void> applyCurrency(String code) async {
            final normalized = sanitizeCurrencyCode(code);
            if (normalized == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('onboarding_custom_currency_error'.tr()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            await settings.updateCurrencyCode(normalized);
            if (context.mounted) {
              Navigator.pop(context);
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'default_currency',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ).tr(),
              ),
              TextField(
                controller: searchController,
                onChanged: (_) => setModalState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'settings_search_currency'.tr(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_rounded),
                  hintText: 'settings_custom_currency_hint'.tr(),
                  labelText: 'settings_custom_currency'.tr(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'save_changes'.tr(),
                    onPressed: () => applyCurrency(customController.text),
                    icon: const Icon(Icons.check_circle_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...filteredOptions.map((option) {
                final isSelected = option.code == settings.currencyCode;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                    child: Text(
                      option.symbol,
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.72),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${option.code} • ${option.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(option.region),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () => applyCurrency(option.code),
                );
              }),
            ],
          );
        },
      ),
    ).whenComplete(() {
      searchController.dispose();
      customController.dispose();
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
