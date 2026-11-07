import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/utils/display_name.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/my_photo.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/edit_profile_screen.dart';
import 'package:split_bill_app/groups_screen.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/payment_settings_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/admin/admin_dashboard_screen.dart';
import 'package:split_bill_app/screens/profile/appearance_screen.dart';
import 'package:split_bill_app/screens/profile/export_screen.dart';
import 'package:split_bill_app/screens/profile/reminders_screen.dart';
import 'package:split_bill_app/screens/profile/subscription_screen.dart';
import 'package:split_bill_app/screens/profile/widgets/debug_seed.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_content.dart';
import 'package:split_bill_app/screens/profile/widgets/photo_sheet.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/services/profile_service.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/screens/recurring/recurring_bill_screen.dart';
import 'package:split_bill_app/services/reminder_prefs.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/searchable_selection_sheet.dart';

/// The v3 "You" tab: profile, account, app settings and Pro tools.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final InAppReview _inAppReview = InAppReview.instance;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  String? _monthlyPrice;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    final user = _user;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
    RewardedAdHelper.warmUpIfEligible();
    _loadMonthlyPrice();
  }

  Future<void> _loadMonthlyPrice() async {
    if (kIsWeb) return;
    try {
      final plans = PaywallPlan.fromPackages(
        await RevenueCatService.getPremiumPackages(),
      );
      final monthly = plans
          .where((p) => p.kind == PaywallPlanKind.monthly)
          .firstOrNull;
      if (mounted && monthly != null) {
        setState(() => _monthlyPrice = monthly.priceString);
      }
    } catch (_) {
      // Card falls back to "Go Pro".
    }
  }

  void _retry() {
    final user = _user;
    if (user == null) return;
    setState(() {
      _streamKey++;
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    });
  }

  Future<void> _openLink(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      AppToast.show(
        context,
        message: 'could_not_open_legal_link'.tr(),
        type: AppToastType.error,
      );
    }
  }

  Future<T?> _push<T>(Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  Future<void> _onAction(
    ProfileAction action,
    Map<String, dynamic> data,
    bool isPro,
  ) async {
    final settings = context.read<AppSettingsProvider>();
    switch (action) {
      case ProfileAction.goPro:
        await PremiumModal.show(context, placement: 'profile');
      case ProfileAction.editProfile:
        await _push(EditProfileScreen(currentData: data));
      case ProfileAction.paymentMethods:
        await _push(const PaymentSettingsScreen());
      case ProfileAction.subscription:
        await _push(const SubscriptionScreen());
      case ProfileAction.privacyAndData:
        await ProfileDialogs.showPrivacyAndData(
          context,
          onExport: () => _push(const ExportScreen()),
        );
      case ProfileAction.groups:
        await _push(const GroupsScreen());
      case ProfileAction.appearance:
        await _push(const AppearanceScreen());
      case ProfileAction.language:
        _showLocaleSheet(settings);
      case ProfileAction.currency:
        _showCurrencySheet(settings);
      case ProfileAction.reminders:
        await _push(RemindersScreen(currencyCode: settings.currencyCode));
      case ProfileAction.help:
        await ProfileDialogs.showContactUs(context);
      case ProfileAction.shareApp:
        await _shareApp();
      case ProfileAction.rateApp:
        await _rateApp();
      case ProfileAction.watchAd:
        await AdModal.show(context, onWatchAd: _showRewardedAd);
      case ProfileAction.export:
        await _push(const ExportScreen());
      case ProfileAction.recurring:
        await _push(const RecurringBillScreen());
      case ProfileAction.admin:
        await _push(const AdminDashboardScreen());
      case ProfileAction.showOnboarding:
        await _push(const NewOnboardingScreen());
      case ProfileAction.seedTransactions:
        await _seed();
      case ProfileAction.changePhoto:
        await _changePhoto(data['photoUrl'] as String?);
      case ProfileAction.addIou:
        final s = HomeBalances.latest;
        await showQuickIouSheet(
          context,
          people: s == null ? const [] : peopleAsMembers(s.summary),
        );
      case ProfileAction.deleteAccount:
        ProfileDialogs.showDeleteAccount(context);
      case ProfileAction.logout:
        await ProfileDialogs.showLogout(context);
    }
  }

  Future<void> _changePhoto(String? current) async {
    final result = await choosePhoto(
      context,
      hasPhoto: current != null && current.isNotEmpty,
      failed: () {
        if (mounted) {
          AppToast.show(
            context,
            message: 'prof_photo_failed'.tr(),
            type: AppToastType.error,
          );
        }
      },
    );
    if (result == null || !mounted) return;
    final service = ProfileService();
    final ok = result.removed
        ? await service.removeAvatar()
        : await service.saveAvatarAsBase64(result.file!) != null;
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok ? 'prof_saved'.tr() : 'prof_photo_failed'.tr(),
      type: ok ? AppToastType.success : AppToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const LoginScreen();
    final settings = context.watch<AppSettingsProvider>();
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AdaptiveBody(
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey(_streamKey),
            stream: _userStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(onRetry: _retry);
              }
              if (!snapshot.hasData) {
                return const _ProfileSkeleton();
              }
              final data = snapshot.data!.data() ?? <String, dynamic>{};
              final isPro = RevenueCatService.isUserActivePremium(data);
              final planKind = planKindForProductId(
                data['premiumProductId']?.toString(),
              );
              final ledger = HomeBalances.latest;
              final year = DateTime.now().year;
              final settled = ledger == null
                  ? 0
                  : [
                      ...ledger.directPayments,
                      for (final g in ledger.groupInputs) ...g.payments,
                    ].where((x) => x.createdAt?.year == year).length;
              final view = ProfileViewData(
                billsSplit: ledger?.recentBills.length ?? 0,
                peopleCount: ledger?.summary.people.length ?? 0,
                settledThisYear: settled,
                name: firstNonBlank([
                  data['displayName'] as String?,
                  _user.displayName,
                ], fallback: 'user'.tr()),
                photoUrl: MyPhoto.chosen(data['photoUrl']),
                isPro: isPro,
                planLabel: planKind == null
                    ? null
                    : 'pw_plan_${planKind.name}'.tr(),
                points: (data['points'] as num?)?.toInt() ?? 0,
                paymentMethodCount: parseStoredPaymentMethods(data).length,
                monthlyPrice: _monthlyPrice,
                appearanceLabel: themeModeLabelKey(settings.themeMode).tr(),
                languageLabel: findLocaleOption(
                  settings.locale.languageCode,
                ).nativeName,
                currencyCode: settings.currencyCode,
                hapticsEnabled: settings.hapticsEnabled,
                remindersSummary: ReminderPrefs.fromUserDoc(
                  data,
                ).summary(offLabel: 'rem_off'.tr(), locale: locale),
                isAdmin: data['isAdmin'] == true,
                showDeveloper: kDebugMode,
              );
              return ProfileContent(
                data: view,
                onAction: (action) => _onAction(action, data, isPro),
                onHapticsChanged: settings.updateHapticsEnabled,
                onOpenLink: _openLink,
              );
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ language

  void _showLocaleSheet(AppSettingsProvider settings) {
    final p = context.palette;
    PremiumBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SearchableSelectionSheet<LocaleOption>(
        title: 'choose_language'.tr(),
        searchHint: 'search_languages'.tr(),
        items: supportedLocaleOptions
            .map(
              (option) => SearchableSheetItem<LocaleOption>(
                value: option,
                title: option.nativeName,
                subtitle: option.englishName,
                searchTerms: [
                  option.code,
                  option.englishName,
                  option.nativeName,
                ],
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            )
            .toList(),
        isSelected: (option) => option.code == settings.locale.languageCode,
        onSelected: (option) async {
          final navigator = Navigator.of(context);
          await applyLocaleOption(context, option);
          if (!mounted) return;
          navigator.pop();
        },
      ),
    );
  }

  void _showCurrencySheet(AppSettingsProvider settings) {
    final p = context.palette;
    PremiumBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SearchableSelectionSheet<CurrencyOption>(
        title: 'choose_currency'.tr(),
        searchHint: 'search_currencies'.tr(),
        items: supportedCurrencyOptions
            .map(
              (option) => SearchableSheetItem<CurrencyOption>(
                value: option,
                title: '${option.code} · ${option.name}',
                subtitle: option.region,
                searchTerms: [
                  option.code,
                  option.name,
                  option.region,
                  option.symbol,
                ],
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surfaceVariant,
                    borderRadius: AppRadii.rowRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.symbol,
                    style: AppTypography.titleMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
        isSelected: (option) => option.code == settings.currencyCode,
        onSelected: (option) async {
          final navigator = Navigator.of(context);
          AppHaptics.selection();
          await settings.updateCurrencyCode(option.code);
          if (!mounted) return;
          navigator.pop();
        },
      ),
    );
  }

  // ------------------------------------------------------------ share/rate

  Future<void> _shareApp() async {
    Future<void> share(String key, String url, String subjectKey) =>
        SharePlus.instance.share(
          ShareParams(
            text: key.tr(namedArgs: {'url': url}),
            subject: subjectKey.tr(),
          ),
        );

    await PremiumBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) {
          final p = sheetContext.palette;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'prof_share_title'.tr(),
                style: AppTypography.headlineLarge.copyWith(
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'prof_share_body'.tr(),
                style: AppTypography.bodyLarge.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  share(
                    'download_split_bill_for_iphone',
                    AppLinks.appStoreUrl,
                    'split_bill_on_the_app_store',
                  );
                },
                icon: const Icon(AppIcons.apple),
                label: Text('share_to_iphone'.tr()),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  share(
                    'download_split_bill_for_android',
                    AppLinks.playStoreUrl,
                    'split_bill_on_google_play',
                  );
                },
                icon: const Icon(AppIcons.android),
                label: Text('share_to_android'.tr()),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: AppLinks.storeUrl));
                  Navigator.pop(sheetContext);
                  AppToast.show(
                    context,
                    message: 'link_copied_to_clipboard'.tr(),
                    type: AppToastType.success,
                  );
                },
                icon: const Icon(AppIcons.link),
                label: Text('copy_app_link'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(appStoreId: AppLinks.appleAppId);
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'could_not_open_rating_dialog'.tr(),
        type: AppToastType.error,
      );
    }
  }

  // ------------------------------------------------------------ rewarded ad

  Future<void> _showRewardedAd() async {
    if (await RewardedAdHelper.isDailyCapReached()) {
      if (!mounted) return;
      AppToast.show(context, message: 'ad_daily_cap_reached'.tr());
      return;
    }
    if (!mounted) return;
    if (!RewardedAdHelper.isReady) {
      AppToast.show(context, message: 'prof_ad_loading'.tr());
      try {
        await RewardedAdHelper.loadAd();
      } catch (e) {
        debugPrint('Ad loading failed: $e');
      }
      return;
    }

    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () {
        if (!mounted) return;
        AppToast.show(
          context,
          message: 'prof_ad_reward'.tr(),
          type: AppToastType.success,
        );
      },
      onAdFailed: () {
        if (!mounted) return;
        AppToast.show(
          context,
          message: 'prof_ad_unavailable'.tr(),
          type: AppToastType.error,
        );
      },
    );
  }

  // ------------------------------------------------------------ debug

  Future<void> _seed() async {
    try {
      await seedTestBills();
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'added_6_diverse_test_bills'.tr(),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: '$e', type: AppToastType.error);
    }
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton.circle(size: 64),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.line(width: 140, height: 18),
                      SizedBox(height: 8),
                      Skeleton.line(width: 200),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            SkeletonCard(lines: [0.5, 0.7, 0.4, 0.6]),
            SizedBox(height: 16),
            SkeletonCard(lines: [0.6, 0.4, 0.5]),
          ],
        ),
      ),
    );
  }
}
