import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_extras.dart';
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
  changePhoto,
  addIou,
  deleteAccount,
  logout,
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
    this.billsSplit = 0,
    this.peopleCount = 0,
    this.settledThisYear = 0,
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
  final int billsSplit;
  final int peopleCount;
  final int settledThisYear;
}

/// The v3 "You" screen body (You.dc.html).
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.data,
    required this.onAction,
    required this.onHapticsChanged,
    this.onOpenLink,
  });

  /// Footer links; the screen launches them externally.
  final ValueChanged<String>? onOpenLink;
  final ProfileViewData data;
  final ValueChanged<ProfileAction> onAction;
  final ValueChanged<bool> onHapticsChanged;

  VoidCallback _tap(ProfileAction action) =>
      () => onAction(action);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final line = data.paymentMethodCount > 0
        ? 'you_pay_methods'.tr(namedArgs: {'n': '${data.paymentMethodCount}'})
        : 'prof_free_plan_points'.tr(namedArgs: {'points': '${data.points}'});

    SettingsIconTile tile(IconData i, Color tint, Color ink) =>
        SettingsIconTile(i, tint: tint, ink: ink);

    Widget group(String title, List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(title),
        SettingsCard(children: rows),
      ],
    );

    return ListView(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom + 48, // + raised centre button
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'prof_change_photo'.tr(),
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('profile-photo'),
                  onTap: _tap(ProfileAction.changePhoto),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      V3Avatar(
                        // Seed by account id so the pal matches Home's.
                        id: PalAvatar.currentUid(),
                        name: data.name,
                        photoUrl: data.photoUrl,
                        size: 76,
                      ),
                      PositionedDirectional(
                        end: -4,
                        bottom: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: p.inverseSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.canvas, width: 3),
                          ),
                          child: Icon(
                            AppIcons.camera,
                            size: 14,
                            color: p.onInverseSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    key: const ValueKey('profile-header'),
                    borderRadius: AppRadii.cardRadius,
                    onTap: _tap(ProfileAction.editProfile),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineMedium.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        data.isPro
                            ? _Pill(
                                key: const ValueKey('profile-pro-badge'),
                                label: 'you_pro_pill'.tr(
                                  namedArgs: {
                                    'plan':
                                        data.planLabel ?? 'prof_plan_pro'.tr(),
                                  },
                                ),
                                bg: p.hero,
                                fg: p.gold,
                                star: true,
                              )
                            // Free users get the Pro card below, not a second pill.
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          // Equal-height tiles even when one label wraps.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat('${data.billsSplit}', 'you_stat_bills'.tr()),
                const SizedBox(width: 10),
                _Stat('${data.peopleCount}', 'you_stat_people'.tr()),
                const SizedBox(width: 10),
                _Stat('${data.settledThisYear}', 'you_stat_settled'.tr()),
              ],
            ),
          ),
        ),
        ProCard(
          isPro: data.isPro,
          planLabel: data.planLabel,
          onTap: _tap(
            data.isPro ? ProfileAction.subscription : ProfileAction.goPro,
          ),
        ),
        IouCard(onAdd: _tap(ProfileAction.addIou)),
        group('prof_section_account'.tr(), [
          SettingsRow(
            key: const ValueKey('profile-edit'),
            leading: tile(AppIcons.edit, p.raised, p.textPrimary),
            title: 'prof_edit_profile'.tr(),
            onTap: _tap(ProfileAction.editProfile),
          ),
          SettingsRow(
            key: const ValueKey('profile-subscription'),
            leading: tile(AppIcons.crown, p.warningSoft, p.warningStrong),
            title: 'prof_subscription'.tr(),
            value: data.isPro ? 'prof_plan_pro'.tr() : 'prof_plan_free'.tr(),
            onTap: _tap(ProfileAction.subscription),
          ),
          if (data.showGroups)
            SettingsRow(
              key: const ValueKey('profile-groups'),
              leading: tile(AppIcons.groups, p.skySoft, p.sky),
              title: 'prof_my_groups'.tr(),
              onTap: _tap(ProfileAction.groups),
            ),
          SettingsRow(
            key: const ValueKey('profile-logout'),
            leading: tile(AppIcons.logout, p.raised, p.textPrimary),
            title: 'yx_logout'.tr(),
            showChevron: false,
            onTap: _tap(ProfileAction.logout),
          ),
        ]),
        group('you_group_money'.tr(), [
          SettingsRow(
            key: const ValueKey('profile-payment-methods'),
            leading: tile(AppIcons.wallet, p.accentSoft, p.accent),
            title: 'you_pay_you'.tr(),
            value: data.paymentMethodCount > 0
                ? '${data.paymentMethodCount}'
                : null,
            onTap: _tap(ProfileAction.paymentMethods),
          ),
          SettingsRow(
            key: const ValueKey('profile-currency'),
            leading: tile(AppIcons.currency, p.warningSoft, p.warningStrong),
            title: 'prof_default_currency'.tr(),
            value: data.currencyCode,
            onTap: _tap(ProfileAction.currency),
          ),
        ]),
        group('prof_section_app'.tr(), [
          SettingsRow(
            key: const ValueKey('profile-language'),
            leading: tile(AppIcons.language, p.skySoft, p.sky),
            title: 'prof_language'.tr(),
            value: data.languageLabel,
            onTap: _tap(ProfileAction.language),
          ),
          SettingsRow(
            key: const ValueKey('profile-appearance'),
            leading: tile(AppIcons.appearance, p.infoSoft, p.infoStrong),
            title: 'prof_appearance'.tr(),
            value: data.appearanceLabel,
            onTap: _tap(ProfileAction.appearance),
          ),
          SettingsRow(
            key: const ValueKey('profile-reminders'),
            leading: tile(AppIcons.bell, p.coralSoft, p.coralText),
            title: 'prof_reminders'.tr(),
            value: data.remindersSummary,
            onTap: _tap(ProfileAction.reminders),
          ),
          SettingsSwitchRow(
            key: const ValueKey('profile-haptics'),
            title: 'settings_haptics'.tr(),
            subtitle: 'settings_haptics_subtitle'.tr(),
            value: data.hapticsEnabled,
            onChanged: onHapticsChanged,
          ),
          SettingsRow(
            key: const ValueKey('profile-help'),
            leading: tile(AppIcons.help, p.raised, p.textPrimary),
            title: 'prof_help_contact'.tr(),
            onTap: _tap(ProfileAction.help),
          ),
          SettingsRow(
            leading: tile(AppIcons.share, p.raised, p.textPrimary),
            title: 'prof_share_app'.tr(),
            onTap: _tap(ProfileAction.shareApp),
          ),
          SettingsRow(
            leading: tile(AppIcons.heart, p.coralSoft, p.coralText),
            title: 'prof_rate_app'.tr(),
            onTap: _tap(ProfileAction.rateApp),
          ),
        ]),
        group('prof_section_pro_tools'.tr(), [
          SettingsRow(
            key: const ValueKey('profile-export'),
            leading: tile(AppIcons.export, p.raised, p.textPrimary),
            title: 'prof_export'.tr(),
            subtitle: 'prof_export_sub'.tr(),
            trailing: data.isPro ? null : const ProBadge(),
            onTap: _tap(ProfileAction.export),
          ),
          SettingsRow(
            key: const ValueKey('profile-recurring'),
            leading: tile(AppIcons.refresh, p.accentSoft, p.accent),
            title: 'prof_recurring'.tr(),
            subtitle: 'prof_recurring_sub'.tr(),
            trailing: data.isPro ? null : const ProBadge(),
            onTap: _tap(ProfileAction.recurring),
          ),
          if (!data.isPro)
            SettingsRow(
              key: const ValueKey('profile-watch-ad'),
              leading: tile(AppIcons.play, p.skySoft, p.sky),
              title: 'prof_watch_ad'.tr(),
              subtitle: 'prof_watch_ad_sub'.tr(),
              onTap: _tap(ProfileAction.watchAd),
            ),
        ]),
        group('you_group_data'.tr(), [
          SettingsRow(
            key: const ValueKey('profile-privacy'),
            leading: tile(AppIcons.lock, p.raised, p.textPrimary),
            title: 'prof_privacy_data'.tr(),
            onTap: _tap(ProfileAction.privacyAndData),
          ),
        ]),
        if (data.isAdmin)
          group('prof_section_admin'.tr(), [
            SettingsRow(
              key: const ValueKey('profile-admin'),
              leading: tile(AppIcons.settings, p.raised, p.textPrimary),
              title: 'prof_admin_dashboard'.tr(),
              onTap: _tap(ProfileAction.admin),
            ),
          ]),
        if (data.showDeveloper)
          group('prof_section_developer'.tr(), [
            SettingsRow(
              title: 'show_onboarding'.tr(),
              onTap: _tap(ProfileAction.showOnboarding),
            ),
            SettingsRow(
              title: 'seed_transactions'.tr(),
              onTap: _tap(ProfileAction.seedTransactions),
            ),
          ]),
        DangerZoneCard(onDelete: _tap(ProfileAction.deleteAccount)),
        const SizedBox(height: 32),
        EvensFooter(onOpen: onOpenLink ?? (_) {}),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.star = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.chipRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (star) ...[
            Icon(AppIcons.star, size: 12, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.titleLarge.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
