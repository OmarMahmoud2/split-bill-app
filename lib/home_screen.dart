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
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';

/// The signed-in shell: Home, Groups, a raised Scan action, Activity, You.
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  static const _tabNames = ['home', 'groups', 'activity', 'you'];
  Stream<HomeLedgerState>? _ledger;
  Stream<bool>? _unread;
  StreamSubscription<HomeLedgerState>? _publish;
  LedgerMe? _me;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.showAds) unawaited(RevenueCatService.syncPremiumStatusIfNeeded());
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
    _publish = _ledger!.listen(HomeBalances.publish, onError: (Object e) {
      if (kDebugMode) debugPrint('home ledger error: $e');
    });
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
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    AppHaptics.selection();
    setState(() => _tab = i);
    if (i >= 0 && i < _tabNames.length) {
      AnalyticsService.instance.screen(_tabNames[i]);
    }
  }

  void _quickIou() {
    final s = HomeBalances.latest;
    showQuickIouSheet(context, people: s == null ? const [] : peopleAsMembers(s.summary));
  }

  void _startGroup() => Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CreateGroupScreen()),
  );

  void _openNew() => showNewSheet(context, onQuickIou: _quickIou, onStartGroup: _startGroup);

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
      onOpenGroups: () => _select(1),
      onOpenActivity: () => _select(2),
      onOpenProfile: () => _select(3),
      onOpenNotifications: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
    final pages = [
      HomeDashboard(
        stream: _ledger!,
        unread: _unread,
        actions: actions,
        onRetry: () => setState(_connect),
      ),
      GroupsScreen(state: _ledger, embedded: true),
      const ActivityScreen(embedded: true),
      const ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: p.background,
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _TabBar(
        index: _tab,
        onSelect: _select,
        onScan: () {
          AppHaptics.light();
          BillEntryPoints.scan(context);
        },
        onScanLongPress: _openNew,
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect, required this.onScan, required this.onScanLongPress});
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;
  final VoidCallback onScanLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget item(int i, IconData icon, IconData active, String label) {
      final on = i == index;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          child: InkWell(
            onTap: () => onSelect(i),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(on ? active : icon, size: 22, color: on ? p.textPrimary : p.textTertiary),
                    const SizedBox(height: 4),
                    Text(label, maxLines: 1, style: AppTypography.labelSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: on ? p.textPrimary : p.textTertiary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.background.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(0, AppIcons.home, AppIcons.home, 'home_tab_home'.tr()),
              item(1, AppIcons.people, AppIcons.people, 'groups'.tr()),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Semantics(
                      button: true,
                      label: 'home_scan_receipt'.tr(),
                      onLongPressHint: 'new_title'.tr(),
                      child: GestureDetector(
                        onLongPress: onScanLongPress,
                        child: Material(
                          color: p.accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onScan,
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: Icon(AppIcons.scan, color: p.onAccent, size: 26),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              item(2, AppIcons.chart, AppIcons.chart, 'activity_title'.tr()),
              item(3, AppIcons.you, AppIcons.you, 'home_tab_you'.tr()),
            ],
          ),
        ),
      ),
    );
  }
}
