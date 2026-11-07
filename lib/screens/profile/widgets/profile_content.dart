import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/profile/widgets/version_info.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Every tap target on the "You" screen.
enum ProfileAction {
  goPro,
  editProfile,
  paymentMethods,
  subscription,
  privacyAndData,
  groups,
  appearance,
  language,
  currency,
  reminders,
  help,
  shareApp,
  rateApp,
  watchAd,
  export,
  recurring,
  admin,
  showOnboarding,
  seedTransactions,
}

/// What the "You" screen shows. Pure data so the screen is testable.
@immutable
class ProfileViewData {
  const ProfileViewData({
    required this.name,
    this.photoUrl,
    this.isPro = false,
    this.planLabel,
    this.points = 0,
    this.paymentMethodCount = 0,
    this.monthlyPrice,
    required this.appearanceLabel,
    required this.languageLabel,
    required this.currencyCode,
    this.hapticsEnabled = true,
    required this.remindersSummary,
    this.isAdmin = false,
    this.showDeveloper = false,
    this.showGroups = true,
  });

  final String name;
  final String? photoUrl;
  final bool isPro;

  /// "Yearly", "Monthly", "Lifetime" for Pro users.
  final String? planLabel;
  final int points;
  final int paymentMethodCount;

  /// Store-localized monthly price for the Go Pro card, when loaded.
  final String? monthlyPrice;
  final String appearanceLabel;
  final String languageLabel;
  final String currencyCode;
  final bool hapticsEnabled;
  final String remindersSummary;
  final bool isAdmin;
  final bool showDeveloper;
  final bool showGroups;
}

