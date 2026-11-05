/// Pure filter, search and sort rules for the admin Users list.
///
/// Firestore has no full-text search, so the list works like this:
/// * Pages of 50 users are loaded ordered by document id (every user doc
///   has one, unlike `createdAt`), with "Load more" cursors.
/// * A query that looks like an email or a phone number additionally runs a
///   server-side prefix query on `email` / `phoneNumber`; a query that looks
///   like a uid is fetched by id. See [adminSearchKindFor].
/// * Everything else (names, partial matches) is matched client-side over
///   the pages loaded so far by [adminUserMatchesQuery].
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';

/// One user row: document id plus raw data.
class AdminUserEntry {
  const AdminUserEntry(this.uid, this.data);

  final String uid;
  final Map<String, dynamic> data;
}

enum AdminPlanFilter { all, free, pro }

enum AdminActivityFilter { all, active, inactive }

enum AdminUserSort { newest, oldest, nameAZ, lastActive, pointsHigh }

/// Users seen within this window count as active.
const Duration adminActiveThreshold = Duration(days: 30);

/// Page size for the paginated list.
const int adminUsersPageSize = 50;

class AdminUserFilters {
  const AdminUserFilters({
    this.query = '',
    this.plan = AdminPlanFilter.all,
    this.platform,
    this.activity = AdminActivityFilter.all,
    this.signedUpFrom,
    this.signedUpTo,
    this.sort = AdminUserSort.newest,
  });

  final String query;
  final AdminPlanFilter plan;

  /// 'ios', 'android', 'web' or null for any.
  final String? platform;
  final AdminActivityFilter activity;
  final DateTime? signedUpFrom;
  final DateTime? signedUpTo;
  final AdminUserSort sort;

  /// Number of non-default filters (search and sort excluded).
  int get activeCount =>
      (plan != AdminPlanFilter.all ? 1 : 0) +
      (platform != null ? 1 : 0) +
      (activity != AdminActivityFilter.all ? 1 : 0) +
      (signedUpFrom != null || signedUpTo != null ? 1 : 0);

  bool get isDefault =>
      activeCount == 0 && query.trim().isEmpty && sort == AdminUserSort.newest;

  AdminUserFilters copyWith({
    String? query,
    AdminPlanFilter? plan,
    String? Function()? platform,
    AdminActivityFilter? activity,
    DateTime? Function()? signedUpFrom,
    DateTime? Function()? signedUpTo,
    AdminUserSort? sort,
  }) => AdminUserFilters(
    query: query ?? this.query,
    plan: plan ?? this.plan,
    platform: platform != null ? platform() : this.platform,
    activity: activity ?? this.activity,
    signedUpFrom: signedUpFrom != null ? signedUpFrom() : this.signedUpFrom,
    signedUpTo: signedUpTo != null ? signedUpTo() : this.signedUpTo,
    sort: sort ?? this.sort,
  );
}

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Sign-up time (`createdAt`), if stored.
DateTime? adminCreatedAt(Map<String, dynamic> data) => _date(data['createdAt']);

/// Last time the app synced for this user: `lastActive` if present, else the
/// FCM token refresh time (written on every app resume).
DateTime? adminLastActive(Map<String, dynamic> data) =>
    _date(data['lastActive']) ?? _date(data['fcmTokenUpdatedAt']);

/// 'ios' | 'android' | 'web' | other lowercase value, from `fcmPlatform`
/// (token sync) or `loginPlatform` (sign-in); null when unknown.
String? adminPlatformOf(Map<String, dynamic> data) {
  for (final key in const ['fcmPlatform', 'loginPlatform', 'platform']) {
    final v = data[key]?.toString().trim().toLowerCase() ?? '';
    if (v.isEmpty) continue;
    if (v == 'macos' || v == 'ios') return 'ios';
    return v;
  }
  final email = data['email']?.toString() ?? '';
  if (email.endsWith('@privaterelay.appleid.com')) return 'ios';
  return null;
}

bool adminIsPro(Map<String, dynamic> data) =>
    RevenueCatService.isUserActivePremium(data);

bool adminIsActive(Map<String, dynamic> data, DateTime now) {
  final last = adminLastActive(data);
  return last != null && now.difference(last) <= adminActiveThreshold;
}

