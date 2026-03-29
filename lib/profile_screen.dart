import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/payment_settings_screen.dart';
import 'package:split_bill_app/groups_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_header.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_cards.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_menu_widgets.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/screens/profile/widgets/version_info.dart';
import 'package:split_bill_app/widgets/searchable_selection_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final InAppReview _inAppReview = InAppReview.instance;

  @override
  void initState() {
    super.initState();
    RewardedAdHelper.warmUpIfEligible();
  }

  Future<void> _shareApp(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('share_split_bill',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ).tr(),
                const SizedBox(height: 8),
                Text('choose_the_store_link_you_want_to_send_so_your_friend_lands_on_the_right_download_page',
                  style: TextStyle(color: Colors.grey.shade600, height: 1.45),
                ).tr(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StoreShareCard(
                        icon: Icons.android_rounded,
                        title: 'share_to_android'.tr(),
                        subtitle: 'google_play_link'.tr(),
                        colors: const [Color(0xFF34A853), Color(0xFF0F9D58)],
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await SharePlus.instance.share(
                            ShareParams(
                              text:
                                  "Download Split Bill for Android\n\n${AppLinks.playStoreUrl}",
                              subject: "Split Bill on Google Play",
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StoreShareCard(
                        icon: Icons.apple_rounded,
                        title: 'share_to_iphone'.tr(),
                        subtitle: 'app_store_link'.tr(),
                        colors: const [Color(0xFF5E5CE6), Color(0xFF0A84FF)],
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await SharePlus.instance.share(
                            ShareParams(
                              text:
                                  "Download Split Bill for iPhone\n\n${AppLinks.appStoreUrl}",
                              subject: "Split Bill on the App Store",
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        // Fallback for debug/unpublished apps
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('in_app_rating_is_not_available_in_development_mode',
              ).tr(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('could_not_open_rating_dialog').tr()),
        );
      }
    }
  }

  Future<void> _contactUs() => ProfileDialogs.showContactUs(context);

  void _showLogoutDialog() => ProfileDialogs.showLogout(context);

  void _showDeleteAccountDialog() => ProfileDialogs.showDeleteAccount(context);

  void _showLocaleSheet(AppSettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SearchableSelectionSheet<LocaleOption>(
          title: 'choose_language'.tr(),
          searchHint: 'search_languages'.tr(),
          items: supportedLocaleOptions
              .map(
                (option) => SearchableSheetItem<LocaleOption>(
                  value: option,
                  title: option.englishName,
                  subtitle: option.nativeName,
                  searchTerms: [option.code, option.englishName, option.nativeName],
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEEF4FF), Color(0xFFF5F7FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.nativeName.characters.first,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          isSelected: (option) => option.code == settings.locale.languageCode,
          onSelected: (option) async {
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
  }

  void _showCurrencySheet(AppSettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SearchableSelectionSheet<CurrencyOption>(
          title: 'choose_currency'.tr(),
          searchHint: 'search_currencies'.tr(),
          items: supportedCurrencyOptions
              .map(
                (option) => SearchableSheetItem<CurrencyOption>(
                  value: option,
                  title: '${option.code} • ${option.name}',
                  subtitle: option.region,
                  searchTerms: [option.code, option.name, option.region, option.symbol],
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF7E8), Color(0xFFFFF1CC)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.symbol,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          isSelected: (option) => option.code == settings.currencyCode,
          onSelected: (option) async {
            await settings.updateCurrencyCode(option.code);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const LoginScreen();
    final settings = context.watch<AppSettingsProvider>();
    final selectedLocale = findLocaleOption(settings.locale.languageCode);
    final selectedCurrency = findCurrencyOption(settings.currencyCode);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        String name = data['displayName'] ?? user?.displayName ?? "User";
        String? photoUrl = data['photoUrl'];

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: CustomScrollView(
            slivers: [
              // 1. HEADER
              SliverToBoxAdapter(
                child: ProfileHeader(
                  name: name,
                  photoUrl: photoUrl,
                  phoneNumber: data['phoneNumber'],
                  userData: data,
                ),
              ),
              // 2. SETTINGS LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ProfileSectionTitle(title: 'preferences'.tr()),
                    ProfileCoolTile(
                      icon: Icons.language_rounded,
                      title: 'app_language'.tr(),
                      subtitle:
                          '${selectedLocale.englishName} • ${selectedLocale.nativeName}',
                      color: Colors.indigo,
                      compact: true,
                      onTap: () => _showLocaleSheet(settings),
                    ),
                    ProfileCoolTile(
                      icon: Icons.attach_money_rounded,
                      title: 'default_currency'.tr(),
                      subtitle:
                          '${selectedCurrency.code} • ${selectedCurrency.name} • ${selectedCurrency.region}',
                      color: Colors.teal,
                      compact: true,
                      onTap: () => _showCurrencySheet(settings),
                    ),
                    ProfileSectionTitle(title: 'personal'.tr()),
                    ProfileCoolTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'payment_methods'.tr(),
                      subtitle: 'manage_how_you_pay_and_receive'.tr(),
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentSettingsScreen(),
                        ),
                      ),
                    ),
                    ProfileCoolTile(
                      icon: Icons.groups_rounded,
                      title: 'my_groups'.tr(),
                      subtitle: 'view_and_manage_your_squads'.tr(),
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupsScreen()),
                      ),
                    ),

                    // Premium & Points Section
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        final isPremium = userData?['isPremium'] ?? false;

                        if (isPremium) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              ProfileSectionTitle(
                                title: 'premium_status'.tr(),
                              ),
                              const PremiumStatusCard(),
                            ],
                          );
                        }

                        final points = userData?['points'] ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            ProfileSectionTitle(
                              title: 'premium_and_points'.tr(),
                            ),
                            ScanPointsCard(points: points),
                            ProfileCoolTile(
                              icon: Icons.play_circle_filled_rounded,
                              title: 'watch_ad_for_points'.tr(),
                              subtitle: 'earn_1_point_per_rewarded_video'.tr(),
                              color: Colors.purple,
                              onTap: _showWatchAdConfirmation,
                            ),
                            ProfileCoolTile(
                              icon: Icons.workspace_premium_rounded,
                              title: 'upgrade_to_premium'.tr(),
                              subtitle: 'unlimited_scans_no_ads_lifetime'.tr(),
                              color: Colors.blue,
                              onTap: _showPremiumDialog,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    ProfileSectionTitle(title: 'support'.tr()),
                    ProfileCoolTile(
                      icon: Icons.share_rounded,
                      title: 'share_app'.tr(),
                      subtitle: 'gift_this_app_to_your_friends'.tr(),
                      color: Colors.blue,
                      onTap: () => _shareApp(context),
                    ),
                    ProfileCoolTile(
                      icon: Icons.star_rounded,
                      title: 'rate_us'.tr(),
                      subtitle: 'help_us_grow_with_5_stars'.tr(),
                      color: Colors.amber,
                      onTap: _rateApp,
                    ),
                    ProfileCoolTile(
                      icon: Icons.mail_rounded,
                      title: 'contact_us'.tr(),
                      subtitle: 'need_help_reach_out_to_us'.tr(),
                      color: Colors.teal,
                      onTap: _contactUs,
                    ),

                    const SizedBox(height: 20),
                    ProfileSectionTitle(title: 'account'.tr()),
                    ProfileCoolTile(
                      icon: Icons.logout_rounded,
                      title: 'logout'.tr(),
                      subtitle: 'sign_out_of_your_account'.tr(),
                      color: Colors.red,
                      isDestructive: true,
                      onTap: _showLogoutDialog,
                    ),
                    ProfileCoolTile(
                      icon: Icons.person_remove_rounded,
                      title: 'delete_account'.tr(),
                      subtitle: 'dangerous_and_irreversible'.tr(),
                      color: Colors.red,
                      isDestructive: true,
                      onTap: _showDeleteAccountDialog,
                    ),

                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      ProfileSectionTitle(title: 'developer'.tr()),
                      ProfileCoolTile(
                        icon: Icons.rocket_launch_rounded,
                        title: 'show_onboarding'.tr(),
                        subtitle: 'view_intro_screens'.tr(),
                        color: Colors.deepPurple,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NewOnboardingScreen(),
                          ),
                        ),
                      ),
                      ProfileCoolTile(
                        icon: Icons.data_usage_rounded,
                        title: 'seed_transactions'.tr(),
                        subtitle: 'add_4_test_bills'.tr(),
                        color: Colors.brown,
                        onTap: _seedTransactions,
                      ),
                    ],

                    const SizedBox(height: 40),
                    const VersionInfo(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWatchAdConfirmation() async {
    await AdModal.show(
      context,
      onWatchAd: () async {
        await _showRewardedAd();
      },
    );
  }

  Future<void> _showRewardedAd() async {
    // 1. If the ad is not ready, attempt to load it and show a professional loading message
    if (!RewardedAdHelper.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ad_is_initializing_please_try_again_in_a_few_seconds',
          ).tr(),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
        ),
      );

      try {
        await RewardedAdHelper.loadAd();
      } catch (e) {
        debugPrint("Ad loading failed: $e");
      }
      return;
    }

    // 2. Show the ad with robust error handling
    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('success_you_earned_1_scan_point').tr(),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          // Show a more formal dialog or detailed snackbar for the reviewer
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('ad_not_available').tr(),
              content: const Text(
                "We're having trouble reaching the ad server right now. "
                "Please ensure you have an active internet connection or try again later.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok').tr(),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _showPremiumDialog() async {
    final result = await PremiumModal.show(context);
    if (result == true && mounted) {
      // Premium purchased successfully, UI will auto-update via StreamBuilder
      setState(() {}); // Refresh to show premium status
    }
  }

  Future<void> _seedTransactions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Helper to create a participant
    Map<String, dynamic> makeParticipant({
      required String id,
      required String name,
      required double share,
      bool isPaid = false,
      bool isCurrentUser = false,
    }) {
      return {
        'id': id,
        'name': name,
        'photoUrl': isCurrentUser ? user.photoURL : null,
        'share': share,
        'isPaid': isPaid,
        'status': isPaid ? 'PAID' : 'PENDING',
        'phoneNumber': isCurrentUser ? user.phoneNumber : null,
      };
    }

    // 1. RECENT & UNFINISHED (Active, you owe money)
    final bill1 = {
      'storeName': "Dinner @ Cheez",
      'total': 1200.0,
      'status': 'PENDING',
      'date': Timestamp.now(), // Just now
      'items': [
        {
          'name': 'Cheese Platter',
          'price': 800.0,
          'qty': 1,
          'assignedTo': [user.uid, 'p2'],
        },
        {
          'name': 'Drinks',
          'price': 400.0,
          'qty': 4,
          'assignedTo': [user.uid, 'p2', 'p3'],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 533.33,
          isCurrentUser: true,
        ),
        makeParticipant(id: 'p2', name: "Sarah K.", share: 533.33),
        makeParticipant(id: 'p3', name: "Mike R.", share: 133.34),
      ],
      'participants_uids': [user.uid],
    };

    // 2. UNFINISHED (Pending, you haven't paid)
    final bill2 = {
      'storeName': "Uber to Airport",
      'total': 450.0,
      'status': 'PENDING',
      'date': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 5)),
      ),
      'items': [
        {
          'name': 'Ride',
          'price': 450.0,
          'qty': 1,
          'assignedTo': [user.uid, 'p2'],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 225.0,
          isCurrentUser: true,
        ),
        makeParticipant(id: 'p2', name: "John Doe", share: 225.0, isPaid: true),
      ],
      'participants_uids': [user.uid],
    };

    // 3. COMPLETED (Recent)
    final bill3 = {
      'storeName': "Starbucks Morning",
      'total': 185.0,
      'status': 'PAID',
      'date': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      'items': [
        {
          'name': 'Latte',
          'price': 185.0,
          'qty': 1,
          'assignedTo': [user.uid],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 185.0,
          isPaid: true,
          isCurrentUser: true,
        ),
      ],
      'participants_uids': [user.uid],
    };

    // 4. COMPLETED (Older)
    final bill4 = {
      'storeName': "Carrefour Grocery",
      'total': 2500.0,
      'status': 'PAID',
      'date': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 5)),
      ),
      'items': [
        {
          'name': 'Groceries',
          'price': 2500.0,
          'qty': 1,
          'assignedTo': [user.uid, 'p2', 'p3'],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 833.33,
          isPaid: true,
          isCurrentUser: true,
        ),
        makeParticipant(id: 'p2', name: "Mom", share: 833.33, isPaid: true),
        makeParticipant(id: 'p3', name: "Dad", share: 833.34, isPaid: true),
      ],
      'participants_uids': [user.uid],
    };

    // 5. UNFINISHED (Someone owes YOU - You are host)
    final bill5 = {
      'storeName': "Cinema Tickets",
      'total': 600.0,
      'status': 'PENDING',
      'date': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 2)),
      ),
      'items': [
        {
          'name': 'Tickets',
          'price': 600.0,
          'qty': 3,
          'assignedTo': [user.uid, 'p2', 'p3'],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 200.0,
          isPaid: true,
          isCurrentUser: true,
        ),
        makeParticipant(id: 'p2', name: "Ahmed", share: 200.0, isPaid: false),
        makeParticipant(id: 'p3', name: "Layla", share: 200.0, isPaid: false),
      ],
      'participants_uids': [user.uid],
    };

    // 6. COMPLETED (You paid, others paid)
    final bill6 = {
      'storeName': "Pizza Hut",
      'total': 850.0,
      'status': 'PAID',
      'date': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 2)),
      ),
      'items': [
        {
          'name': 'Super Supreme',
          'price': 850.0,
          'qty': 2,
          'assignedTo': [user.uid, 'p2'],
        },
      ],
      'participants': [
        makeParticipant(
          id: user.uid,
          name: "Me",
          share: 425.0,
          isPaid: true,
          isCurrentUser: true,
        ),
        makeParticipant(id: 'p2', name: "Coworker", share: 425.0, isPaid: true),
      ],
      'participants_uids': [user.uid],
    };

    final List<Map<String, dynamic>> dummyBills = [
      bill1,
      bill2,
      bill3,
      bill4,
      bill5,
      bill6,
    ];

    for (var bill in dummyBills) {
      await FirebaseFirestore.instance.collection('bills').add({
        'hostId': user.uid,
        'hostName': user.displayName,
        'storeName': bill['storeName'],
        'date': bill['date'],
        'total': bill['total'],
        'items': bill['items'],
        'charges': {
          'taxAmount': 0.0,
          'serviceCharge': 0.0,
          'tipAmount': 0.0,
          'discountAmount': 0.0,
        },
        'participants': bill['participants'],
        'participants_uids': bill['participants_uids'],
      });
    }

    if (mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('added_6_diverse_test_bills').tr()),
      );
    }
  }
}

class _StoreShareCard extends StatelessWidget {
  const _StoreShareCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