/// The v3 "You" screen body (Profile.dc.html).
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.data,
    required this.onAction,
    required this.onHapticsChanged,
  });

  final ProfileViewData data;
  final ValueChanged<ProfileAction> onAction;
  final ValueChanged<bool> onHapticsChanged;

  VoidCallback _tap(ProfileAction action) =>
      () => onAction(action);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final subtitle = data.isPro
        ? 'prof_pro_plan'.tr(
            namedArgs: {'plan': data.planLabel ?? 'prof_plan_pro'.tr()},
          )
        : 'prof_free_plan_points'.tr(namedArgs: {'points': '${data.points}'});

    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: Semantics(
            button: true,
            label: '${data.name}, $subtitle',
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('profile-header'),
              borderRadius: AppRadii.cardRadius,
              onTap: _tap(ProfileAction.editProfile),
              child: Row(
                children: [
                  _ProfileAvatar(name: data.name, photoUrl: data.photoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineMedium.copyWith(
                            color: p.textPrimary,
                            fontFamily: AppTypography.bodyFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTypography.bodyMedium.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!data.isPro)
          _GoProCard(
            price: data.monthlyPrice,
            onTap: _tap(ProfileAction.goPro),
          ),
        SettingsSectionLabel('prof_section_account'.tr()),
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('profile-edit'),
              title: 'prof_edit_profile'.tr(),
              onTap: _tap(ProfileAction.editProfile),
            ),
            SettingsRow(
              key: const ValueKey('profile-payment-methods'),
              title: 'prof_payment_methods'.tr(),
              value: data.paymentMethodCount > 0
                  ? '${data.paymentMethodCount}'
                  : null,
              onTap: _tap(ProfileAction.paymentMethods),
            ),
            SettingsRow(
              key: const ValueKey('profile-subscription'),
              title: 'prof_subscription'.tr(),
              value: data.isPro ? 'prof_plan_pro'.tr() : 'prof_plan_free'.tr(),
              onTap: _tap(ProfileAction.subscription),
            ),
            if (data.showGroups)
              SettingsRow(
                key: const ValueKey('profile-groups'),
                title: 'prof_my_groups'.tr(),
                onTap: _tap(ProfileAction.groups),
              ),
            SettingsRow(
              key: const ValueKey('profile-privacy'),
              title: 'prof_privacy_data'.tr(),
              onTap: _tap(ProfileAction.privacyAndData),
            ),
          ],
        ),
        SettingsSectionLabel('prof_section_app'.tr()),
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('profile-appearance'),
              title: 'prof_appearance'.tr(),
              value: data.appearanceLabel,
              onTap: _tap(ProfileAction.appearance),
            ),
            SettingsRow(
              key: const ValueKey('profile-language'),
              title: 'prof_language'.tr(),
              value: data.languageLabel,
              onTap: _tap(ProfileAction.language),
            ),
            SettingsRow(
              key: const ValueKey('profile-currency'),
              title: 'prof_default_currency'.tr(),
              value: data.currencyCode,
              onTap: _tap(ProfileAction.currency),
            ),
            SettingsSwitchRow(
              key: const ValueKey('profile-haptics'),
              title: 'settings_haptics'.tr(),
              subtitle: 'settings_haptics_subtitle'.tr(),
              value: data.hapticsEnabled,
              onChanged: onHapticsChanged,
            ),
            SettingsRow(
              key: const ValueKey('profile-reminders'),
              title: 'prof_reminders'.tr(),
              value: data.remindersSummary,
              onTap: _tap(ProfileAction.reminders),
            ),
            SettingsRow(
              key: const ValueKey('profile-help'),
              title: 'prof_help_contact'.tr(),
              onTap: _tap(ProfileAction.help),
            ),
            SettingsRow(
              title: 'prof_share_app'.tr(),
              onTap: _tap(ProfileAction.shareApp),
            ),
            SettingsRow(
              title: 'prof_rate_app'.tr(),
              onTap: _tap(ProfileAction.rateApp),
            ),
          ],
        ),
        SettingsSectionLabel('prof_section_pro_tools'.tr()),
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('profile-export'),
              title: 'prof_export'.tr(),
              subtitle: 'prof_export_sub'.tr(),
              trailing: data.isPro ? null : const ProBadge(),
              onTap: _tap(ProfileAction.export),
            ),
            SettingsRow(
              key: const ValueKey('profile-recurring'),
              title: 'prof_recurring'.tr(),
              subtitle: 'prof_recurring_sub'.tr(),
              trailing: data.isPro ? null : const ProBadge(),
              onTap: _tap(ProfileAction.recurring),
            ),
            if (!data.isPro)
              SettingsRow(
                key: const ValueKey('profile-watch-ad'),
                title: 'prof_watch_ad'.tr(),
                subtitle: 'prof_watch_ad_sub'.tr(),
                onTap: _tap(ProfileAction.watchAd),
              ),
          ],
        ),
        if (data.isAdmin) ...[
          SettingsSectionLabel('prof_section_admin'.tr()),
          SettingsCard(
            children: [
              SettingsRow(
                key: const ValueKey('profile-admin'),
                title: 'prof_admin_dashboard'.tr(),
                onTap: _tap(ProfileAction.admin),
              ),
            ],
          ),
        ],
        if (data.showDeveloper) ...[
          SettingsSectionLabel('prof_section_developer'.tr()),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'show_onboarding'.tr(),
                onTap: _tap(ProfileAction.showOnboarding),
              ),
              SettingsRow(
                title: 'seed_transactions'.tr(),
                onTap: _tap(ProfileAction.seedTransactions),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),
        const VersionInfo(),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) =>
      V3Avatar(name: name, photoUrl: photoUrl, size: 64);
}

class _GoProCard extends StatelessWidget {
  const _GoProCard({required this.price, required this.onTap});

  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = price == null
        ? 'prof_go_pro'.tr()
        : 'prof_go_pro_price'.tr(namedArgs: {'price': price!});
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      child: Semantics(
        button: true,
        child: Material(
          key: const ValueKey('profile-go-pro'),
          color: p.inverseSurface,
          borderRadius: AppRadii.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppHaptics.light();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: p.onInverseSurface,
                          ),
                        ),
                        Text(
                          'prof_go_pro_sub'.tr(),
                          style: AppTypography.bodySmall.copyWith(
                            color: p.onInverseSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.onInverseSurface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
