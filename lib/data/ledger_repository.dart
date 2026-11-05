/// Data access for groups, ledgers, payments and the activity feed.
///
/// Read cost (per screen open, listeners included):
/// * Home: my groups (1 query) + one ledger per active group (bills by
///   `groupId` + `groups/{id}/payments`) + my last [recentBillsLimit] bills
///   + my direct payments/IOUs. Totals only count open (unsettled) shares, and
///   history is paged in Activity instead of loading every bill.
/// * Activity: one page = [activityPageSize] bills + [activityPageSize]
///   payments (a collection-group query over `payments`), merged by date.
///   Derived from existing docs, so no fan-out writes or extra storage.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:split_bill_app/data/activity.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/services/public_profile_service.dart';

const int recentBillsLimit = 200;
const int groupBillsLimit = 500;
const int activityPageSize = 20;

/// Opaque cursor for [LedgerRepository.fetchActivity].
class ActivityCursor {
  const ActivityCursor({this.bills, this.payments, this.billsDone = false, this.paymentsDone = false});
  final Object? bills;
  final Object? payments;
  final bool billsDone;
  final bool paymentsDone;
  bool get isDone => billsDone && paymentsDone;
}

class ActivityPage {
  const ActivityPage(this.items, this.next);
  final List<ActivityItem> items;

  /// Null when there is nothing more to load.
  final ActivityCursor? next;
}

/// What a new group or trip starts with.
class GroupDraft {
  const GroupDraft({
    required this.name,
    required this.type,
    required this.currency,
    required this.members,
    this.budgetMinor,
    this.startDate,
    this.endDate,
    this.simplifyDebts = true,
  });

  final String name;
  final GroupType type;
  final String currency;
  final List<GroupMember> members;
  final int? budgetMinor;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool simplifyDebts;
}

abstract class LedgerRepository {
  /// The app-wide instance. Tests replace it.
  static LedgerRepository instance = FirestoreLedgerRepository();

  String? get currentUid;

  Stream<List<LedgerGroup>> watchMyGroups(String uid);
  Stream<LedgerGroup?> watchGroup(String groupId);
  Stream<List<BillRecord>> watchGroupBills(String groupId, {String fallbackCurrency});
  Stream<List<PaymentRecord>> watchGroupPayments(String groupId);
  Stream<List<BillRecord>> watchRecentBills(String uid, {String fallbackCurrency});

  /// Top-level payments and IOUs between [uid] and someone else.
  Stream<List<PaymentRecord>> watchDirectPayments(String uid);

  Future<ActivityPage> fetchActivity(
    String uid, {
    ActivityCursor? cursor,
    int limit = activityPageSize,
    String fallbackCurrency,
  });

  Future<String> createGroup(GroupDraft draft, {required GroupMember creator});
  Future<void> updateGroup(String groupId, Map<String, dynamic> fields);
  Future<void> deleteGroup(String groupId);

  /// Records a payment (in the group when [PaymentRecord.groupId] is set) or
  /// a Quick IOU. Returns the new id.
  Future<String> recordPayment(PaymentRecord payment);
  Future<void> deletePayment(PaymentRecord payment);

  /// Whether the user has unread inbox notifications (Home's bell dot).
  Stream<bool> watchHasUnread(String uid);

  /// The recipient's saved payment methods (publicProfiles).
  Future<Map<String, dynamic>?> publicProfile(String uid);
}

