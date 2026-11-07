import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'admin_ai_usage_screen.dart';
import 'admin_overview_stats.dart';
import 'admin_users_screen.dart';

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

  int _days = 7;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _selfStream =
      _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
  late final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
                      icon: AppIcons.lock,
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
                          key: const ValueKey('admin-users'),
                          title: 'adm3_users_row'.tr(),
                          subtitle: 'adm3_users_row_subtitle'.tr(
                            namedArgs: {'count': '${stats.totalUsers}'},
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminUsersScreen(),
                            ),
                          ),
                        ),
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
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
          boxShadow: p.softShadow,
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
        boxShadow: p.softShadow,
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
