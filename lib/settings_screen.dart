import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';

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
            subtitle: '${selectedLocale.englishName} • ${selectedLocale.nativeName}',
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
        ],
      ),
    );
  }

  void _showLocaleSheet(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: supportedLocaleOptions.length,
          itemBuilder: (context, index) {
            final option = supportedLocaleOptions[index];
            final isSelected = option.code == settings.locale.languageCode;

            return ListTile(
              leading: CircleAvatar(
                child: Text(option.nativeName.characters.first),
              ),
              title: Text(option.englishName),
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
          },
        );
      },
    );
  }

  void _showCurrencySheet(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return ListView.builder(
              controller: scrollController,
              itemCount: supportedCurrencyOptions.length,
              itemBuilder: (context, index) {
                final option = supportedCurrencyOptions[index];
                final isSelected = option.code == settings.currencyCode;

                return ListTile(
                  leading: CircleAvatar(child: Text(option.symbol)),
                  title: Text('${option.code} • ${option.name}'),
                  subtitle: Text(option.region),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await settings.updateCurrencyCode(option.code);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
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