class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository({FirebaseFirestore? db, String? Function()? uid})
    : _dbOverride = db,
      _uid = uid;

  final FirebaseFirestore? _dbOverride;
  final String? Function()? _uid;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  @override
  String? get currentUid =>
      _uid != null ? _uid() : FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _bills => _db.collection('bills');

  @override
  Stream<List<LedgerGroup>> watchMyGroups(String uid) => _groups
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((s) {
        final list = [for (final d in s.docs) LedgerGroup.fromMap(d.id, d.data())];
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  @override
  Stream<LedgerGroup?> watchGroup(String groupId) => _groups
      .doc(groupId)
      .snapshots()
      .map((d) => d.exists ? LedgerGroup.fromMap(d.id, d.data()!) : null);

  @override
  Stream<List<BillRecord>> watchGroupBills(String groupId, {String fallbackCurrency = 'USD'}) => _bills
      .where('groupId', isEqualTo: groupId)
      .orderBy('date', descending: true)
      .limit(groupBillsLimit)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              BillRecord.fromMap(d.id, d.data(), fallbackCurrency: fallbackCurrency),
          ]);

  @override
  Stream<List<PaymentRecord>> watchGroupPayments(String groupId) => _groups
      .doc(groupId)
      .collection('payments')
      .orderBy('createdAt', descending: true)
      .limit(groupBillsLimit)
      .snapshots()
      .map((s) => [for (final d in s.docs) PaymentRecord.fromMap(d.id, d.data())]);

  @override
  Stream<List<BillRecord>> watchRecentBills(String uid, {String fallbackCurrency = 'USD'}) => _bills
      .where('participants_uids', arrayContains: uid)
      .orderBy('date', descending: true)
      .limit(recentBillsLimit)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              BillRecord.fromMap(d.id, d.data(), fallbackCurrency: fallbackCurrency),
          ]);

  @override
  Stream<List<PaymentRecord>> watchDirectPayments(String uid) => _db
      .collection('payments')
      .where('participants_uids', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .limit(recentBillsLimit)
      .snapshots()
      .map((s) => [for (final d in s.docs) PaymentRecord.fromMap(d.id, d.data())]);

  @override
  Future<ActivityPage> fetchActivity(
    String uid, {
    ActivityCursor? cursor,
    int limit = activityPageSize,
    String fallbackCurrency = 'USD',
  }) async {
    final c = cursor ?? const ActivityCursor();
    Query<Map<String, dynamic>> billsQ = _bills
        .where('participants_uids', arrayContains: uid)
        .orderBy('date', descending: true)
        .limit(limit);
    Query<Map<String, dynamic>> payQ = _db
        .collectionGroup('payments')
        .where('participants_uids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (c.bills is DocumentSnapshot) billsQ = billsQ.startAfterDocument(c.bills! as DocumentSnapshot);
    if (c.payments is DocumentSnapshot) payQ = payQ.startAfterDocument(c.payments! as DocumentSnapshot);

    final results = await Future.wait([
      c.billsDone ? Future.value(null) : billsQ.get(),
      c.paymentsDone ? Future.value(null) : payQ.get(),
    ]);
    final billDocs = results[0]?.docs ?? const [];
    final payDocs = results[1]?.docs ?? const [];
    final billItems = [
      for (final d in billDocs)
        activityFromBill(BillRecord.fromMap(d.id, d.data(), fallbackCurrency: fallbackCurrency), uid),
    ];
    final payItems = [
      for (final d in payDocs) activityFromPayment(PaymentRecord.fromMap(d.id, d.data()), uid),
    ];
    final merged = mergeNewestFirst(billItems, payItems, (i) => i.date, limit);
    final billsDone = c.billsDone || (billDocs.length < limit && merged.takenFromA == billDocs.length);
    final paymentsDone = c.paymentsDone || (payDocs.length < limit && merged.takenFromB == payDocs.length);
    final next = ActivityCursor(
      bills: merged.takenFromA > 0 ? billDocs[merged.takenFromA - 1] : c.bills,
      payments: merged.takenFromB > 0 ? payDocs[merged.takenFromB - 1] : c.payments,
      billsDone: billsDone,
      paymentsDone: paymentsDone,
    );
    return ActivityPage(merged.items, next.isDone ? null : next);
  }

  @override
  Future<String> createGroup(GroupDraft draft, {required GroupMember creator}) async {
    final members = [
      creator,
      ...draft.members.where((m) => m.id != creator.id),
    ];
    final ref = await _groups.add({
      'name': draft.name.trim(),
      'createdBy': creator.id,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [for (final m in members) m.toMap()],
      'memberIds': [for (final m in members) m.id],
      'type': draft.type.name,
      'currency': draft.currency,
      if (draft.budgetMinor != null) 'budgetMinor': draft.budgetMinor,
      if (draft.startDate != null) 'startDate': Timestamp.fromDate(draft.startDate!),
      if (draft.endDate != null) 'endDate': Timestamp.fromDate(draft.endDate!),
      'simplifyDebts': draft.simplifyDebts,
    });
    return ref.id;
  }

  @override
  Future<void> updateGroup(String groupId, Map<String, dynamic> fields) =>
      _groups.doc(groupId).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Stream<bool> watchHasUnread(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isNotEmpty);

  @override
  Future<void> deleteGroup(String groupId) => _groups.doc(groupId).delete();

  @override
  Future<String> recordPayment(PaymentRecord payment) async {
    final uids = <String>{payment.from, payment.to}.toList();
    final col = payment.groupId != null
        ? _groups.doc(payment.groupId).collection('payments')
        : _db.collection('payments');
    final ref = await col.add(payment.toCreateMap(participantUids: uids));
    return ref.id;
  }

  @override
  Future<void> deletePayment(PaymentRecord payment) {
    final col = payment.groupId != null
        ? _groups.doc(payment.groupId).collection('payments')
        : _db.collection('payments');
    return col.doc(payment.id).delete();
  }

  @override
  Future<Map<String, dynamic>?> publicProfile(String uid) =>
      PublicProfileService.fetch(uid);
}

/// Everything Home needs, recomputed whenever any source changes.
class HomeLedgerState {
  const HomeLedgerState({
    required this.groups,
    required this.groupInputs,
    required this.recentBills,
    required this.directPayments,
    required this.summary,
  });

  final List<LedgerGroup> groups;
  final List<GroupLedgerInput> groupInputs;
  final List<BillRecord> recentBills;
  final List<PaymentRecord> directPayments;
  final BalanceSummary summary;

  GroupLedgerInput? input(String groupId) {
    for (final g in groupInputs) {
      if (g.group.id == groupId) return g;
    }
    return null;
  }
}

/// Combines the repository streams into [HomeLedgerState] for [uid].
/// Archived groups are left out of totals.
Stream<HomeLedgerState> watchHomeLedger(
  LedgerRepository repo,
  String uid, {
  String fallbackCurrency = 'USD',
  String looseLabel = '',
}) {
  final groupsWithLedgers = repo.watchMyGroups(uid).switchMap((groups) {
    final active = groups.where((g) => !g.archived).toList();
    if (active.isEmpty) {
      return Stream.value((groups, const <GroupLedgerInput>[]));
    }
    return Rx.combineLatestList([
      for (final g in active)
        Rx.combineLatest2(
          repo.watchGroupBills(g.id, fallbackCurrency: g.currency ?? fallbackCurrency),
          repo.watchGroupPayments(g.id),
          (List<BillRecord> b, List<PaymentRecord> p) =>
              GroupLedgerInput(group: g, bills: b, payments: p),
        ),
    ]).map((inputs) => (groups, inputs));
  });

  return Rx.combineLatest3(
    groupsWithLedgers,
    repo.watchRecentBills(uid, fallbackCurrency: fallbackCurrency),
    repo.watchDirectPayments(uid),
    (
      (List<LedgerGroup>, List<GroupLedgerInput>) g,
      List<BillRecord> bills,
      List<PaymentRecord> payments,
    ) {
      final summary = buildCounterparties(
        me: uid,
        groups: g.$2,
        looseBills: bills,
        directPayments: payments,
        looseLabel: looseLabel,
      );
      return HomeLedgerState(
        groups: g.$1,
        groupInputs: g.$2,
        recentBills: bills,
        directPayments: payments,
        summary: summary,
      );
    },
  );
}

/// Latest balances for other features (home screen widgets): call
/// [HomeBalances.latest] or listen to [HomeBalances.stream].
class HomeBalances {
  HomeBalances._();

  static final BehaviorSubject<HomeLedgerState> _subject = BehaviorSubject();

  /// The most recent state Home computed, or null before the first load.
  static HomeLedgerState? get latest => _subject.valueOrNull;

  /// Emits every time Home recomputes balances.
  static Stream<HomeLedgerState> get stream => _subject.stream;

  @visibleForTesting
  static void reset() => _subject.value = HomeLedgerState(
    groups: const [],
    groupInputs: const [],
    recentBills: const [],
    directPayments: const [],
    summary: BalanceSummary(me: '', people: const []),
  );

  static void publish(HomeLedgerState state) => _subject.add(state);
}

/// One group with its bills and payments; null once the group is gone.
Stream<GroupLedgerInput?> watchGroupLedger(
  LedgerRepository repo,
  String groupId, {
  String fallbackCurrency = 'USD',
}) => repo.watchGroup(groupId).switchMap((group) {
  if (group == null) return Stream<GroupLedgerInput?>.value(null);
  return Rx.combineLatest2(
    repo.watchGroupBills(groupId, fallbackCurrency: group.currency ?? fallbackCurrency),
    repo.watchGroupPayments(groupId),
    (List<BillRecord> b, List<PaymentRecord> p) =>
        GroupLedgerInput(group: group, bills: b, payments: p),
  );
});
