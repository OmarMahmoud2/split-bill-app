import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/payment_settings_screen.dart';
import 'package:split_bill_app/groups_screen.dart';
import 'package:split_bill_app/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_header.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_cards.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_menu_widgets.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/screens/profile/widgets/version_info.dart';
import 'package:split_bill_app/screens/completed_bills_screen.dart';

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
    final box = context.findRenderObject() as RenderBox?;
    final Rect? sharePosition = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    final String message =
        "${AppLinks.shareText}\n\nDownload here: ${AppLinks.storeUrl}";

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: "Split Bill App",
        sharePositionOrigin: sharePosition,
      ),
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
            const SnackBar(
              content: Text(
                "In-app rating is not available in development mode.",
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open rating dialog.")),
        );
      }
    }
  }

  Future<void> _contactUs() => ProfileDialogs.showContactUs(context);

  void _showLogoutDialog() => ProfileDialogs.showLogout(context);

  void _showDeleteAccountDialog() => ProfileDialogs.showDeleteAccount(context);

  @override
  Widget build(BuildContext context) {
    if (user == null) return const LoginScreen();

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
                    const ProfileSectionTitle(title: "Personal"),
                    ProfileCoolTile(
                      icon: Icons.receipt_long_rounded,
                      title: "Completed Bills",
                      subtitle: "View your past bills history",
                      color: Colors.blueGrey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompletedBillsScreen(),
                        ),
                      ),
                    ),
                    // ProfileCoolTile(
                    //   icon: Icons.qr_code_2_rounded,
                    //   title: "My QR Code",
                    //   subtitle: "Show your code to friends",
                    //   color: Colors.indigo,
                    //   onTap: () =>
                    //       QrDialog.show(context, name, photoUrl, user!.uid),
                    // ),
                    ProfileCoolTile(
                      icon: Icons.tune_rounded,
                      title: "App Preferences",
                      subtitle: "Theme, language, and currency",
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    ProfileCoolTile(
                      icon: Icons.account_balance_wallet_rounded,
                      title: "Payment Methods",
                      subtitle: "Manage how you pay & receive",
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
                      title: "My Groups",
                      subtitle: "View and manage your squads",
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
                              const ProfileSectionTitle(
                                title: "Premium Status",
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
                            const ProfileSectionTitle(
                              title: "Premium & Points",
                            ),
                            ScanPointsCard(points: points),
                            ProfileCoolTile(
                              icon: Icons.play_circle_filled_rounded,
                              title: "Watch Ad for Points",
                              subtitle: "Earn 1 point per rewarded video",
                              color: Colors.purple,
                              onTap: _showWatchAdConfirmation,
                            ),
                            ProfileCoolTile(
                              icon: Icons.workspace_premium_rounded,
                              title: "Upgrade to Premium",
                              subtitle: "Unlimited scans • No ads • Lifetime",
                              color: Colors.blue,
                              onTap: _showPremiumDialog,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    const ProfileSectionTitle(title: "Support"),
                    ProfileCoolTile(
                      icon: Icons.share_rounded,
                      title: "Share App",
                      subtitle: "Gift this app to your friends",
                      color: Colors.blue,
                      onTap: () => _shareApp(context),
                    ),
                    ProfileCoolTile(
                      icon: Icons.star_rounded,
                      title: "Rate Us",
                      subtitle: "Help us grow with 5 stars",
                      color: Colors.amber,
                      onTap: _rateApp,
                    ),
                    ProfileCoolTile(
                      icon: Icons.mail_rounded,
                      title: "Contact Us",
                      subtitle: "Need help? Reach out to us",
                      color: Colors.teal,
                      onTap: _contactUs,
                    ),

                    const SizedBox(height: 20),
                    const ProfileSectionTitle(title: "Account"),
                    ProfileCoolTile(
                      icon: Icons.logout_rounded,
                      title: "Logout",
                      subtitle: "Sign out of your account",
                      color: Colors.red,
                      isDestructive: true,
                      onTap: _showLogoutDialog,
                    ),
                    ProfileCoolTile(
                      icon: Icons.person_remove_rounded,
                      title: "Delete Account",
                      subtitle: "Dangerous & Irreversible",
                      color: Colors.red,
                      isDestructive: true,
                      onTap: _showDeleteAccountDialog,
                    ),

                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      const ProfileSectionTitle(title: "Developer"),
                      ProfileCoolTile(
                        icon: Icons.rocket_launch_rounded,
                        title: "Show Onboarding",
                        subtitle: "View intro screens",
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
                        title: "Seed Transactions",
                        subtitle: "Add 4 test bills",
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
        const SnackBar(
          content: Text(
            "Ad is initializing... Please try again in a few seconds.",
          ),
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
            const SnackBar(
              content: Text("🎉 Success! You earned 1 scan point."),
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
              title: const Text("Ad Not Available"),
              content: const Text(
                "We're having trouble reaching the ad server right now. "
                "Please ensure you have an active internet connection or try again later.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
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
        const SnackBar(content: Text("Added 6 diverse test bills!")),
      );
    }
  }
}
