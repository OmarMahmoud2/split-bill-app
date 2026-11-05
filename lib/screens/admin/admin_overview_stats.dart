import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';

/// Overview numbers the admin dashboard can compute honestly from the
/// `users` collection alone (no analytics backend): totals, sign-ups in the
/// period vs the period before, Pro users and a sign-up funnel.
class AdminOverviewStats {
  const AdminOverviewStats({
    required this.days,
    required this.totalUsers,
    required this.admins,
    required this.proUsers,
    required this.newSignups,
    required this.previousSignups,
    required this.missingContact,
    required this.newWithPhone,
    required this.newPro,
    required this.unknownSignupDate,
  });

  factory AdminOverviewStats.compute(
    Iterable<Map<String, dynamic>> users, {
    required int days,
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    final start = end.subtract(Duration(days: days));
    final prevStart = start.subtract(Duration(days: days));
    var total = 0, admins = 0, pro = 0, fresh = 0, prev = 0, missing = 0;
    var freshPhone = 0, freshPro = 0, unknown = 0;
    for (final u in users) {
      total++;
      final isPro = RevenueCatService.isUserActivePremium(u);
      if (u['isAdmin'] == true) admins++;
      if (isPro) pro++;
      final email = (u['email'] ?? '').toString().trim();
      final phone = (u['phoneNumber'] ?? '').toString().trim();
      if (email.isEmpty && phone.isEmpty) missing++;
      final created = createdAtOf(u);
      if (created == null) {
        unknown++;
        continue;
      }
      if (!created.isBefore(start) && !created.isAfter(end)) {
        fresh++;
        if (phone.isNotEmpty) freshPhone++;
        if (isPro) freshPro++;
      } else if (!created.isBefore(prevStart) && created.isBefore(start)) {
        prev++;
      }
    }
    return AdminOverviewStats(
      days: days,
      totalUsers: total,
      admins: admins,
      proUsers: pro,
      newSignups: fresh,
      previousSignups: prev,
      missingContact: missing,
      newWithPhone: freshPhone,
      newPro: freshPro,
      unknownSignupDate: unknown,
    );
  }

  static DateTime? createdAtOf(Map<String, dynamic> data) {
    final v = data['createdAt'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  final int days;
  final int totalUsers;
  final int admins;
  final int proUsers;
  final int newSignups;
  final int previousSignups;
  final int missingContact;
  final int newWithPhone;
  final int newPro;

  /// Users without a `createdAt`; excluded from period counts.
  final int unknownSignupDate;

  /// Pro share of all users, 0..100; null when there are no users.
  double? get proSharePercent =>
      totalUsers == 0 ? null : proUsers * 100 / totalUsers;

  /// Sign-up change vs the previous period in percent; null when the
  /// previous period had none (no honest percentage).
  double? get signupChangePercent => previousSignups == 0
      ? null
      : (newSignups - previousSignups) * 100 / previousSignups;
}
