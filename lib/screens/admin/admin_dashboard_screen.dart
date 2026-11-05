import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'admin_ai_usage_screen.dart';
import 'admin_overview_stats.dart';
import 'user_admin_detail_screen.dart';
import 'widgets/admin_avatar.dart';

enum _AdminUserStatusFilter { all, admins, premium, free }

enum _AdminUserContactFilter { all, withContact, missingContact }

enum _AdminUserSort { newest, oldest, nameAZ, nameZA, pointsHigh, premiumFirst }

/// Admin overview (v3 "Admin overview"): KPIs from the users collection,
/// sign-up funnel, AI usage entry and the searchable user list.
///
/// Admin-only: the screen checks `users/{uid}.isAdmin` itself and the
/// Firestore rules only let admins list users.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _ranges = [7, 30, 90];

  String _searchQuery = '';
  int _days = 7;
  _AdminUserStatusFilter _statusFilter = _AdminUserStatusFilter.all;
  _AdminUserContactFilter _contactFilter = _AdminUserContactFilter.all;
  _AdminUserSort _sort = _AdminUserSort.newest;
  final TextEditingController _searchController = TextEditingController();

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _selfStream =
      _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
  late final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _selfStream,
          builder: (context, selfSnap) {
            if (_selfStream != null &&
                selfSnap.connectionState == ConnectionState.waiting &&
                !selfSnap.hasData) {
              return const _DashboardSkeleton();
            }
            final isAdmin = selfSnap.data?.data()?['isAdmin'] == true;
            if (!isAdmin) {
              return Column(
                children: [
                  _topBar(context),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'adm3_not_admin_title'.tr(),
                      message: 'adm3_not_admin_message'.tr(),
                    ),
                  ),
                ],
              );
            }
            return StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (context, snapshot) =>
                  _buildAdminBody(context, snapshot),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => V3TopBar(
    large: true,
    leading: Navigator.of(context).canPop() ? V3IconButton.back(context) : null,
    title: 'adm3_title'.tr(),
    trailing: ProBadge(label: 'adm3_admin_only'.tr()),
  );

  Widget _buildAdminBody(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot> snapshot,
  ) {
    if (snapshot.hasError) {
      return Column(
        children: [
          _topBar(context),
          Expanded(child: ErrorState(onRetry: () => setState(() {}))),
        ],
      );
    }
    final isLoading = !snapshot.hasData;
    final allUsers = snapshot.data?.docs ?? [];
    final filteredUsers = _filterAndSortUsers(allUsers);
    final stats = AdminOverviewStats.compute(
      allUsers.map((d) => d.data() as Map<String, dynamic>),
      days: _days,
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _topBar(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
            child: Wrap(
              spacing: 6,
              children: [
                for (final d in _ranges)
                  V3ChoiceChip(
                    label: 'adm3_range_days'.tr(namedArgs: {'days': '$d'}),
                    selected: d == _days,
                    onTap: () => setState(() => _days = d),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: isLoading
              ? const _DashboardSkeleton(withTopBar: false)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KpiGrid(stats: stats),
                    _FunnelCard(stats: stats),
                    const SizedBox(height: 12),
                    SettingsCard(
                      children: [
                        SettingsRow(
                          key: const ValueKey('admin-ai-usage'),
                          title: 'adm3_ai_usage_row'.tr(),
                          subtitle: 'adm3_ai_usage_row_subtitle'.tr(),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminAiUsageScreen(initialDays: _days),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        SliverToBoxAdapter(
          child: SettingsSectionLabel('adm3_users_section'.tr()),
        ),
        SliverToBoxAdapter(
          child: _buildSearchHeader(
            context,
            totalCount: allUsers.length,
            shownCount: filteredUsers.length,
          ),
        ),
        ..._buildUsersSlivers(
          context,
          isLoading: isLoading,
          allUsers: allUsers,
          filteredUsers: filteredUsers,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _buildSearchHeader(
    BuildContext context, {
    required int totalCount,
    required int shownCount,
  }) {
    final p = context.palette;
    final activeFilters = _activeFilterCount;
    final isFiltered =
        activeFilters > 0 ||
        _searchQuery.trim().isNotEmpty ||
        _sort != _AdminUserSort.newest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'search_by_name_email_phone_or_uid'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: activeFilters > 0,
                label: Text('$activeFilters'),
                backgroundColor: p.accent,
                textColor: p.onAccent,
                child: V3IconButton(
                  icon: Icons.tune_rounded,
                  semanticLabel: 'admin_user_filters'.tr(),
                  onPressed: _openUserFiltersSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  shownCount == totalCount
                      ? 'admin_users_count'.tr(
                          namedArgs: {'count': totalCount.toString()},
                        )
                      : 'admin_users_filtered_count'.tr(
                          namedArgs: {
                            'shown': shownCount.toString(),
                            'total': totalCount.toString(),
                          },
                        ),
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
              if (isFiltered)
                TextButton(
                  onPressed: _resetFiltersAndSearch,
                  child: Text('admin_reset_filters'.tr()),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  List<Widget> _buildUsersSlivers(
    BuildContext context, {
    required bool isLoading,
    required List<QueryDocumentSnapshot<Object?>> allUsers,
    required List<QueryDocumentSnapshot<Object?>> filteredUsers,
  }) {
    if (isLoading) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonShimmer(
              child: Column(
                children: [
                  SkeletonListTile(),
                  SkeletonListTile(),
                  SkeletonListTile(),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (allUsers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            compact: true,
            icon: Icons.group_outlined,
            title: 'no_users_found'.tr(),
          ),
        ),
      ];
    }
    if (filteredUsers.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            compact: true,
            icon: Icons.manage_search_rounded,
            title: 'admin_no_matching_users'.tr(),
            actionLabel: 'admin_clear_filters'.tr(),
            onAction: _resetFiltersAndSearch,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UserTile(
                uid: userDoc.id,
                data: userData,
                name: _displayName(userData),
                points: _intValue(userData['points']),
              ),
            );
          },
        ),
      ),
    ];
  }

  void _openUserFiltersSheet() {
    var selectedStatus = _statusFilter;
    var selectedContact = _contactFilter;
    var selectedSort = _sort;

    PremiumBottomSheet.show<void>(
      context: context,
      isScrollable: true,
      child: StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final p = sheetContext.palette;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'admin_user_filters'.tr(),
                style: AppTypography.headlineMedium.copyWith(
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              V3FieldLabel('admin_status_filter'.tr()),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final filter in _AdminUserStatusFilter.values)
                    V3ChoiceChip(
                      label: _statusFilterLabel(filter),
                      selected: selectedStatus == filter,
                      onTap: () => setModalState(() => selectedStatus = filter),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              V3FieldLabel('admin_contact_filter'.tr()),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final filter in _AdminUserContactFilter.values)
                    V3ChoiceChip(
                      label: _contactFilterLabel(filter),
                      selected: selectedContact == filter,
                      onTap: () =>
                          setModalState(() => selectedContact = filter),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              V3FieldLabel('admin_sort'.tr()),
              for (final sort in _AdminUserSort.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: V3RadioTile(
                    selected: selectedSort == sort,
                    onTap: () => setModalState(() => selectedSort = sort),
                    child: Text(
                      _sortLabel(sort),
                      style: AppTypography.bodyLarge.copyWith(
                        color: p.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setModalState(() {
                        selectedStatus = _AdminUserStatusFilter.all;
                        selectedContact = _AdminUserContactFilter.all;
                        selectedSort = _AdminUserSort.newest;
                      }),
                      child: Text('admin_reset_filters'.tr()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = selectedStatus;
                          _contactFilter = selectedContact;
                          _sort = selectedSort;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: Text('admin_apply_filters'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Object?>> _filterAndSortUsers(
    List<QueryDocumentSnapshot<Object?>> users,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = users.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!_matchesSearch(doc.id, data, query)) return false;
      if (!_matchesStatus(data)) return false;
      if (!_matchesContact(data)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      switch (_sort) {
        case _AdminUserSort.oldest:
          return _timestampMillis(
            aData,
            'createdAt',
          ).compareTo(_timestampMillis(bData, 'createdAt'));
        case _AdminUserSort.nameAZ:
          return _displayName(
            aData,
          ).toLowerCase().compareTo(_displayName(bData).toLowerCase());
        case _AdminUserSort.nameZA:
          return _displayName(
            bData,
          ).toLowerCase().compareTo(_displayName(aData).toLowerCase());
        case _AdminUserSort.pointsHigh:
          return _intValue(
            bData['points'],
          ).compareTo(_intValue(aData['points']));
        case _AdminUserSort.premiumFirst:
          final premiumCompare = _boolInt(
            bData['isPremium'],
          ).compareTo(_boolInt(aData['isPremium']));
          if (premiumCompare != 0) return premiumCompare;
          return _displayName(
            aData,
          ).toLowerCase().compareTo(_displayName(bData).toLowerCase());
        case _AdminUserSort.newest:
          return _timestampMillis(
            bData,
            'createdAt',
          ).compareTo(_timestampMillis(aData, 'createdAt'));
      }
    });

    return filtered;
  }

  bool _matchesSearch(String uid, Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;

    final haystack = [
      data['displayName'],
      data['email'],
      data['phoneNumber'],
      data['loginPlatform'],
      data['isoCode'],
      uid,
    ].whereType<Object>().join(' ').toLowerCase();

    return haystack.contains(query);
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    switch (_statusFilter) {
      case _AdminUserStatusFilter.admins:
        return _boolValue(data['isAdmin']);
      case _AdminUserStatusFilter.premium:
        return _boolValue(data['isPremium']);
      case _AdminUserStatusFilter.free:
        return !_boolValue(data['isPremium']);
      case _AdminUserStatusFilter.all:
        return true;
    }
  }

  bool _matchesContact(Map<String, dynamic> data) {
    final hasContact = _hasContact(data);
    switch (_contactFilter) {
      case _AdminUserContactFilter.withContact:
        return hasContact;
      case _AdminUserContactFilter.missingContact:
        return !hasContact;
      case _AdminUserContactFilter.all:
        return true;
    }
  }

  bool _hasContact(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim();
    final phone = (data['phoneNumber'] ?? '').toString().trim();
    return email.isNotEmpty || phone.isNotEmpty;
  }

  String _displayName(Map<String, dynamic> data) {
    final name = (data['displayName'] ?? '').toString().trim();
    return name.isEmpty ? 'unknown_user'.tr() : name;
  }

  int _timestampMillis(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _boolValue(Object? value) => value == true;

  int _boolInt(Object? value) => _boolValue(value) ? 1 : 0;

  int get _activeFilterCount {
    var count = 0;
    if (_statusFilter != _AdminUserStatusFilter.all) count++;
    if (_contactFilter != _AdminUserContactFilter.all) count++;
    return count;
  }

  void _resetFiltersAndSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _statusFilter = _AdminUserStatusFilter.all;
      _contactFilter = _AdminUserContactFilter.all;
      _sort = _AdminUserSort.newest;
    });
  }

  String _statusFilterLabel(_AdminUserStatusFilter filter) {
    switch (filter) {
      case _AdminUserStatusFilter.admins:
        return 'admin_filter_admins'.tr();
      case _AdminUserStatusFilter.premium:
        return 'admin_filter_premium'.tr();
      case _AdminUserStatusFilter.free:
        return 'admin_filter_free'.tr();
      case _AdminUserStatusFilter.all:
        return 'admin_filter_all_users'.tr();
    }
  }

  String _contactFilterLabel(_AdminUserContactFilter filter) {
    switch (filter) {
      case _AdminUserContactFilter.withContact:
        return 'admin_contact_with_contact'.tr();
      case _AdminUserContactFilter.missingContact:
        return 'admin_contact_missing_contact'.tr();
      case _AdminUserContactFilter.all:
        return 'admin_contact_all'.tr();
    }
  }

  String _sortLabel(_AdminUserSort sort) {
    switch (sort) {
      case _AdminUserSort.oldest:
        return 'admin_sort_oldest'.tr();
      case _AdminUserSort.nameAZ:
        return 'admin_sort_name_az'.tr();
      case _AdminUserSort.nameZA:
        return 'admin_sort_name_za'.tr();
      case _AdminUserSort.pointsHigh:
        return 'admin_sort_points_high'.tr();
      case _AdminUserSort.premiumFirst:
        return 'admin_sort_premium_first'.tr();
      case _AdminUserSort.newest:
        return 'admin_sort_newest'.tr();
    }
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.uid,
    required this.data,
    required this.name,
    required this.points,
  });

  final String uid;
  final Map<String, dynamic> data;
  final String name;
  final int points;

  @override
  Widget build(BuildContext context) {
    final contact =
        (data['email'] as String?) ??
        (data['phoneNumber'] as String?) ??
        'no_contact_info'.tr();
    final isPremium = RevenueCatService.isUserActivePremium(data);
    final isAdmin = data['isAdmin'] == true;
    return SettingsCard(
      margin: EdgeInsets.zero,
      children: [
        SettingsRow(
          leading: AdminAvatar(
            name: name,
            photoUrl: data['photoUrl'] as String?,
            size: 40,
          ),
          title: name,
          subtitle:
              '$contact · ${'adm3_points_count'.tr(namedArgs: {'count': '$points'})}',
          trailing: isAdmin
              ? ProBadge(label: 'admin'.tr().toUpperCase())
              : (isPremium ? const ProBadge() : null),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserAdminDetailScreen(uid: uid, userData: data),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final AdminOverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final nf = NumberFormat.decimalPattern('en');
    final change = stats.signupChangePercent;
    final share = stats.proSharePercent;
    final cards = <_Kpi>[
      _Kpi(
        'adm3_kpi_total_users'.tr(),
        nf.format(stats.totalUsers),
        'adm3_kpi_admins_caption'.tr(namedArgs: {'count': '${stats.admins}'}),
        p.textSecondary,
      ),
      _Kpi(
        'adm3_kpi_new_signups'.tr(),
        nf.format(stats.newSignups),
        change == null
            ? 'adm3_kpi_vs_previous'.tr(
                namedArgs: {
                  'count': '${stats.previousSignups}',
                  'days': '${stats.days}',
                },
              )
            : 'adm3_kpi_change'.tr(
                namedArgs: {
                  'percent':
                      '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(0)}',
                },
              ),
        change == null ? p.textSecondary : (change >= 0 ? p.accent : p.owe),
      ),
      _Kpi(
        'adm3_kpi_pro_users'.tr(),
        nf.format(stats.proUsers),
        share == null
            ? '—'
            : 'adm3_kpi_pro_share'.tr(
                namedArgs: {'percent': share.toStringAsFixed(1)},
              ),
        p.textSecondary,
      ),
      _Kpi(
        'adm3_kpi_missing_contact'.tr(),
        nf.format(stats.missingContact),
        'adm3_kpi_missing_caption'.tr(),
        p.textSecondary,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in cards)
                SizedBox(
                  width: width,
                  child: _KpiCard(kpi: k),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.caption, this.captionColor);
  final String label;
  final String value;
  final String caption;
  final Color captionColor;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kpi.label,
              style: AppTypography.labelSmall.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              kpi.value,
              style: AppTypography.headlineLarge.copyWith(
                color: p.textPrimary,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            Text(
              kpi.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(color: kpi.captionColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.stats});

  final AdminOverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final steps = [
      ('adm3_funnel_signed_up'.tr(), stats.newSignups),
      ('adm3_funnel_phone'.tr(), stats.newWithPhone),
      ('adm3_funnel_pro'.tr(), stats.newPro),
    ];
    final top = stats.newSignups == 0 ? 1 : stats.newSignups;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'adm3_funnel_title'.tr(namedArgs: {'days': '${stats.days}'}),
            style: AppTypography.labelMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 10),
          for (final (label, value) in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MergeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        label,
                        style: AppTypography.labelSmall.copyWith(
                          color: p.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 10,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(color: p.surfaceVariant),
                              ),
                              FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: (value / top).clamp(0.0, 1.0),
                                child: ColoredBox(color: p.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$value',
                        textAlign: TextAlign.end,
                        style: AppTypography.amountSmall.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({this.withTopBar = true});

  final bool withTopBar;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withTopBar) ...[
              const Skeleton.line(width: 120, height: 28),
              const SizedBox(height: 16),
            ],
            const Row(
              children: [
                Expanded(
                  child: Skeleton(
                    height: 88,
                    borderRadius: AppRadii.cardRadius,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Skeleton(
                    height: 88,
                    borderRadius: AppRadii.cardRadius,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Skeleton(height: 110, borderRadius: AppRadii.cardRadius),
          ],
        ),
      ),
    );
  }
}
