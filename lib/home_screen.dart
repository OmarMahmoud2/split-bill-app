import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/profile_screen.dart';
import 'package:split_bill_app/bill_setup_screen.dart'; // New Entry Point
import 'package:split_bill_app/widgets/banner_ad_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/bill_tile.dart';
import 'package:split_bill_app/widgets/home/home_header.dart';
import 'package:split_bill_app/widgets/home/qr_dialog.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;

  // Navigation State
  int _selectedIndex = 0; // 0 = Home, 1 = Profile

  // Tab/Filter State
  late TabController _tabController;
  int _selectedFilterIndex = 0;

  // Stream State
  late Stream<QuerySnapshot> _billsStream;

  @override
  void initState() {
    super.initState();
    // 0 = Recent, 1 = Unfinished, 2 = Later
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilterIndex = _tabController.index;
        });
      }
    });

    // Initialize Stream once to prevent reloading on setState
    if (user != null) {
      _billsStream = FirebaseFirestore.instance
          .collection('bills')
          .where('participants_uids', arrayContains: user!.uid)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // --- LOGIC: Filter Bills ---
  List<QueryDocumentSnapshot> _filterBills(List<QueryDocumentSnapshot> docs) {
    DateTime now = DateTime.now();
    DateTime threeDaysAgo = now.subtract(const Duration(days: 3));

    // We sort by date descending first
    docs.sort((a, b) {
      Timestamp tA = (a.data() as Map)['date'] ?? Timestamp.now();
      Timestamp tB = (b.data() as Map)['date'] ?? Timestamp.now();
      return tB.compareTo(tA);
    });

    return docs.where((doc) {
      try {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        if (!data.containsKey('hostId') || !data.containsKey('participants')) {
          return false;
        }

        bool amIHost = data['hostId'] == user!.uid;
        List parts = data['participants'] ?? [];
        Timestamp? timestamp = data['date'];
        DateTime date = timestamp?.toDate() ?? DateTime(2000);

        // Determine Settled Status
        bool isSettled = false;
        if (amIHost) {
          // Host: Settled if ALL participants (including host) have paid
          bool anyPending = parts.any(
            (p) => p['status'] == 'PENDING' || p['status'] == 'REVIEW',
          );
          isSettled = !anyPending;
        } else {
          // Participant: Settled if I paid
          var me = parts.firstWhere(
            (p) => p['id'] == user!.uid,
            orElse: () => null,
          );
          isSettled = (me != null && me['status'] == 'PAID');
        }

        if (_selectedFilterIndex == 2) {
          // LATER TAB
          return data['status'] == 'UNATTEMPTED';
        } else if (_selectedFilterIndex == 0) {
          // RECENT TAB
          return !isSettled &&
              data['status'] != 'UNATTEMPTED' &&
              date.isAfter(threeDaysAgo);
        } else {
          // UNFINISHED TAB
          return !isSettled &&
              data['status'] != 'UNATTEMPTED' &&
              date.isBefore(threeDaysAgo);
        }
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Map<String, double> _calculateTotals(List<QueryDocumentSnapshot> docs) {
    double iOwe = 0.0;
    double owedToMe = 0.0;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>? ?? {};
      bool amIHost = data['hostId'] == user!.uid;
      List participants = data['participants'] ?? [];

      if (amIHost) {
        for (var p in participants) {
          if (p['id'] != user!.uid &&
              (p['status'] == 'PENDING' || p['status'] == 'REVIEW')) {
            owedToMe += (p['share'] as num? ?? 0.0).toDouble();
          }
        }
      } else {
        var me = participants.firstWhere(
          (p) => p['id'] == user!.uid,
          orElse: () => null,
        );
        if (me != null &&
            (me['status'] == 'PENDING' || me['status'] == 'REVIEW')) {
          iOwe += (me['share'] as num? ?? 0.0).toDouble();
        }
      }
    }
    return {'iOwe': iOwe, 'owedToMe': owedToMe};
  }

  // --- UI BUILDING BLOCKS ---

  void _onAddBillTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BillSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    Widget content;
    if (_selectedIndex == 1) {
      content = const ProfileScreen();
    } else {
      content = StreamBuilder<QuerySnapshot>(
        stream: _billsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(
              message: "Loading your dashboard...",
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final totals = _calculateTotals(allDocs);
          final filteredDocs = _filterBills(allDocs);

          return CustomScrollView(
            slivers: [
              // SCROLLABLE HEADER
              SliverToBoxAdapter(
                child: HomeHeader(
                  user: user,
                  iOwe: totals['iOwe']!,
                  owedToMe: totals['owedToMe']!,
                  onQrTap: (name, photoUrl) =>
                      QrDialog.show(context, name, photoUrl, user?.uid ?? ""),
                  getAvatarImage: ImageUtils.getAvatarImage,
                ),
              ),

              // Banner Ad (only for non-premium users)
              SliverToBoxAdapter(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final isPremium = userData?['isPremium'] ?? false;

                    if (isPremium) return const SizedBox.shrink();

                    return const Padding(
                      padding: EdgeInsets.only(
                        top: 10,
                        left: 25,
                        right: 25,
                        bottom: 10,
                      ),
                      child: BannerAdWidget(),
                    );
                  },
                ),
              ),

              // Filter Tabs
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "Recent"),
                      Tab(text: "Unfinished"),
                      Tab(text: "Later"),
                    ],
                  ),
                ),
              ),

              // Bills List
              if (filteredDocs.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return BillTile(
                      data: filteredDocs[index].data() as Map<String, dynamic>,
                      billId: filteredDocs[index].id,
                      currentUserId: user!.uid,
                    );
                  }, childCount: filteredDocs.length),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBody: true,
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddBillTap,
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        height: 70,
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavBarItem(0, CupertinoIcons.home, CupertinoIcons.house_fill),
            const SizedBox(width: 40),
            _buildNavBarItem(
              1,
              CupertinoIcons.settings,
              CupertinoIcons.settings_solid,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(
    int index,
    IconData iconOutline,
    IconData iconFilled,
  ) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutline,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              size: 28,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Lottie.asset('assets/animations/empty.json', height: 150),
            const SizedBox(height: 10),
            const Text("No bills found!", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
