import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:split_bill_app/services/admin_account_api.dart';
import 'package:split_bill_app/services/admin_user_actions.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'admin_user_filters.dart';
import 'widgets/admin_avatar.dart';
import 'widgets/send_notification_sheet.dart';

/// Bills and groups a user is part of.
class AdminUserCounts {
  const AdminUserCounts({this.bills, this.groups});
  final int? bills;
  final int? groups;
}

/// Admin: everything about one user and every admin action (v3 "User
/// detail"). Each action asks for confirmation, shows a success or error
/// toast, and is written with an `adminAudit` entry by [AdminUserActions].
class UserAdminDetailScreen extends StatefulWidget {
  const UserAdminDetailScreen({
    super.key,
    required this.uid,
    required this.userData,
    @visibleForTesting this.userStream,
    @visibleForTesting this.actions,
    @visibleForTesting this.adminUid,
    @visibleForTesting this.loadCounts,
    @visibleForTesting this.loadBills,
    @visibleForTesting this.notificationSender,
  });

  final String uid;
  final Map<String, dynamic> userData;
  final Stream<Map<String, dynamic>?>? userStream;
  final AdminUserActions? actions;
  final String? adminUid;
  final Future<AdminUserCounts> Function()? loadCounts;
  final Future<List<Map<String, dynamic>>> Function()? loadBills;
  final Future<bool> Function({
    required String targetUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  })?
  notificationSender;

  static String platformLabel(Map<String, dynamic> data) =>
      switch (adminPlatformOf(data)) {
        'ios' => 'iOS',
        'android' => 'Android',
        'web' => 'Web',
        null => '',
        final other => other,
      };

  @override
  State<UserAdminDetailScreen> createState() => _UserAdminDetailScreenState();
}

class _UserAdminDetailScreenState extends State<UserAdminDetailScreen> {
  late final String _adminUid =
      widget.adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  late final AdminUserActions _actions =
      widget.actions ??
      AdminUserActions(
        backend: FirestoreAdminActionBackend(),
        adminUid: _adminUid,
        accountDisabler: (uid, {required disabled, reason}) =>
            disableAccountViaBackend(uid, disabled: disabled, reason: reason),
      );
  late final Stream<Map<String, dynamic>?> _userStream =
      widget.userStream ??
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots()
          .map((s) => s.data());
  late final Future<AdminUserCounts> _counts = _loadCounts();
  late Future<List<Map<String, dynamic>>> _bills = _loadBills();
  bool _busy = false;

  String get uid => widget.uid;

  Future<AdminUserCounts> _loadCounts() async {
    if (widget.loadCounts != null) return widget.loadCounts!();
    final db = FirebaseFirestore.instance;
    int? bills, groups;
    try {
      bills =
          (await db
                  .collection('bills')
                  .where('participants_uids', arrayContains: uid)
                  .count()
                  .get())
              .count;
    } catch (_) {}
    try {
      groups =
          (await db
                  .collection('groups')
                  .where('memberIds', arrayContains: uid)
                  .count()
                  .get())
              .count;
    } catch (_) {}
    return AdminUserCounts(bills: bills, groups: groups);
  }

  Future<List<Map<String, dynamic>>> _loadBills() async {
    if (widget.loadBills != null) return widget.loadBills!();
    final snap = await FirebaseFirestore.instance
        .collection('bills')
        .where('participants_uids', arrayContains: uid)
        .limit(100)
        .get();
    final bills = [for (final d in snap.docs) d.data()];
    bills.sort((a, b) {
      final da = a['date'], db = b['date'];
      if (da is! Timestamp && db is! Timestamp) return 0;
      if (da is! Timestamp) return 1;
      if (db is! Timestamp) return -1;
      return db.compareTo(da);
    });
    return bills;
  }

