import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/groups_screen.dart';
import 'package:split_bill_app/notifications_screen.dart';
import 'package:split_bill_app/profile_screen.dart';
import 'package:split_bill_app/screens/activity/activity_screen.dart';
import 'package:split_bill_app/screens/groups/create_group_screen.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/home/floating_tab_bar.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/layout/app_background.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';

/// The signed-in shell: Home, Groups, a raised New action, Activity, You.
///
/// One [watchHomeLedger] stream feeds Home, Groups and the friend screens,
/// and is published to [HomeBalances] for the home screen widgets.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showAds = true});

  /// Off in tests.
  final bool showAds;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Quick fade-through when the tab changes; the pages stay alive.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  int _tab = 0;
  static const _tabNames = ['home', 'activity', 'groups', 'you'];
  Stream<HomeLedgerState>? _ledger;
  Stream<bool>? _unread;
  StreamSubscription<HomeLedgerState>? _publish;
  LedgerMe? _me;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showAds)
      unawaited(RevenueCatService.syncPremiumStatusIfNeeded());
    AnalyticsService.instance.screen(_tabNames[0]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ledger == null) _connect();
  }

  void _connect() {
    _me = LedgerMe.current();
    final me = _me;
    if (me == null) return;
    final repo = LedgerRepository.instance;
    _ledger = watchHomeLedger(
      repo,
      me.uid,
      fallbackCurrency: preferredCurrency(context),
      looseLabel: 'friend_direct_label'.tr(),
    ).shareReplay(maxSize: 1);
    _unread = repo.watchHasUnread(me.uid).shareReplay(maxSize: 1);
    _publish?.cancel();
    _publish = _ledger!.listen(
      HomeBalances.publish,
      onError: (Object e) {
        if (kDebugMode) debugPrint('home ledger error: $e');
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.showAds) {
      unawaited(RevenueCatService.syncPremiumStatusIfNeeded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _publish?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    AppHaptics.light();
    setState(() => _tab = i);
    if (!AppMotion.reduceMotion(context)) _fade.forward(from: 0.2);
    if (i >= 0 && i < _tabNames.length) {
      AnalyticsService.instance.screen(_tabNames[i]);
    }
  }

  void _quickIou() {
    final s = HomeBalances.latest;
    showQuickIouSheet(
      context,
      people: s == null ? const [] : peopleAsMembers(s.summary),
    );
  }

  void _startGroup() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CreateGroupScreen(),
    ),
  );

  void _openNew() =>
      showNewSheet(context, onQuickIou: _quickIou, onStartGroup: _startGroup);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_me == null || _ledger == null) {
      return Scaffold(body: Center(child: Text('please_log_in_2'.tr())));
    }
    final actions = HomeActions(
      onNew: _openNew,
      onQuickIou: _quickIou,
      onStartGroup: _startGroup,
      onOpenGroups: () => _select(2),
      onOpenActivity: () => _select(1),
      onOpenProfile: () => _select(3),
      onOpenNotifications: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
    final pages = [
      HomeDashboard(
        stream: _ledger!,
        unread: _unread,
        actions: actions,
        onRetry: () => setState(_connect),
      ),
      const ActivityScreen(embedded: true),
      GroupsScreen(state: _ledger, embedded: true),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Content scrolls behind the frosted nav; each tab pads its list by
      // MediaQuery bottom padding, which here includes the bar's height.
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          FadeTransition(
            opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
            child: IndexedStack(index: _tab, children: pages),
          ),
          // Soft fade under the status bar so scrolled content never sits
          // hard against the clock.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      p.background,
                      p.background.withValues(alpha: 0.85),
                      p.background.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.7, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingTabBar(
        index: _tab,
        onSelect: _select,
        onNew: _openNew,
        onScan: () {
          AppHaptics.light();
          BillEntryPoints.scan(context);
        },
        newLabel: 'new_title'.tr(),
        scanHint: 'home_scan_receipt'.tr(),
        tabs: [
          TabSpec(AppIcons.home, AppIcons.homeFill, 'home_tab_home'.tr()),
          TabSpec(
            AppIcons.activity,
            AppIcons.activityFill,
            'activity_title'.tr(),
          ),
          TabSpec(AppIcons.groups, AppIcons.groupsFill, 'groups'.tr()),
          TabSpec(AppIcons.you, AppIcons.youFill, 'home_tab_you'.tr()),
        ],
      ),
    );
  }
}
