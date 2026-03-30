import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/contact_service.dart';
import 'services/friend_scanner_service.dart';
import 'home_screen.dart';
import 'package:split_bill_app/widgets/multi_contact_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'screens/edit_bill/widgets/edit_bill_header.dart';
import 'screens/edit_bill/widgets/participant_list.dart';
import 'screens/edit_bill/widgets/bill_items_list.dart';
import 'screens/edit_bill/widgets/edit_assignment_sheet.dart';
import 'screens/edit_bill/widgets/participant_options_sheet.dart';
import 'screens/edit_bill/widgets/edit_bill_summary_dialog.dart';
import 'screens/split_bill/widgets/add_members_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class EditBillScreen extends StatefulWidget {
  final String billId;
  final Map<String, dynamic> billData;

  const EditBillScreen({
    super.key,
    required this.billId,
    required this.billData,
  });

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  // Bill Data
  double _taxAmount = 0.0;
  double _serviceChargeAmount = 0.0;
  double _tipAmount = 0.0;
  double _deliveryFeeAmount = 0.0;
  double _discountAmount = 0.0;

  List<Map<String, dynamic>> participants = [];
  Map<int, List<String>> itemAssignments = {};
  List<dynamic> items = [];

  final ContactService _contactService = ContactService();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // --- RESTORE DATA ---
  void _loadExistingData() {
    final data = widget.billData;

    // 1. Restore Charges
    if (data['charges'] != null) {
      _taxAmount = (data['charges']['taxAmount'] as num).toDouble();
      _tipAmount = (data['charges']['tipAmount'] as num).toDouble();
      _serviceChargeAmount = (data['charges']['serviceCharge'] as num)
          .toDouble();
      _tipAmount = (data['charges']['tipAmount'] as num? ?? 0.0).toDouble();
      _deliveryFeeAmount = (data['charges']['deliveryFeeAmount'] as num? ?? 0.0)
          .toDouble();
      _discountAmount = (data['charges']['discountAmount'] as num? ?? 0.0)
          .toDouble();
    }

    // 2. Restore Items & Assignments
    items = List.from(data['items']);
    for (int i = 0; i < items.length; i++) {
      List<dynamic> assigned = items[i]['assignedTo'] ?? [];
      itemAssignments[i] = assigned.map((e) => e.toString()).toList();
    }

    // 3. Restore Participants
    participants = List<Map<String, dynamic>>.from(data['participants']);
    _refreshHostPhoto();
  }

  void _refreshHostPhoto() async {
    if (user == null) return;
    int hostIndex = participants.indexWhere((p) => p['id'] == user!.uid);
    if (hostIndex != -1) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('photoUrl')) {
        setState(() {
          participants[hostIndex]['photoUrl'] = doc.data()!['photoUrl'];
        });
      }
    }
  }

  // --- LOGIC: Calculate Shares ---
  Map<String, double> _calculateShares() {
    Map<String, double> shares = {};
    for (var p in participants) {
      shares[p['id']] = 0.0;
    }

    for (int i = 0; i < items.length; i++) {
      List<String>? assignedIds = itemAssignments[i];
      double price = (items[i]['price'] as num).toDouble();
      int qty = (items[i]['qty'] as num? ?? 1).toInt();
      double totalItemPrice = price * qty;

      if (assignedIds != null && assignedIds.isNotEmpty) {
        double splitPrice = totalItemPrice / assignedIds.length;
        for (String uid in assignedIds) {
          if (shares.containsKey(uid)) {
            shares[uid] = (shares[uid]!) + splitPrice;
          }
        }
      }
    }
    return shares;
  }

  // --- ACTIONS ---
  Future<void> _pickContact() async {
    final List<dynamic>? contacts = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MultiContactPicker()),
    );

    if (contacts != null && contacts.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            LoadingStateWidget(message: 'checking_app_status'.tr()),
      );

      try {
        final results = await _contactService.identifyUsers(
          contacts.cast<Contact>(),
        );
        if (!mounted) return;
        Navigator.pop(context); // Close loading

        int addedCount = 0;
        for (var result in results) {
          _addParticipant(result['data'], result['type']);
          addedCount++;
        }

        if (addedCount > 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(
                'added_people_count'.tr(
                  namedArgs: {'count': addedCount.toString()},
                ),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'error_adding_contacts'.tr(
                namedArgs: {'error': e.toString()},
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanQr() async {
    try {
      final String? scannedUid = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScanFriendScreen()),
      );
      if (scannedUid != null) {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(scannedUid)
            .get();
        if (doc.exists) {
          _addParticipant(doc.data() as Map<String, dynamic>, 'app_user');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'error_scanning_qr'.tr(namedArgs: {'error': e.toString()}),
          ),
        ),
      );
    }
  }

  void _addParticipant(Map<String, dynamic> data, String type) {
    // The scanned or selected user's ID might be in 'uid' or 'id'
    final String? candidateId = data['uid'] ?? data['id'];

    if (candidateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_user_id_missing_from_data').tr()),
      );
      return;
    }

    // Check for duplicates
    if (participants.any((p) => p['id'] == candidateId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('user_already_in_bill').tr()));
      return;
    }

    setState(() {
      participants.add({
        'name': data['displayName'] ?? data['name'] ?? "Unknown",
        'id': candidateId,
        'color':
            Colors.primaries[participants.length % Colors.primaries.length],
        'phoneNumber': data['phoneNumber'] ?? '',
        'photoUrl': data['photoUrl'] ?? '',
        'isGuest': type == 'guest',
        'status': 'PENDING',
        'isHost': candidateId == user?.uid,
      });
    });
  }

  void _removeParticipant(String id) {
    if (participants.any((p) => p['id'] == id && p['isHost'] == true)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('cannot_remove_yourself').tr()));
      return;
    }

    setState(() {
      participants.removeWhere((p) => p['id'] == id);
      // Also clear assignments for this user
      itemAssignments.forEach((key, value) => value.remove(id));
      // In EditBillScreen we don't have quantityAssignments implemented like SplitBillScreen yet,
      // but if we were to add it, we should clear it here too.
    });
  }

  void _togglePaidStatus(String id) {
    int index = participants.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      setState(() {
        String current = participants[index]['status'] ?? 'PENDING';
        participants[index]['status'] = (current == 'PAID')
            ? 'PENDING'
            : 'PAID';
        participants[index]['isPaid'] = participants[index]['status'] == 'PAID';
      });
    }
  }

  void _showParticipantOptions(Map<String, dynamic> p) {
    ParticipantOptionsSheet.show(
      context,
      participant: p,
      onTogglePaid: () => _togglePaidStatus(p['id']),
      onRemove: () => _removeParticipant(p['id']),
    );
  }

  // --- DIALOGS: Assign Items ---
  void _showAssignDialog(int itemIndex) {
    EditAssignmentSheet.show(
      context,
      participants: participants,
      currentSelection: itemAssignments[itemIndex] ?? [],
      onConfirm: (newSelection) {
        setState(() {
          itemAssignments[itemIndex] = newSelection;
        });
      },
    );
  }

  // --- FINALIZATION ---
  Future<void> _finalizeChanges() async {
    // 1. Validation: Ensure all items have at least one person assigned
    for (int i = 0; i < items.length; i++) {
      if ((itemAssignments[i] ?? []).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Item '${items[i]['name']}' needs at least one person!",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // 2. Show Tax/Charges Dialog
    await EditBillSummaryDialog.show(
      context,
      initialTax: _taxAmount,
      initialService: _serviceChargeAmount,
      initialTip: _tipAmount,
      initialDiscount: _discountAmount,
      initialDelivery: _deliveryFeeAmount,
      onConfirm: (newTax, newService, newTip, newDiscount, newDelivery) {
        setState(() {
          _taxAmount = newTax;
          _serviceChargeAmount = newService;
          _tipAmount = newTip;
          _discountAmount = newDiscount;
          _deliveryFeeAmount = newDelivery;
        });
        _saveUpdatesToFirebase();
      },
    );
  }

  Future<void> _saveUpdatesToFirebase() async {
    if (user == null) return;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, double> rawShares = _calculateShares();
    Map<String, double> finalShares = {};

    double totalItemsCost = 0.0;
    for (var item in items) {
      totalItemsCost += ((item['price'] as num) * (item['qty'] as num? ?? 1))
          .toDouble();
    }

    if (totalItemsCost <= 0) totalItemsCost = 1.0;

    double additionalCharges =
        _taxAmount +
        _serviceChargeAmount +
        _tipAmount +
        _deliveryFeeAmount -
        _discountAmount;

    rawShares.forEach((uid, amount) {
      double ratio = amount / totalItemsCost;
      finalShares[uid] = amount + (additionalCharges * ratio);
    });

    final updatedData = {
      'charges': {
        'taxAmount': _taxAmount,
        'serviceCharge': _serviceChargeAmount,
        'tipAmount': _tipAmount,
        'deliveryFeeAmount': _deliveryFeeAmount,
        'discountAmount': _discountAmount,
      },
      'items': items.asMap().entries.map((entry) {
        int idx = entry.key;
        var item = entry.value;
        return {
          'name': item['name'],
          'price': item['price'],
          'qty': item['qty'] ?? 1,
          'assignedTo': itemAssignments[idx] ?? [],
        };
      }).toList(),
      'participants': participants.map((p) {
        String status = p['status'] ?? 'PENDING';
        if (p['id'] == user!.uid) status = 'PAID';
        return {
          'id': p['id'],
          'name': p['name'],
          'photoUrl': p['photoUrl'],
          'share': finalShares[p['id']] ?? 0.0,
          'isPaid': status == 'PAID',
          'phoneNumber': p['phoneNumber'],
          'status': status,
        };
      }).toList(),
      'participants_uids': participants.map((p) => p['id']).toList(),
      'total': totalItemsCost + additionalCharges,
    };

    try {
      await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billId)
          .update(updatedData);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('bill_updated').tr(),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'error_with_details'.tr(namedArgs: {'error': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddMembersModal() {
    PremiumBottomSheet.show(
      context: context,
      child: AddMembersSheet(
        onScanQR: _scanQr,
        onPickContacts: _pickContact,
        onPickGroups: null, // EditBillScreen doesn't support groups yet
      ),
    );
  }

  void _splitEqually() {
    if (participants.isEmpty) return;
    setState(() {
      final participantIds = participants
          .map((p) => p['id'] as String)
          .toList();
      for (int i = 0; i < items.length; i++) {
        itemAssignments[i] = List.from(participantIds);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('split_equally_among_all').tr(),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmSplitEqually() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('split_bill_equally',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        content: Text('this_will_assign_all_items_to_all_participants_this_action_will_overwrite_your_current_assignments',
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel', style: TextStyle(color: Colors.grey)).tr(),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _splitEqually();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('confirm_split').tr(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> currentShares = _calculateShares();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM HEADER
            EditBillHeader(
              storeName: widget.billData['storeName'] ?? "Bill",
              onAddMembers: _showAddMembersModal,
            ),

            // 2. MEMBER LIST
            ParticipantList(
              participants: participants,
              currentShares: currentShares,
              onParticipantTap: _showParticipantOptions,
              currencyCode:
                  (widget.billData['currencyCode'] ??
                          widget.billData['currency_code'] ??
                          'USD')
                      .toString(),
            ),

            const SizedBox(height: 16),

            // 3. ITEMS LIST
            Expanded(
              child: BillItemsList(
                items: items,
                itemAssignments: itemAssignments,
                participants: participants,
                onItemTap: _showAssignDialog,
                currencyCode:
                    (widget.billData['currencyCode'] ??
                            widget.billData['currency_code'] ??
                            'USD')
                        .toString(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: "edit_split_equally",
              onPressed: _confirmSplitEqually,
              backgroundColor: Colors.white,
              child: Icon(
                CupertinoIcons.divide,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            FloatingActionButton(
              heroTag: "edit_finalize",
              onPressed: _finalizeChanges,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                CupertinoIcons.check_mark,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
