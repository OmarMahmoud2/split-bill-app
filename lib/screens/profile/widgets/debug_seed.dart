import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Debug-only: adds 6 varied test bills for the signed-in user.
Future<void> seedTestBills() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Helper to create a participant
  Map<String, dynamic> makeParticipant({
    required String id,
    required String name,
    required double share,
    bool isPaid = false,
    bool isCurrentUser = false,
  }) {
    return {
      'id': id,
      'name': name,
      'photoUrl': isCurrentUser ? user.photoURL : null,
      'share': share,
      'isPaid': isPaid,
      'status': isPaid ? 'PAID' : 'PENDING',
      'phoneNumber': isCurrentUser ? user.phoneNumber : null,
    };
  }

  // 1. RECENT & UNFINISHED (Active, you owe money)
  final bill1 = {
    'storeName': "Dinner @ Cheez",
    'total': 1200.0,
    'status': 'PENDING',
    'date': Timestamp.now(), // Just now
    'items': [
      {
        'name': 'Cheese Platter',
        'price': 800.0,
        'qty': 1,
        'assignedTo': [user.uid, 'p2'],
      },
      {
        'name': 'Drinks',
        'price': 400.0,
        'qty': 4,
        'assignedTo': [user.uid, 'p2', 'p3'],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 533.33,
        isCurrentUser: true,
      ),
      makeParticipant(id: 'p2', name: "Sarah K.", share: 533.33),
      makeParticipant(id: 'p3', name: "Mike R.", share: 133.34),
    ],
    'participants_uids': [user.uid],
  };

  // 2. UNFINISHED (Pending, you haven't paid)
  final bill2 = {
    'storeName': "Uber to Airport",
    'total': 450.0,
    'status': 'PENDING',
    'date': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 5)),
    ),
    'items': [
      {
        'name': 'Ride',
        'price': 450.0,
        'qty': 1,
        'assignedTo': [user.uid, 'p2'],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 225.0,
        isCurrentUser: true,
      ),
      makeParticipant(id: 'p2', name: "John Doe", share: 225.0, isPaid: true),
    ],
    'participants_uids': [user.uid],
  };

  // 3. COMPLETED (Recent)
  final bill3 = {
    'storeName': "Starbucks Morning",
    'total': 185.0,
    'status': 'PAID',
    'date': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 1)),
    ),
    'items': [
      {
        'name': 'Latte',
        'price': 185.0,
        'qty': 1,
        'assignedTo': [user.uid],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 185.0,
        isPaid: true,
        isCurrentUser: true,
      ),
    ],
    'participants_uids': [user.uid],
  };

  // 4. COMPLETED (Older)
  final bill4 = {
    'storeName': "Carrefour Grocery",
    'total': 2500.0,
    'status': 'PAID',
    'date': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 5)),
    ),
    'items': [
      {
        'name': 'Groceries',
        'price': 2500.0,
        'qty': 1,
        'assignedTo': [user.uid, 'p2', 'p3'],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 833.33,
        isPaid: true,
        isCurrentUser: true,
      ),
      makeParticipant(id: 'p2', name: "Mom", share: 833.33, isPaid: true),
      makeParticipant(id: 'p3', name: "Dad", share: 833.34, isPaid: true),
    ],
    'participants_uids': [user.uid],
  };

  // 5. UNFINISHED (Someone owes YOU - You are host)
  final bill5 = {
    'storeName': "Cinema Tickets",
    'total': 600.0,
    'status': 'PENDING',
    'date': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 2)),
    ),
    'items': [
      {
        'name': 'Tickets',
        'price': 600.0,
        'qty': 3,
        'assignedTo': [user.uid, 'p2', 'p3'],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 200.0,
        isPaid: true,
        isCurrentUser: true,
      ),
      makeParticipant(id: 'p2', name: "Ahmed", share: 200.0, isPaid: false),
      makeParticipant(id: 'p3', name: "Layla", share: 200.0, isPaid: false),
    ],
    'participants_uids': [user.uid],
  };

  // 6. COMPLETED (You paid, others paid)
  final bill6 = {
    'storeName': "Pizza Hut",
    'total': 850.0,
    'status': 'PAID',
    'date': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 2)),
    ),
    'items': [
      {
        'name': 'Super Supreme',
        'price': 850.0,
        'qty': 2,
        'assignedTo': [user.uid, 'p2'],
      },
    ],
    'participants': [
      makeParticipant(
        id: user.uid,
        name: "Me",
        share: 425.0,
        isPaid: true,
        isCurrentUser: true,
      ),
      makeParticipant(id: 'p2', name: "Coworker", share: 425.0, isPaid: true),
    ],
    'participants_uids': [user.uid],
  };

  final List<Map<String, dynamic>> dummyBills = [
    bill1,
    bill2,
    bill3,
    bill4,
    bill5,
    bill6,
  ];

  for (var bill in dummyBills) {
    await FirebaseFirestore.instance.collection('bills').add({
      'hostId': user.uid,
      'hostName': user.displayName,
      'storeName': bill['storeName'],
      'date': bill['date'],
      'total': bill['total'],
      'items': bill['items'],
      'charges': {
        'taxAmount': 0.0,
        'serviceCharge': 0.0,
        'tipAmount': 0.0,
        'discountAmount': 0.0,
      },
      'participants': bill['participants'],
      'participants_uids': bill['participants_uids'],
    });
  }
}
