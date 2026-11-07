import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/admin_users_source.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'admin_user_filters.dart';
import 'user_admin_detail_screen.dart';
import 'widgets/admin_avatar.dart';

/// Admin: every user, 50 per page, with search and filters.
///
/// Admin-only: checks `users/{me}.isAdmin`; the rules also only let admins
/// list `users`. Search is a mix of server prefix queries (email, phone, uid)
/// and client-side matching over loaded pages — see admin_user_filters.dart.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    @visibleForTesting this.source,
    @visibleForTesting this.debugIsAdmin,
    @visibleForTesting this.now,
    @visibleForTesting this.onOpenUser,
  });

  final AdminUsersSource? source;
  final bool? debugIsAdmin;
  final DateTime? now;
  final void Function(BuildContext context, AdminUserEntry user)? onOpenUser;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final AdminUsersSource _source =
      widget.source ?? FirestoreAdminUsersSource();
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  bool? _isAdmin;
  List<AdminUserEntry> _loaded = const [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  AdminUserFilters _filters = const AdminUserFilters();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _checkAdmin();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    var admin = widget.debugIsAdmin;
    if (admin == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      try {
        final doc = uid == null
            ? null
            : await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();
        admin = doc?.data()?['isAdmin'] == true;
      } catch (_) {
        admin = false;
      }
    }
    if (!mounted) return;
    setState(() => _isAdmin = admin);
    if (admin == true) _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _source.fetchPage(limit: adminUsersPageSize);
      if (!mounted) return;
      setState(() {
        _loaded = page.entries;
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _source.fetchPage(
        cursor: _cursor,
        limit: adminUsersPageSize,
      );
      if (!mounted) return;
      setState(() {
        _loaded = mergeAdminUserPages(_loaded, page.entries);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppToast.show(
        context,
        message: 'adm3_load_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  void _onQueryChanged(String value) {
    setState(() => _filters = _filters.copyWith(query: value));
    _debounce?.cancel();
    final kind = adminSearchKindFor(value);
    if (kind == AdminSearchKind.none || kind == AdminSearchKind.text) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final found = await _source.search(value);
        if (!mounted) return;
        setState(() => _loaded = mergeAdminUserPages(_loaded, found));
      } catch (_) {
        // Client-side matching still runs over the loaded pages.
      }
    });
  }

  void _reset() {
    _searchController.clear();
    setState(() => _filters = const AdminUserFilters());
  }

  void _open(AdminUserEntry e) {
    if (widget.onOpenUser != null) {
      widget.onOpenUser!(context, e);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserAdminDetailScreen(uid: e.uid, userData: e.data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final top = V3TopBar(
      leading: V3IconButton.back(context),
      title: 'adm3_users_title'.tr(),
      trailing: ProBadge(label: 'adm3_admin_only'.tr()),
    );
    Widget body;
    if (_isAdmin == null) {
      body = const _ListSkeleton();
    } else if (_isAdmin == false) {
      body = EmptyState(
        icon: AppIcons.lock,
        title: 'adm3_not_admin_title'.tr(),
        message: 'adm3_not_admin_message'.tr(),
      );
    } else if (_error != null) {
      body = ErrorState(onRetry: _loadFirst);
    } else {
      body = _list(context);
    }
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            top,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final p = context.palette;
    final shown = applyAdminUserFilters(_loaded, _filters, now: widget.now);
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(child: _searchHeader(context, shown.length)),
        if (_loading)
          const SliverToBoxAdapter(child: _ListSkeleton())
        else if (_loaded.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              compact: true,
              icon: AppIcons.people,
              title: 'no_users_found'.tr(),
            ),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              compact: true,
              icon: AppIcons.search,
              title: 'admin_no_matching_users'.tr(),
              message: _hasMore ? 'adm3_search_load_more_hint'.tr() : null,
              actionLabel: 'admin_clear_filters'.tr(),
              onAction: _reset,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AdminUserTile(
                  entry: shown[i],
                  onTap: () => _open(shown[i]),
                ),
              ),
            ),
          ),
        if (!_loading && _hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: OutlinedButton(
                key: const ValueKey('admin-users-load-more'),
                onPressed: _loadingMore ? null : _loadMore,
                child: _loadingMore
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.textSecondary,
                        ),
                      )
                    : Text('adm3_load_more'.tr()),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }

  Widget _searchHeader(BuildContext context, int shownCount) {
    final p = context.palette;
    final active = _filters.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('admin-users-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'search_by_name_email_phone_or_uid'.tr(),
                    prefixIcon: const Icon(AppIcons.search),
                    suffixIcon: _filters.query.isNotEmpty
                        ? IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).deleteButtonTooltip,
                            icon: const Icon(AppIcons.close),
                            onPressed: () {
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 10),
              Badge(
                isLabelVisible: active > 0,
                label: Text('$active'),
                backgroundColor: p.accent,
                textColor: p.onAccent,
                child: V3IconButton(
                  key: const ValueKey('admin-users-filters'),
                  icon: AppIcons.filter,
                  semanticLabel: 'admin_user_filters'.tr(),
                  onPressed: _openFilters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _filters.isDefault
                      ? 'adm3_users_loaded'.tr(
                          namedArgs: {'count': '${_loaded.length}'},
                        )
                      : 'admin_users_filtered_count'.tr(
                          namedArgs: {
                            'shown': '$shownCount',
                            'total': '${_loaded.length}',
                          },
                        ),
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
              if (!_filters.isDefault)
                TextButton(
                  onPressed: _reset,
                  child: Text('admin_reset_filters'.tr()),
                ),
            ],
          ),
          if (adminSearchKindFor(_filters.query) == AdminSearchKind.text)
            Text(
              'adm3_search_note'.tr(),
              style: AppTypography.bodySmall.copyWith(color: p.textTertiary),
            ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await PremiumBottomSheet.show<AdminUserFilters>(
      context: context,
      isScrollable: true,
      child: AdminUserFiltersSheet(initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }
}

/// One user in the list.
class AdminUserTile extends StatelessWidget {
  const AdminUserTile({super.key, required this.entry, required this.onTap});

  final AdminUserEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = entry.data;
    final name = adminDisplayName(d).isEmpty
        ? 'unknown_user'.tr()
        : adminDisplayName(d);
    final contact =
        (d['email'] as String?) ??
        (d['phoneNumber'] as String?) ??
        'no_contact_info'.tr();
    final points = (d['points'] as num?)?.toInt() ?? 0;
    final Widget? badge = d['suspended'] == true
        ? ProBadge(label: 'adm3_suspended_badge'.tr())
        : d['isAdmin'] == true
        ? ProBadge(label: 'admin'.tr().toUpperCase())
        : adminIsPro(d)
        ? const ProBadge()
        : null;
    return SettingsCard(
      margin: EdgeInsets.zero,
      children: [
        SettingsRow(
          leading: AdminAvatar(
            name: name,
            photoUrl: d['photoUrl'] as String?,
            size: 40,
          ),
          title: name,
          subtitle:
              '$contact · ${'adm3_points_count'.tr(namedArgs: {'count': '$points'})}',
          trailing: badge,
          onTap: onTap,
        ),
      ],
    );
  }
}

/// Filter + sort sheet; pops with the new [AdminUserFilters].
class AdminUserFiltersSheet extends StatefulWidget {
  const AdminUserFiltersSheet({super.key, required this.initial});

  final AdminUserFilters initial;

  @override
  State<AdminUserFiltersSheet> createState() => _AdminUserFiltersSheetState();
}

class _AdminUserFiltersSheetState extends State<AdminUserFiltersSheet> {
  late AdminUserFilters _f = widget.initial;

  Widget _group(String label, List<Widget> chips) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          label,
          style: AppTypography.titleSmall.copyWith(
            color: context.palette.textPrimary,
          ),
        ),
      ),
      Wrap(spacing: 6, runSpacing: 6, children: chips),
    ],
  );

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: _f.signedUpFrom != null && _f.signedUpTo != null
          ? DateTimeRange(start: _f.signedUpFrom!, end: _f.signedUpTo!)
          : null,
    );
    if (picked != null) {
      setState(
        () => _f = _f.copyWith(
          signedUpFrom: () => picked.start,
          signedUpTo: () => picked.end,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final locale = context.locale.toLanguageTag();
    final range = _f.signedUpFrom == null
        ? 'adm3_pick_dates'.tr()
        : '${DateFormat.yMMMd(locale).format(_f.signedUpFrom!)} – '
              '${DateFormat.yMMMd(locale).format(_f.signedUpTo ?? DateTime.now())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'admin_user_filters'.tr(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        _group('adm3_filter_plan'.tr(), [
          for (final v in AdminPlanFilter.values)
            V3ChoiceChip(
              label: switch (v) {
                AdminPlanFilter.all => 'adm3_any'.tr(),
                AdminPlanFilter.free => 'adm3_plan_free'.tr(),
                AdminPlanFilter.pro => 'adm3_plan_pro'.tr(),
              },
              selected: _f.plan == v,
              onTap: () => setState(() => _f = _f.copyWith(plan: v)),
            ),
        ]),
        _group('adm3_filter_platform'.tr(), [
          for (final v in const [null, 'ios', 'android', 'web'])
            V3ChoiceChip(
              label: switch (v) {
                'ios' => 'iOS',
                'android' => 'Android',
                'web' => 'Web',
                _ => 'adm3_any'.tr(),
              },
              selected: _f.platform == v,
              onTap: () => setState(() => _f = _f.copyWith(platform: () => v)),
            ),
        ]),
        _group('adm3_filter_activity'.tr(), [
          for (final v in AdminActivityFilter.values)
            V3ChoiceChip(
              label: switch (v) {
                AdminActivityFilter.all => 'adm3_any'.tr(),
                AdminActivityFilter.active => 'adm3_active_30'.tr(),
                AdminActivityFilter.inactive => 'adm3_inactive'.tr(),
              },
              selected: _f.activity == v,
              onTap: () => setState(() => _f = _f.copyWith(activity: v)),
            ),
        ]),
        _group('adm3_filter_signed_up'.tr(), [
          V3ChoiceChip(
            label: range,
            selected: _f.signedUpFrom != null,
            onTap: _pickRange,
          ),
          if (_f.signedUpFrom != null)
            V3ChoiceChip(
              label: 'admin_reset_filters'.tr(),
              selected: false,
              onTap: () => setState(
                () => _f = _f.copyWith(
                  signedUpFrom: () => null,
                  signedUpTo: () => null,
                ),
              ),
            ),
        ]),
        _group('admin_sort'.tr(), [
          for (final v in AdminUserSort.values)
            V3ChoiceChip(
              label: switch (v) {
                AdminUserSort.newest => 'admin_sort_newest'.tr(),
                AdminUserSort.oldest => 'admin_sort_oldest'.tr(),
                AdminUserSort.nameAZ => 'admin_sort_name_az'.tr(),
                AdminUserSort.lastActive => 'adm3_sort_last_active'.tr(),
                AdminUserSort.pointsHigh => 'admin_sort_points_high'.tr(),
              },
              selected: _f.sort == v,
              onTap: () => setState(() => _f = _f.copyWith(sort: v)),
            ),
        ]),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(
                  () => _f = AdminUserFilters(query: widget.initial.query),
                ),
                child: Text('admin_reset_filters'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('admin-filters-apply'),
                onPressed: () => Navigator.pop(context, _f),
                child: Text('admin_apply_filters'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: SkeletonShimmer(
      child: Column(
        children: [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
      ),
    ),
  );
}