  String _date(Object? v, String locale) {
    final d = v is Timestamp
        ? v.toDate()
        : v is DateTime
        ? v
        : v is String
        ? DateTime.tryParse(v)
        : null;
    return d == null ? '—' : DateFormat.yMMMd(locale).format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userStream,
      builder: (context, snapshot) {
        final p = context.palette;
        if (snapshot.hasData && snapshot.data == null) {
          return Scaffold(
            backgroundColor: p.canvas,
            body: SafeArea(
              child: Column(
                children: [
                  V3TopBar(
                    leading: V3IconButton.back(context),
                    title: 'adm3_user_title'.tr(),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'adm3_user_gone'.tr(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data ?? widget.userData;
        return Scaffold(
          backgroundColor: p.canvas,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: V3TopBar(
                    leading: V3IconButton.back(context),
                    title: 'adm3_user_title'.tr(),
                  ),
                ),
                SliverToBoxAdapter(child: _content(context, data)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> data) {
    final p = context.palette;
    final locale = context.locale.toLanguageTag();
    final name = adminDisplayName(data).isEmpty
        ? 'unknown_user'.tr()
        : adminDisplayName(data);
    final isPro = adminIsPro(data);
    final isAdmin = data['isAdmin'] == true;
    final suspended = data['suspended'] == true;
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final platform = UserAdminDetailScreen.platformLabel(data);
    final joined = adminCreatedAt(data);
    final caption = [
      if (joined != null)
        'adm3_joined'.tr(
          namedArgs: {'date': DateFormat.yMMMd(locale).format(joined)},
        ),
      if (platform.isNotEmpty) platform,
      isAdmin
          ? 'admin'.tr()
          : (isPro ? 'adm3_plan_pro'.tr() : 'adm3_plan_free'.tr()),
    ].join(' · ');
    final isoCode = data['isoCode'] as String?;
    var country = '—';
    if (isoCode != null && isoCode.isNotEmpty) {
      country = countries
          .where((c) => c.code == isoCode)
          .map((c) => c.name)
          .firstWhere((_) => true, orElse: () => isoCode);
    }
    final phone = (data['phoneNumber'] as String?)?.trim() ?? '';
    final email = (data['email'] as String?)?.trim() ?? '';
    final appVersion = (data['appVersion'] ?? data['loginAppVersion'])
        ?.toString();
    final willRenew = data['premiumWillRenew'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: Row(
            children: [
              AdminAvatar(
                name: name,
                photoUrl: data['photoUrl'] as String?,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.titleLarge.copyWith(
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      caption,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (suspended)
          Container(
            key: const ValueKey('admin-suspended-banner'),
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.oweSoft,
              borderRadius: AppRadii.rowRadius,
            ),
            child: Text(
              'adm3_suspended_note'.tr(
                namedArgs: {'date': _date(data['suspendedAt'], locale)},
              ),
              style: AppTypography.titleSmall.copyWith(color: p.oweInk),
            ),
          ),
        SettingsSectionLabel('adm3_section_profile'.tr()),
        SettingsCard(
          children: [
            _InfoRow('email'.tr(), email.isEmpty ? 'not_provided'.tr() : email),
            _InfoRow('phone'.tr(), phone.isEmpty ? 'not_provided'.tr() : phone),
            _InfoRow('country'.tr(), country),
            _InfoRow('adm3_platform'.tr(), platform.isEmpty ? '—' : platform),
            if (appVersion != null && appVersion.isNotEmpty)
              _InfoRow('adm3_app_version'.tr(), appVersion),
            _InfoRow('adm3_signed_up'.tr(), _date(data['createdAt'], locale)),
            _InfoRow(
              'adm3_last_active'.tr(),
              _date(adminLastActive(data), locale),
            ),
            _InfoRow('UID', uid, selectable: true),
          ],
        ),
        SettingsSectionLabel('adm3_section_plan'.tr()),
        SettingsCard(
          children: [
            _InfoRow(
              'adm3_plan'.tr(),
              data['premiumStore'] == 'admin_override' && isPro
                  ? 'adm3_plan_override'.tr()
                  : (isPro ? 'adm3_plan_pro'.tr() : 'adm3_plan_free'.tr()),
            ),
            if ((data['premiumProductId'] ?? '').toString().isNotEmpty)
              _InfoRow('adm3_product'.tr(), '${data['premiumProductId']}'),
            if ((data['premiumStore'] ?? '').toString().isNotEmpty)
              _InfoRow('adm3_store'.tr(), '${data['premiumStore']}'),
            _InfoRow(
              'adm3_premium_expires'.tr(),
              data['premiumExpiresAt'] == null
                  ? (isPro ? 'adm3_never'.tr() : '—')
                  : _date(data['premiumExpiresAt'], locale),
            ),
            if (willRenew is bool)
              _InfoRow(
                'adm3_auto_renew'.tr(),
                willRenew ? 'adm3_yes'.tr() : 'adm3_no'.tr(),
              ),
            if ((data['premiumEnvironment'] ?? '').toString().isNotEmpty)
              _InfoRow(
                'adm3_environment'.tr(),
                '${data['premiumEnvironment']}',
              ),
          ],
        ),
        SettingsSectionLabel('adm3_section_activity'.tr()),
        FutureBuilder<AdminUserCounts>(
          future: _counts,
          builder: (context, snap) {
            String n(int? v) => snap.hasData && v != null ? '$v' : '—';
            return SettingsCard(
              children: [
                _InfoRow('adm3_points_balance'.tr(), '$points', numeric: true),
                _InfoRow('adm3_bills'.tr(), n(snap.data?.bills), numeric: true),
                _InfoRow(
                  'adm3_groups'.tr(),
                  n(snap.data?.groups),
                  numeric: true,
                ),
                _InfoRow('adm3_ai_usage_user'.tr(), 'adm3_not_available'.tr()),
              ],
            );
          },
        ),
        _actionsSection(context, data, points, isPro, isAdmin, suspended),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'adm3_audit_caption'.tr(),
            style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
          ),
        ),
        SettingsSectionLabel('user_bills_summary'.tr()),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _bills,
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorState.inline(
                message: 'error_loading_bills'.tr(),
                onRetry: () => setState(() => _bills = _loadBills()),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SkeletonCard(),
              );
            }
            final bills = snap.data!;
            if (bills.isEmpty) {
              return EmptyState(
                compact: true,
                icon: Icons.receipt_long_outlined,
                title: 'no_bills_found'.tr(),
              );
            }
            return SettingsCard(
              children: [for (final b in bills) _billRow(context, b, locale)],
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _destructiveButton({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final p = context.palette;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: p.error,
        side: BorderSide(color: p.errorSoft),
      ),
      child: Text(label),
    );
  }

  Widget _actionsSection(
    BuildContext context,
    Map<String, dynamic> data,
    int points,
    bool isPro,
    bool isAdmin,
    bool suspended,
  ) {
    final phone = (data['phoneNumber'] as String?)?.trim() ?? '';
    final self = uid == _adminUid;
    final busy = _busy;
    const gap = SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionLabel('adm3_section_actions'.tr()),
          OutlinedButton(
            key: const ValueKey('admin-grant-10'),
            onPressed: busy ? null : () => _changePoints(points, points + 10),
            child: Text('adm3_grant_points'.tr(namedArgs: {'count': '10'})),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final delta in const [5, 50, -5, -10])
                V3ChoiceChip(
                  label: delta > 0 ? '+$delta' : '−${-delta}',
                  selected: false,
                  onTap: () => _changePoints(points, points + delta),
                ),
              V3ChoiceChip(
                label: 'set_custom_points'.tr(),
                selected: false,
                onTap: () => _customPoints(points),
              ),
            ],
          ),
          gap,
          OutlinedButton(
            key: const ValueKey('admin-send-message'),
            onPressed: busy ? null : () => _sendNotification(data),
            child: Text('adm3_send_message'.tr()),
          ),
          gap,
          isPro
              ? _destructiveButton(
                  key: const ValueKey('admin-premium'),
                  label: 'revoke_premium'.tr(),
                  onPressed: busy ? null : () => _togglePremium(true),
                )
              : OutlinedButton(
                  key: const ValueKey('admin-premium'),
                  onPressed: busy ? null : () => _togglePremium(false),
                  child: Text('grant_premium'.tr()),
                ),
          gap,
          if (isAdmin)
            _destructiveButton(
              key: const ValueKey('admin-role'),
              label: 'adm3_remove_admin'.tr(),
              onPressed: busy || self ? null : () => _toggleAdmin(true),
            )
          else
            OutlinedButton(
              key: const ValueKey('admin-role'),
              onPressed: busy ? null : () => _toggleAdmin(false),
              child: Text('adm3_make_admin'.tr()),
            ),
          if (self && isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'adm3_self_note'.tr(),
                style: AppTypography.bodySmall.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          gap,
          if (suspended)
            OutlinedButton(
              key: const ValueKey('admin-suspend'),
              onPressed: busy ? null : () => _toggleSuspend(true),
              child: Text('adm3_unsuspend'.tr()),
            )
          else
            _destructiveButton(
              key: const ValueKey('admin-suspend'),
              label: 'adm3_suspend'.tr(),
              onPressed: busy || self ? null : () => _toggleSuspend(false),
            ),
          if (phone.isNotEmpty) ...[
            gap,
            _destructiveButton(
              key: const ValueKey('admin-reset-phone'),
              label: 'adm3_reset_phone'.tr(),
              onPressed: busy ? null : () => _resetPhone(phone),
            ),
          ],
          gap,
          _destructiveButton(
            key: const ValueKey('admin-delete-data'),
            label: 'adm3_delete_data'.tr(),
            onPressed: busy || self ? null : () => _deleteData(data),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- actions

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    if (destructive) AppHaptics.warning();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              key: const ValueKey('admin-confirm'),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: p.error,
                      foregroundColor: p.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  /// Runs [run], then shows a success or error toast.
  Future<bool> _perform(
    Future<AdminActionResult> Function() run, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      final result = await run();
      if (!mounted) return true;
      AppToast.show(
        context,
        message: result.auditLogged
            ? success
            : '$success ${'adm3_audit_not_logged'.tr()}',
        type: AppToastType.success,
      );
      return true;
    } on AdminActionException catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: switch (e.error) {
            AdminActionError.selfTarget => 'adm3_self_note'.tr(),
            AdminActionError.invalidAmount => 'adm3_points_invalid'.tr(),
            AdminActionError.confirmationMismatch =>
              'adm3_delete_mismatch'.tr(),
          },
          type: AppToastType.error,
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'adm3_update_failed'.tr(),
          type: AppToastType.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePoints(int from, int to) async {
    final target = to.clamp(0, adminMaxPoints);
    final ok = await _confirm(
      title: 'adm3_points_confirm_title'.tr(),
      message: 'adm3_points_confirm'.tr(
        namedArgs: {'from': '$from', 'to': '$target'},
      ),
      action: 'adm3_save'.tr(),
      destructive: target < from,
    );
    if (!ok || !mounted) return;
    await _perform(
      () => _actions.setPoints(uid, currentPoints: from, newPoints: target),
      success: 'adm3_points_saved'.tr(namedArgs: {'count': '$target'}),
    );
  }

  Future<void> _customPoints(int current) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('set_custom_points'.tr()),
        content: TextField(
          key: const ValueKey('admin-custom-points'),
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: 'points'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: Text('adm3_save'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    if (value < 0 || value > adminMaxPoints) {
      AppToast.show(
        context,
        message: 'adm3_points_invalid'.tr(),
        type: AppToastType.error,
      );
      return;
    }
    await _changePoints(current, value);
  }

  Future<void> _togglePremium(bool currentlyPro) async {
    final label = currentlyPro ? 'revoke_premium'.tr() : 'grant_premium'.tr();
    final ok = await _confirm(
      title: label,
      message: currentlyPro
          ? 'adm3_premium_revoke_confirm'.tr()
          : 'adm3_premium_grant_confirm'.tr(),
      action: label,
      destructive: currentlyPro,
    );
    if (!ok || !mounted) return;
    await _perform(
      () => _actions.setPremium(uid, grant: !currentlyPro),
      success: currentlyPro
          ? 'adm3_premium_revoked'.tr()
          : 'adm3_premium_granted'.tr(),
    );
  }

  Future<void> _toggleAdmin(bool currentlyAdmin) async {
    final label = currentlyAdmin
        ? 'adm3_remove_admin'.tr()
        : 'adm3_make_admin'.tr();
    final ok = await _confirm(
      title: label,
      message: 'confirm_admin_toggle'.tr(),
      action: label,
      destructive: currentlyAdmin,
    );
    if (!ok || !mounted) return;
    await _perform(
      () => _actions.setAdmin(uid, admin: !currentlyAdmin),
      success: 'user_updated_success'.tr(),
    );
  }

  Future<void> _toggleSuspend(bool currentlySuspended) async {
    final label = currentlySuspended
        ? 'adm3_unsuspend'.tr()
        : 'adm3_suspend'.tr();
    final ok = await _confirm(
      title: label,
      message: currentlySuspended
          ? 'adm3_unsuspend_confirm'.tr()
          : 'adm3_suspend_confirm'.tr(),
      action: label,
      destructive: !currentlySuspended,
    );
    if (!ok || !mounted) return;
    await _perform(
      () => _actions.setSuspended(uid, suspended: !currentlySuspended),
      success: currentlySuspended
          ? 'adm3_unsuspended'.tr()
          : 'adm3_suspended'.tr(),
    );
  }

  Future<void> _resetPhone(String phone) async {
    AppHaptics.warning();
    var clear = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final p = ctx.palette;
          return AlertDialog(
            title: Text('adm3_reset_phone'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'adm3_reset_phone_confirm'.tr(namedArgs: {'phone': phone}),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: clear,
                  onChanged: (v) => setLocal(() => clear = v ?? false),
                  title: Text('adm3_reset_phone_clear'.tr()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                key: const ValueKey('admin-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.error,
                  foregroundColor: p.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('adm3_reset_phone'.tr()),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    await _perform(
      () => _actions.resetPhoneClaim(uid, phone: phone, clearPhone: clear),
      success: 'adm3_phone_reset_done'.tr(),
    );
  }

  Future<void> _deleteData(Map<String, dynamic> data) async {
    AppHaptics.warning();
    final email = (data['email'] as String?)?.trim();
    final target = deleteConfirmationTarget(uid: uid, email: email);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final p = ctx.palette;
          final valid = isDeleteConfirmationValid(
            typed: controller.text,
            uid: uid,
            email: email,
          );
          return AlertDialog(
            title: Text('adm3_delete_data'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('adm3_delete_data_message'.tr()),
                  const SizedBox(height: 12),
                  Text(
                    'adm3_delete_type'.tr(namedArgs: {'target': target}),
                    style: AppTypography.titleSmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('admin-delete-confirm-field'),
                    controller: controller,
                    autocorrect: false,
                    onChanged: (_) => setLocal(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                key: const ValueKey('admin-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.error,
                  foregroundColor: p.onError,
                ),
                onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                child: Text('adm3_delete_data'.tr()),
              ),
            ],
          );
        },
      ),
    );
    final typed = controller.text;
    controller.dispose();
    if (ok != true || !mounted) return;
    final done = await _perform(
      () => _actions.deleteUserData(
        uid,
        typedConfirmation: typed,
        email: email,
        phone: data['phoneNumber'] as String?,
      ),
      success: 'adm3_delete_done'.tr(),
    );
    if (done && mounted) Navigator.of(context).maybePop();
  }

  void _sendNotification(Map<String, dynamic> data) {
    PremiumBottomSheet.show(
      context: context,
      child: SendNotificationSheet(
        targetUid: uid,
        targetToken: data['fcmToken'] as String?,
        userName: (data['displayName'] as String?) ?? 'user'.tr(),
        sender: widget.notificationSender,
        onSent: (title) {
          _actions
              .logNotificationSent(uid, title: title)
              .catchError((_) => const AdminActionResult(auditLogged: false));
        },
      ),
    );
  }

  Widget _billRow(
    BuildContext context,
    Map<String, dynamic> billData,
    String locale,
  ) {
    final storeName = billData['storeName'] ?? 'unknown_store'.tr();
    final total = (billData['total'] as num? ?? 0.0).toDouble();
    final currency = billData['currencyCode'] ?? 'USD';
    final date = billData['date'];
    final status = billData['status'] ?? 'PENDING';
    return SettingsRow(
      title: storeName.toString(),
      subtitle: [
        CurrencyUtils.format(total, currencyCode: currency),
        if (date is Timestamp) DateFormat.yMMMd(locale).format(date.toDate()),
      ].join(' · '),
      trailing: status == 'PAID' ? SoftChip('adm3_paid'.tr()) : null,
      onTap: () => PremiumBottomSheet.show(
        context: context,
        isScrollable: true,
        child: _BillSummarySheet(billData: billData),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
    this.label,
    this.value, {
    this.numeric = false,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool numeric;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = numeric
        ? AppTypography.amountSmall.copyWith(
            color: p.textPrimary,
            fontFeatures: AppTypography.tabularFigures,
          )
        : AppTypography.bodyMedium.copyWith(color: p.textPrimary);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: p.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selectable
                    ? SelectableText(
                        value,
                        style: style,
                        textAlign: TextAlign.end,
                      )
                    : Text(
                        value,
                        style: style,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillSummarySheet extends StatelessWidget {
  final Map<String, dynamic> billData;

  const _BillSummarySheet({required this.billData});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final storeName = billData['storeName'] ?? 'unknown_store'.tr();
    final total = (billData['total'] as num? ?? 0.0).toDouble();
    final currency = billData['currencyCode'] ?? 'USD';
    final participants = billData['participants'] as List<dynamic>? ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeName.toString(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '${'total_bill'.tr()}: ${CurrencyUtils.format(total, currencyCode: currency)}',
          style: AppTypography.amount.copyWith(color: p.textPrimary),
        ),
        Divider(height: 28, color: p.borderSubtle),
        Text(
          'participants'.tr(),
          style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 8),
        ...participants.map((part) {
          final pName = (part is Map ? part['name'] : null) ?? 'a_friend'.tr();
          final pShare = ((part is Map ? part['share'] : null) as num? ?? 0.0)
              .toDouble();
          final isPaid = part is Map && part['status'] == 'PAID';
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 18,
                  color: isPaid ? p.accent : p.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$pName',
                    style: AppTypography.bodyLarge.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Text(
                  isPaid ? 'adm3_paid'.tr() : 'adm3_pending'.tr(),
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  CurrencyUtils.format(pShare, currencyCode: currency),
                  style: AppTypography.amountSmall.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
