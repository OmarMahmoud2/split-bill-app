import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';

/// In-memory [LedgerRepository] for widget tests.
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository({
    List<LedgerGroup> groups = const [],
    Map<String, List<BillRecord>> groupBills = const {},
    Map<String, List<PaymentRecord>> groupPayments = const {},
    List<BillRecord> recentBills = const [],
    List<PaymentRecord> directPayments = const [],
    this.profiles = const {},
    this.activityPages = const [],
  }) : groups = BehaviorSubject.seeded(groups),
       recent = BehaviorSubject.seeded(recentBills),
       direct = BehaviorSubject.seeded(directPayments) {
    for (final g in groups) {
      bills[g.id] = BehaviorSubject.seeded(groupBills[g.id] ?? const []);
      payments[g.id] = BehaviorSubject.seeded(groupPayments[g.id] ?? const []);
    }
  }

  final BehaviorSubject<List<LedgerGroup>> groups;
  final bills = <String, BehaviorSubject<List<BillRecord>>>{};
  final payments = <String, BehaviorSubject<List<PaymentRecord>>>{};
  final BehaviorSubject<List<BillRecord>> recent;
  final BehaviorSubject<List<PaymentRecord>> direct;
  final Map<String, Map<String, dynamic>> profiles;
  final List<ActivityPage> activityPages;

  final recorded = <PaymentRecord>[];
  final created = <GroupDraft>[];
  final updates = <String, Map<String, dynamic>>{};
  int activityCalls = 0;
  bool failWrites = false;

  @override
  String? get currentUid => 'me';

  @override
  Stream<List<LedgerGroup>> watchMyGroups(String uid) => groups.stream;

  @override
  Stream<LedgerGroup?> watchGroup(String groupId) => groups.stream.map((l) {
    for (final g in l) {
      if (g.id == groupId) return g;
    }
    return null;
  });

  @override
  Stream<List<BillRecord>> watchGroupBills(String groupId, {String fallbackCurrency = 'USD'}) =>
      (bills[groupId] ??= BehaviorSubject.seeded(const [])).stream;

  @override
  Stream<List<PaymentRecord>> watchGroupPayments(String groupId) =>
      (payments[groupId] ??= BehaviorSubject.seeded(const [])).stream;

  @override
  Stream<List<BillRecord>> watchRecentBills(String uid, {String fallbackCurrency = 'USD'}) => recent.stream;

  @override
  Stream<List<PaymentRecord>> watchDirectPayments(String uid) => direct.stream;

  @override
  Stream<bool> watchHasUnread(String uid) => Stream.value(true);

  @override
  Future<ActivityPage> fetchActivity(String uid, {ActivityCursor? cursor, int limit = activityPageSize, String fallbackCurrency = 'USD'}) async {
    final i = activityCalls++;
    if (i >= activityPages.length) return const ActivityPage([], null);
    return activityPages[i];
  }

  @override
  Future<String> createGroup(GroupDraft draft, {required GroupMember creator}) async {
    if (failWrites) throw Exception('offline');
    created.add(draft);
    return 'new-group';
  }

  @override
  Future<void> updateGroup(String groupId, Map<String, dynamic> fields) async {
    updates[groupId] = fields;
  }

  @override
  Future<void> deleteGroup(String groupId) async {}

  @override
  Future<String> recordPayment(PaymentRecord payment) async {
    if (failWrites) throw Exception('offline');
    final id = 'p${recorded.length}';
    recorded.add(payment);
    final saved = PaymentRecord(
      id: id,
      kind: payment.kind,
      from: payment.from,
      to: payment.to,
      fromName: payment.fromName,
      toName: payment.toName,
      amountMinor: payment.amountMinor,
      currency: payment.currency,
      method: payment.method,
      groupId: payment.groupId,
      createdBy: payment.createdBy,
      createdAt: DateTime.now(),
    );
    if (payment.groupId != null) {
      final s = payments[payment.groupId]!;
      s.add([saved, ...s.value]);
    } else {
      direct.add([saved, ...direct.value]);
    }
    return id;
  }

  @override
  Future<void> deletePayment(PaymentRecord payment) async {}

  @override
  Future<Map<String, dynamic>?> publicProfile(String uid) async => profiles[uid];
}

const me = LedgerMe(uid: 'me', name: 'Omar Test');

Widget testApp(Widget home, {bool dark = false, TextDirection direction = TextDirection.ltr}) => MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => Directionality(
    textDirection: direction,
    child: MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
  ),
  home: home,
);

String plainText(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');