String adminDisplayName(Map<String, dynamic> data) =>
    (data['displayName']?.toString().trim() ?? '');

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Case-insensitive match on name, email, phone (digits) and uid.
bool adminUserMatchesQuery(AdminUserEntry e, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final d = e.data;
  final fields = [
    adminDisplayName(d).toLowerCase(),
    (d['email']?.toString() ?? '').toLowerCase(),
    e.uid.toLowerCase(),
  ];
  if (fields.any((f) => f.contains(q))) return true;
  final qd = _digits(q);
  if (qd.length >= 3) {
    return _digits(d['phoneNumber']?.toString() ?? '').contains(qd);
  }
  return false;
}

bool adminUserMatchesFilters(
  AdminUserEntry e,
  AdminUserFilters f,
  DateTime now,
) {
  final d = e.data;
  if (!adminUserMatchesQuery(e, f.query)) return false;
  if (f.plan == AdminPlanFilter.pro && !adminIsPro(d)) return false;
  if (f.plan == AdminPlanFilter.free && adminIsPro(d)) return false;
  if (f.platform != null && adminPlatformOf(d) != f.platform) return false;
  if (f.activity != AdminActivityFilter.all) {
    final active = adminIsActive(d, now);
    if (f.activity == AdminActivityFilter.active && !active) return false;
    if (f.activity == AdminActivityFilter.inactive && active) return false;
  }
  if (f.signedUpFrom != null || f.signedUpTo != null) {
    final created = adminCreatedAt(d);
    if (created == null) return false;
    if (f.signedUpFrom != null && created.isBefore(f.signedUpFrom!)) {
      return false;
    }
    if (f.signedUpTo != null) {
      // Inclusive end day.
      final end = DateTime(
        f.signedUpTo!.year,
        f.signedUpTo!.month,
        f.signedUpTo!.day,
      ).add(const Duration(days: 1));
      if (!created.isBefore(end)) return false;
    }
  }
  return true;
}

int _cmpDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Oldest first; unknown dates still last.
int _cmpDateAsc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _points(Map<String, dynamic> d) {
  final v = d['points'];
  if (v is num) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

/// Filters then sorts (stable on uid for ties).
List<AdminUserEntry> applyAdminUserFilters(
  Iterable<AdminUserEntry> users,
  AdminUserFilters f, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final list = users.where((e) => adminUserMatchesFilters(e, f, at)).toList();
  int cmp(AdminUserEntry a, AdminUserEntry b) {
    final r = switch (f.sort) {
      AdminUserSort.newest => _cmpDateDesc(
        adminCreatedAt(a.data),
        adminCreatedAt(b.data),
      ),
      AdminUserSort.oldest => _cmpDateAsc(
        adminCreatedAt(a.data),
        adminCreatedAt(b.data),
      ),
      AdminUserSort.nameAZ => adminDisplayName(
        a.data,
      ).toLowerCase().compareTo(adminDisplayName(b.data).toLowerCase()),
      AdminUserSort.lastActive => _cmpDateDesc(
        adminLastActive(a.data),
        adminLastActive(b.data),
      ),
      AdminUserSort.pointsHigh => _points(b.data).compareTo(_points(a.data)),
    };
    return r != 0 ? r : a.uid.compareTo(b.uid);
  }

  list.sort(cmp);
  return list;
}

/// Adds a page to the loaded list, replacing duplicates by uid (search
/// results and pages can overlap).
List<AdminUserEntry> mergeAdminUserPages(
  List<AdminUserEntry> loaded,
  Iterable<AdminUserEntry> incoming,
) {
  final byId = <String, AdminUserEntry>{for (final e in loaded) e.uid: e};
  for (final e in incoming) {
    byId[e.uid] = e;
  }
  return byId.values.toList();
}

enum AdminSearchKind { none, email, phone, uid, text }

/// Which server-side lookup helps for [query] (client-side matching always
/// runs as well).
AdminSearchKind adminSearchKindFor(String query) {
  final q = query.trim();
  if (q.isEmpty) return AdminSearchKind.none;
  if (q.contains('@')) return AdminSearchKind.email;
  if (RegExp(r'^\+?[0-9 ()\-]{4,}$').hasMatch(q)) return AdminSearchKind.phone;
  if (RegExp(r'^[A-Za-z0-9]{20,36}$').hasMatch(q)) return AdminSearchKind.uid;
  return AdminSearchKind.text;
}

/// Prefix-range end for a Firestore `>=`/`<` prefix query.
String adminPrefixEnd(String prefix) => '$prefix';
