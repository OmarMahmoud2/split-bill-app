import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'services/group_service.dart';
import 'services/friend_scanner_service.dart';
import 'services/contact_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'bill_summary_confirm_screen.dart';
import 'package:split_bill_app/widgets/multi_contact_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'screens/split_bill/widgets/add_members_sheet.dart';
import 'screens/split_bill/widgets/assignment_sheets.dart';
import 'screens/split_bill/widgets/group_selection_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/voice_command_overlay.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';

class SplitBillScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Contact>? preSelectedContacts;
  final List<Map<String, dynamic>>? initialParticipants; // New parameter
  final Map<String, List<String>>? initialAssignments;
  final String? resumedBillId;
  final String? cleanupImagePath;

  const SplitBillScreen({
    super.key,
    required this.receiptData,
    this.preSelectedContacts,
    this.initialParticipants,
    this.initialAssignments,
    this.resumedBillId,
    this.cleanupImagePath,
  });

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  // Bill Data
  double _taxAmount = 0.0;
  double _serviceChargeAmount = 0.0;
  double _tipAmount = 0.0;
  double _discountAmount = 0.0;
  double _deliveryFeeAmount = 0.0;

  // Participants List
  List<Map<String, dynamic>> participants = [];

  final GroupService _groupService = GroupService();
  final ContactService _contactService = ContactService();

  // Simple Assignments: Map Item Index -> List of User IDs
  Map<int, List<String>> itemAssignments = {};

  // Complex Assignments: Map Item Index -> { User ID : Quantity }
  Map<int, Map<String, int>> quantityAssignments = {};

  @override
  @override
  void initState() {
    super.initState();
    // Initialize participants
    if (widget.initialParticipants != null &&
        widget.initialParticipants!.isNotEmpty) {
      // Map incoming rich participants to local structure
      for (var p in widget.initialParticipants!) {
        final data = p['data'];
        final type = p['type']; // 'host', 'app_user', 'guest'
        participants.add({
          'id': data['uid'] ?? UniqueKey().toString(),
          'name': data['displayName'] ?? 'guest'.tr(),
          'phoneNumber': data['phoneNumber'],
          'photoUrl': data['photoUrl'],
          'isGuest': type == 'guest',
          'isHost': type == 'host',
          'isPro': data['isPro'] == true, // Preserve Pro status
          'color':
              Colors.primaries[participants.length % Colors.primaries.length],
        });
      }
    } else if (widget.preSelectedContacts != null &&
        widget.preSelectedContacts!.isNotEmpty) {
      // Fallback for legacy flows
      _processPreSelectedContacts();
    } else {}

    _initializeHost(); // Always check to ensure host is there

    // Initialize assignments if available (deferred to allow participants to load first)
    if (widget.initialAssignments != null) {
      // We need to wait for participants to be added, so we'll do this slightly later or chained
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyInitialAssignments();
      });
    }
    // Initialize tax and service charge from receipt data
    if (widget.receiptData.isNotEmpty) {
      _taxAmount = (widget.receiptData['tax_amount'] is num)
          ? (widget.receiptData['tax_amount'] as num).toDouble()
          : 0.0;
      _serviceChargeAmount = (widget.receiptData['service_charge'] is num)
          ? (widget.receiptData['service_charge'] as num).toDouble()
          : 0.0;
      _tipAmount = (widget.receiptData['tip_amount'] is num)
          ? (widget.receiptData['tip_amount'] as num).toDouble()
          : 0.0;
      _discountAmount = (widget.receiptData['discount_amount'] is num)
          ? (widget.receiptData['discount_amount'] as num).toDouble()
          : 0.0;
      _deliveryFeeAmount = (widget.receiptData['delivery_fee'] is num)
          ? (widget.receiptData['delivery_fee'] as num).toDouble()
          : 0.0;
    }
  }

  ImageProvider? _getAvatarImage(String? url) {
    return ImageUtils.getAvatarImage(url);
  }

  void _initializeHost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if host is already in the list (by ID)
      if (participants.any((p) => p['id'] == user.uid)) return;

      String? photoUrl;
      bool isProHost = false;
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          photoUrl = doc.data()?['photoUrl'];
          isProHost = doc.data()?['isPro'] == true;
        }
      } catch (e) {
        debugPrint("Error fetching host image: $e");
      }

      if (mounted) {
        setState(() {
          participants.add({
            'name': user.displayName ?? 'Me',
            'id': user.uid,
            'color': Theme.of(context).colorScheme.primary,
            'phoneNumber': user.phoneNumber,
            'photoUrl': photoUrl,
            'isGuest': false,
            'isHost': true,
            'isPro': isProHost,
          });
        });
      }
    }
  }

  Future<void> _processPreSelectedContacts() async {
    try {
      final results = await _contactService.identifyUsers(
        widget.preSelectedContacts!,
      );
      if (mounted) {
        setState(() {
          for (var result in results) {
            _addParticipant(result['data'], result['type']);
          }
        });
      }
    } catch (e) {
      debugPrint("Error processing pre-selected contacts: $e");
    }
  }

  void _applyInitialAssignments() {
    if (widget.initialAssignments == null) return;

    setState(() {
      widget.initialAssignments!.forEach((itemIdStr, userIds) {
        int? index = int.tryParse(itemIdStr);
        if (index != null) {
          itemAssignments[index] = List.from(userIds);
        }
      });
    });
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
        final results = await _contactService.identifyUsers(contacts.cast());

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        int addedCount = 0;
        for (var result in results) {
          _addParticipant(result['data'], result['type']);
          addedCount++;
        }

        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'error_adding_contacts'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanAndAddFriend() async {
    final String? scannedUid = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanFriendScreen()),
    );

    if (scannedUid != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(scannedUid)
            .get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          userData['uid'] = userDoc.id; // Inject ID explicitly
          _addParticipant(userData, 'app_user');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'error_with_details'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  void _addParticipant(Map<String, dynamic> data, String type) {
    final String? candidateId = data['uid'] ?? data['id'];

    if (candidateId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_missing_user_id').tr()));
      return;
    }

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
        'isHost': false,
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
      quantityAssignments.forEach((key, value) => value.remove(id));
    });
  }

  void _showRemoveParticipantDialog(Map<String, dynamic> participant) {
    if (participant['isHost'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('cannot_remove_the_host_of_the_bill').tr()),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'remove_participant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        content: Text(
          "Are you sure you want to remove \"${participant['name']}\" from this bill?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common_cancel',
              style: TextStyle(color: Colors.grey),
            ).tr(),
          ),
          ElevatedButton(
            onPressed: () {
              _removeParticipant(participant['id']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('common_remove').tr(),
          ),
        ],
      ),
    );
  }

  void _splitEqually() {
    if (participants.isEmpty) return;

    setState(() {
      itemAssignments.clear();
      quantityAssignments.clear();

      final items = widget.receiptData['items'] as List;
      final participantIds = participants
          .map((p) => p['id'] as String)
          .toList();

      for (int i = 0; i < items.length; i++) {
        itemAssignments[i] = List.from(participantIds);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('bill_split_equally_among_all_members').tr()),
    );
  }

  void _confirmSplitEqually() {
    if (participants.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('add_participants_first').tr()));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('split_bill_equally').tr(),
        content: Text(
          'this_will_assign_all_current_members_to_every_item_on_the_receipt_existing_assignments_will_be_cleared',
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel').tr(),
          ),
          ElevatedButton(
            onPressed: () {
              _splitEqually();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('split_equally').tr(),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsSheet() {
    PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'how_to_assign_items',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ).tr(),
          const SizedBox(height: 24),
          // Split Equally option
          _buildQuickActionTile(
            icon: Icons.groups_rounded,
            title: 'split_equally'.tr(),
            subtitle: 'split_equally_subtitle'.tr(),
            gradientColors: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
            onTap: () {
              Navigator.pop(context);
              _confirmSplitEqually();
            },
          ),
          const SizedBox(height: 12),
          // Voice Command option
          _buildQuickActionTile(
            icon: Icons.mic_rounded,
            title: 'voice_command'.tr(),
            subtitle: 'voice_command_subtitle'.tr(),
            gradientColors: [const Color(0xFF7209B7), const Color(0xFF560BAD)],
            badge: 'voice_command_cost'.tr(),
            onTap: () {
              Navigator.pop(context);
              _showVoiceOverlay();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors
                      .map((c) => c.withValues(alpha: 0.15))
                      .toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: gradientColors[0], size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  void _showVoiceOverlay() async {
    if (participants.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('add_participants_first').tr()));
      return;
    }

    // Warm up ad in case it's needed
    RewardedAdHelper.warmUpIfEligible();

    final result = await Navigator.push<Map<String, List<String>>>(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => VoiceCommandOverlay(
          receiptData: widget.receiptData,
          participants: participants,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        itemAssignments.clear();
        quantityAssignments.clear();
        result.forEach((itemIdStr, userIds) {
          int? index = int.tryParse(itemIdStr);
          if (index != null) {
            itemAssignments[index] = List.from(userIds);
          }
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('voice_assignment_applied').tr(),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _pickGroup() {
    PremiumBottomSheet.show(
      context: context,
      child: GroupSelectionSheet(
        groupService: _groupService,
        onGroupSelected: (members) {
          _showSelectGroupMembersDialog(members);
        },
      ),
    );
  }

  void _showSelectGroupMembersDialog(List<dynamic> groupMembers) {
    showDialog(
      context: context,
      builder: (context) {
        return GroupMemberSelectionDialog(
          groupMembers: groupMembers,
          onMembersConfirmed: (finalSelection) {
            _importMembers(finalSelection);
          },
        );
      },
    );
  }

  void _importMembers(List<dynamic> groupMembers) {
    int addedCount = 0;
    for (var m in groupMembers) {
      if (!participants.any((p) => p['id'] == m['id'])) {
        setState(() {
          participants.add({
            'name': m['name'],
            'id': m['id'],
            'color':
                Colors.primaries[participants.length % Colors.primaries.length],
            'phoneNumber': m['phoneNumber'],
            'photoUrl': m['photoUrl'],
            'isGuest': m['isGuest'] ?? true,
            'isHost': false,
          });
        });
        addedCount++;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'added_members_count'.tr(namedArgs: {'count': addedCount.toString()}),
        ),
      ),
    );
  }

  // --- ADD MEMBERS MODAL ---
  void _showAddMembersModal() {
    PremiumBottomSheet.show(
      context: context,
      child: AddMembersSheet(
        onScanQR: () {
          Navigator.pop(context);
          _scanAndAddFriend();
        },
        onPickContacts: () {
          Navigator.pop(context);
          _pickContact();
        },
        onPickGroups: () {
          Navigator.pop(context);
          _pickGroup();
        },
      ),
    );
  }

  // --- ITEM ASSIGNMENT DIALOG ---
  void _showAssignDialog(int itemIndex) {
    final item = widget.receiptData['items'][itemIndex];
    int maxQty = (item['qty'] as num?)?.toInt() ?? 1;

    if (maxQty > 1) {
      _showComplexAssignDialog(itemIndex, maxQty);
    } else {
      _showSimpleAssignDialog(itemIndex);
    }
  }

  void _showSimpleAssignDialog(int itemIndex) {
    List<String> currentSelection = List.from(itemAssignments[itemIndex] ?? []);
    PremiumBottomSheet.show(
      context: context,
      child: SimpleAssignmentSheet(
        participants: participants,
        currentSelection: currentSelection,
        onConfirm: (selectedIds) {
          setState(() {
            itemAssignments[itemIndex] = selectedIds;
            quantityAssignments.remove(itemIndex);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showComplexAssignDialog(int itemIndex, int maxQty) {
    Map<String, int> currentMap = Map.from(
      quantityAssignments[itemIndex] ?? {},
    );

    PremiumBottomSheet.show(
      context: context,
      child: ComplexAssignmentSheet(
        participants: participants,
        initialMap: currentMap,
        maxQty: maxQty,
        onConfirm: (confirmedMap) {
          setState(() {
            quantityAssignments[itemIndex] = confirmedMap;
            itemAssignments.remove(itemIndex);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- FINALIZATION ---
  Future<void> _finalizeBill() async {
    // 1. VALIDATION: Check if all items are fully assigned
    List items = widget.receiptData['items'];
    for (int i = 0; i < items.length; i++) {
      int totalQty = (items[i]['qty'] as num?)?.toInt() ?? 1;
      int assignedQty = 0;

      if (quantityAssignments.containsKey(i)) {
        assignedQty = quantityAssignments[i]!.values.fold(
          0,
          (assignedTotal, v) => assignedTotal + v,
        );
      } else if (itemAssignments.containsKey(i)) {
        // In simple mode, we assume the whole item is assigned if the list is not empty
        if (itemAssignments[i]!.isNotEmpty) {
          assignedQty = totalQty;
        }
      }

      if (assignedQty < totalQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'item_not_fully_assigned'.tr(
                namedArgs: {
                  'item': (items[i]['name'] ?? '').toString(),
                  'assigned': assignedQty.toString(),
                  'total': totalQty.toString(),
                },
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // 2. SHOW TAX DIALOG
    await showDialog(
      context: context,
      builder: (context) {
        double tempTax = _taxAmount;
        double tempService = _serviceChargeAmount;
        double tempTip = _tipAmount;
        double tempDiscount = _discountAmount;
        double tempDelivery = _deliveryFeeAmount;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('final_steps').tr(),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMoneyInput(
                  context,
                  'tax_vat'.tr(),
                  tempTax,
                  (v) => tempTax = v,
                ),
                const SizedBox(height: 12),
                _buildMoneyInput(
                  context,
                  'service_charge'.tr(),
                  tempService,
                  (v) => tempService = v,
                ),
                const SizedBox(height: 12),
                _buildMoneyInput(
                  context,
                  'tip'.tr(),
                  tempTip,
                  (v) => tempTip = v,
                ),
                const SizedBox(height: 12),
                _buildMoneyInput(
                  context,
                  'delivery_fee'.tr(),
                  tempDelivery,
                  (v) => tempDelivery = v,
                ),
                const SizedBox(height: 12),
                _buildMoneyInput(
                  context,
                  'discount'.tr(),
                  tempDiscount,
                  (v) => tempDiscount = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common_cancel',
                style: TextStyle(color: Colors.grey),
              ).tr(),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _taxAmount = tempTax;
                  _serviceChargeAmount = tempService;
                  _tipAmount = tempTip;
                  _discountAmount = tempDiscount;
                  _deliveryFeeAmount = tempDelivery;
                });
                Navigator.pop(context);

                // 3. NAVIGATE TO SUMMARY
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BillSummaryConfirmScreen(
                      receiptData: widget.receiptData,
                      participants: participants,
                      itemAssignments: itemAssignments,
                      quantityAssignments: quantityAssignments,
                      taxAmount: _taxAmount,
                      serviceChargeAmount: _serviceChargeAmount,
                      tipAmount: _tipAmount,
                      discountAmount: _discountAmount,
                      deliveryFeeAmount: _deliveryFeeAmount,
                      oldBillIdToDelete: widget.resumedBillId,
                      oldImageToDelete: widget.cleanupImagePath,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('common_continue').tr(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoneyInput(
    BuildContext context,
    String label,
    double initial,
    Function(double) onChanged,
  ) {
    final currencyCode = context.read<AppSettingsProvider>().currencyCode;
    return TextFormField(
      initialValue: initial == 0 ? "" : initial.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'add_label'.tr(namedArgs: {'label': label}),
        prefixIcon: Container(
          width: 50,
          alignment: Alignment.center,
          child: Text(
            currencyCode,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
            ),
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = context.watch<AppSettingsProvider>().currencyCode;
    List items = widget.receiptData['items'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM HEADER
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.receiptData['storeName'] ?? 'split_bill'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'assign_items',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ).tr(),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: _showAddMembersModal,
                  ),
                ],
              ),
            ),

            // 2. MEMBER LIST
            Container(
              height: 140,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: participants.length,
                separatorBuilder: (c, i) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final p = participants[index];
                  final isHost = p['isHost'] == true;
                  return GestureDetector(
                    onTap: () => _showRemoveParticipantDialog(p),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p['color'], width: 2),
                                boxShadow: isHost
                                    ? [
                                        BoxShadow(
                                          color: p['color'].withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: p['color'].withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white,
                                backgroundImage: _getAvatarImage(p['photoUrl']),
                                child: _getAvatarImage(p['photoUrl']) == null
                                    ? Text(
                                        p['name'][0].toUpperCase(),
                                        style: TextStyle(
                                          color: p['color'],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            p['name'].split(" ")[0],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 3. ITEMS LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  int qty = (item['qty'] as num?)?.toInt() ?? 1;
                  double price = (item['price'] as num).toDouble();
                  double total = price * qty;

                  final simpleAssigned = itemAssignments[index] ?? [];
                  final complexAssigned = quantityAssignments[index] ?? {};
                  final isAssigned =
                      simpleAssigned.isNotEmpty || complexAssigned.isNotEmpty;

                  return GestureDetector(
                    onTap: () => _showAssignDialog(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: isAssigned
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Lottie.asset(
                              'assets/animations/food.json',
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) =>
                                  Icon(Icons.fastfood, color: Colors.orange),
                            ),
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "x$qty",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyUtils.format(
                                        price,
                                        currencyCode: currencyCode,
                                        decimalDigits: 1,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'equals_sign',
                                      style: TextStyle(color: Colors.grey),
                                    ).tr(),
                                    Text(
                                      CurrencyUtils.format(
                                        total,
                                        currencyCode: currencyCode,
                                        decimalDigits: 1,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (!isAssigned)
                            Icon(
                              Icons.add_circle_outline_rounded,
                              color: Colors.grey[300],
                              size: 28,
                            ),

                          if (isAssigned)
                            _buildAssignmentIndicator(
                              simpleAssigned,
                              complexAssigned,
                              qty > 1,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: "quick_actions_fab",
              onPressed: _showQuickActionsSheet,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            FloatingActionButton(
              heroTag: "finalize_fab",
              onPressed: _finalizeBill,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentIndicator(
    List<String> simple,
    Map<String, int> complex,
    bool isComplex,
  ) {
    // If complex (qty > 1) but complex assignments are empty, fallback to simple
    List<String> userIds = (isComplex && complex.isNotEmpty)
        ? complex.keys.toList()
        : simple;
    return SizedBox(
      height: 36,
      width: 80,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (int i = 0; i < (userIds.length > 3 ? 3 : userIds.length); i++)
            Positioned(
              right: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2),
                  ],
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      participants.firstWhere(
                        (e) => e['id'].toString() == userIds[i].toString(),
                        orElse: () => {'color': Colors.grey},
                      )['color'] ??
                      Colors.grey,
                  backgroundImage: _getAvatarImage(
                    participants.firstWhere(
                      (e) => e['id'].toString() == userIds[i].toString(),
                      orElse: () => {},
                    )['photoUrl'],
                  ),
                  child:
                      _getAvatarImage(
                            participants.firstWhere(
                              (e) =>
                                  e['id'].toString() == userIds[i].toString(),
                              orElse: () => {},
                            )['photoUrl'],
                          ) ==
                          null
                      ? Text(
                          participants.firstWhere(
                            (e) => e['id'].toString() == userIds[i].toString(),
                            orElse: () => {'name': '?'},
                          )['name'][0],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BillSummaryScreen extends StatelessWidget {
  final String billId;
  final Map<String, double> shares;
  final List<Map<String, dynamic>> participants;

  const BillSummaryScreen({
    super.key,
    required this.billId,
    required this.shares,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'bill_sent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ).tr(),
            const SizedBox(height: 10),
            Text(
              'your_friends_have_been_notified',
              style: TextStyle(color: Colors.white70),
            ).tr(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (c) => const HomeScreen()),
                (r) => false,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
              ),
              child: Text('back_to_home').tr(),
            ),
          ],
        ),
      ),
    );
  }
}
