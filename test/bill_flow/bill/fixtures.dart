/// Bill documents shared by the bill-view tests.
library;

import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';

/// 2.0 bill, by item: Omar (host) paid; Sara took 1 of 3 lemonades and
/// shares the fries with Ali; Mona has the burger. EGP, 14% tax.
Map<String, dynamic> itemizedBill() {
  final bill = _itemizedRaw();
  // Store exact shares the way 2.0 writers do.
  final computed = computeBill(BillReader(bill).toDraft());
  var total = 0;
  for (final p in bill['participants'] as List) {
    final share = computed.shareOf(p['id'] as String);
    p['shareMinor'] = share;
    p['share'] = share / 100;
    total += share;
  }
  bill['totalMinor'] = total;
  bill['total'] = total / 100;
  return bill;
}

Map<String, dynamic> _itemizedRaw() => {
  'hostId': 'omar',
  'hostName': 'Omar',
  'storeName': 'Sea Breeze Grill',
  'currency': 'EGP',
  'currencyCode': 'EGP',
  'splitMethod': 'items',
  'items': [
    {
      'name': 'Lemon mint',
      'price': 3.0,
      'priceMinor': 300,
      'qty': 3,
      'assignedTo': ['omar', 'sara', 'ali'],
      'unitAssignments': {'omar': 1, 'sara': 1, 'ali': 1},
    },
    {
      'name': 'Fries',
      'price': 6.0,
      'priceMinor': 600,
      'qty': 1,
      'assignedTo': ['sara', 'ali'],
    },
    {
      'name': 'Beef burger',
      'price': 14.0,
      'priceMinor': 1400,
      'qty': 1,
      'assignedTo': ['mona'],
    },
    {
      'name': 'Kunafa',
      'price': 7.0,
      'priceMinor': 700,
      'qty': 1,
      'assignedTo': ['omar'],
    },
  ],
  'charges': {
    'taxAmount': 4.2,
    'serviceCharge': 0.0,
    'tipAmount': 0.0,
    'discountAmount': 0.0,
    'deliveryFeeAmount': 0.0,
    'otherCharges': <Map<String, dynamic>>[],
    'minor': {'tax': 420, 'service': 0, 'tip': 0, 'delivery': 0, 'discount': 0},
  },
  'participants': [
    {'id': 'omar', 'name': 'Omar', 'status': 'PAID', 'isPaid': true},
    {'id': 'sara', 'name': 'Sara', 'status': 'PAID', 'isPaid': true},
    {'id': 'ali', 'name': 'Ali', 'status': 'REVIEW', 'isPaid': false},
    {'id': 'mona', 'name': 'Mona', 'status': 'PENDING', 'isPaid': false},
  ],
  'paymentMethods': {
    'InstaPay': 'omar@instapay',
    'PayPal': 'paypal.me/omarm',
    'Apple Cash': '+15551234567',
  },
};

/// 1.x bill: doubles only, no minor fields, equal split.
Map<String, dynamic> legacyBill() => {
  'hostId': 'omar',
  'hostName': 'Omar',
  'storeName': 'Taxi',
  'currencyCode': 'USD',
  'total': 30.0,
  'items': [
    {
      'name': 'Ride',
      'price': 30.0,
      'qty': 1,
      'assignedTo': ['omar', 'sara', 'ali'],
    },
  ],
  'charges': {
    'taxAmount': 0,
    'serviceCharge': 0,
    'tipAmount': 0,
    'discountAmount': 0,
    'deliveryFeeAmount': 0,
  },
  'participants': [
    {'id': 'omar', 'name': 'Omar', 'share': 10.0, 'status': 'PAID'},
    {'id': 'sara', 'name': 'Sara', 'share': 10.0, 'status': 'PAID'},
    {'id': 'ali', 'name': 'Ali', 'share': 10.0, 'status': 'PENDING'},
  ],
};
