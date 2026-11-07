import 'package:split_bill_app/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/split_bill/split_method_screen.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_people_screen.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_people_groups.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/multi_contact_picker.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/voice_command_overlay.dart';

import 'bill_summary_confirm_screen.dart';
import 'services/contact_service.dart';
import 'services/friend_scanner_service.dart';
import 'services/group_service.dart';

/// "Who had what" (People board 3): tap an item, tap the faces of the
/// people who had it. Live per-person totals come from `computeBill`.
class SplitBillScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Contact>? preSelectedContacts;
  final List<Map<String, dynamic>>? initialParticipants;
  final Map<String, List<String>>? initialAssignments;
  final String? resumedBillId;
  final String? cleanupImagePath;

  /// Group the bill is filed into; carried to the summary screen.
  final String? groupId;

  const SplitBillScreen({
    super.key,
    required this.receiptData,
    this.preSelectedContacts,
    this.initialParticipants,
    this.initialAssignments,
    this.resumedBillId,
    this.cleanupImagePath,
    this.groupId,
  });

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  List<Map<String, dynamic>> participants = [];

  final GroupService _groupService = GroupService();
  final ContactService _contactService = ContactService();
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  /// Item index -> people sharing the whole line equally.
  Map<int, List<String>> itemAssignments = {};

  /// Item index -> units per person (quantity > 1).
  Map<int, Map<String, int>> quantityAssignments = {};

  /// The row whose face picker is open.
  int? _activeIndex;
  bool _activeChosen = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialParticipants;
    if (initial != null && initial.isNotEmpty) {
      for (final p in initial) {
        final data = Map<String, dynamic>.from((p['data'] as Map?) ?? const {});
        final type = p['type'];
        final person = participantFromProfile(
          data,
          isGuest: type == 'guest',
          fallbackName: 'guest'.tr(),
        );
        person['isHost'] = type == 'host';
        if (!participants.any((x) => x['id'] == person['id'])) {
          participants.add(person);
        }
      }
    } else if (widget.preSelectedContacts?.isNotEmpty == true) {
      _processPreSelectedContacts();
    }

    widget.initialAssignments?.forEach((itemIdStr, userIds) {
      final index = int.tryParse(itemIdStr);
      if (index != null && userIds.isNotEmpty) {
        itemAssignments[index] = List.of(userIds);
      }
    });

    final needsPeopleStep =
        (initial == null || initial.isEmpty) &&
        (widget.preSelectedContacts?.isEmpty ?? true) &&
        widget.resumedBillId == null &&
        widget.initialAssignments == null;
    _initializeHost().then((_) {
      if (needsPeopleStep && mounted) _openAddPeople();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  List<Map<String, dynamic>> get _rawItems => [
    for (final x in (widget.receiptData['items'] as List?) ?? const [])
      if (x is Map) Map<String, dynamic>.from(x),
  ];

  String _currency(BuildContext context) {
    final fromReceipt =
        widget.receiptData['currency_code'] ??
        widget.receiptData['currencyCode'];
    if (fromReceipt is String && fromReceipt.trim().isNotEmpty) {
      return fromReceipt;
    }
    return context.watch<AppSettingsProvider>().currencyCode;
  }

  BillDraft _draft(String currency) => draftFromReceipt(
    receiptData: widget.receiptData,
    participantIds: [for (final p in participants) p['id'].toString()],
    currency: currency,
    itemAssignments: itemAssignments,
    quantityAssignments: quantityAssignments,
  );

  double _charge(String key) {
    final v = widget.receiptData[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  /// Participants with their palette tint under `color` (read by the
  /// summary screen).
  List<Map<String, dynamic>> _participantsForNext() {
    final p = context.palette;
    return [
      for (final x in participants)
        {...x, 'color': p.avatarTintFor(x['id'].toString())},
    ];
  }

  Future<void> _initializeHost() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return;
    }
    if (user == null) return;
    if (participants.any((p) => p['id'] == user!.uid)) {
      for (final p in participants) {
        if (p['id'] == user.uid) p['isHost'] = true;
      }
      return;
    }

    String? photoUrl;
    var isPro = false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        photoUrl = doc.data()?['photoUrl'];
        isPro = doc.data()?['isPro'] == true;
      }
    } catch (e) {
      debugPrint('Host profile read failed: $e');
    }
    if (!mounted) return;
    setState(() {
      participants.insert(0, {
        'name': user!.displayName ?? 'bf_assign_me'.tr(),
        'id': user.uid,
        'phoneNumber': user.phoneNumber,
        'photoUrl': photoUrl,
        'isGuest': false,
        'isHost': true,
        'isPro': isPro,
      });
    });
  }

  Future<void> _processPreSelectedContacts() async {
    try {
      final results = await _contactService.identifyUsers(
        widget.preSelectedContacts!,
      );
      if (!mounted) return;
      setState(() {
        for (final r in results) {
          final person = participantFromProfile(
            Map<String, dynamic>.from(r['data'] as Map),
            isGuest: r['type'] == 'guest',
            fallbackName: 'guest'.tr(),
          );
          if (!participants.any((x) => x['id'] == person['id'])) {
            participants.add(person);
          }
        }
      });
    } catch (e) {
      debugPrint('Pre-selected contacts failed: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_assign_contacts_error'.tr(),
        type: AppToastType.error,
      );
    }
  }

  // -------------------------------------------------------- add people

  Future<List<Map<String, dynamic>>> _scanSource(BuildContext ctx) async {
    final String? uid = await Navigator.push<String>(
      ctx,
      MaterialPageRoute(builder: (_) => const ScanFriendScreen()),
    );
    if (uid == null) return const [];
    Map<String, dynamic>? profile;
    try {
      profile = await PublicProfileService.fetch(uid);
    } catch (e) {
      debugPrint('Scanned profile read failed: $e');
    }
    if (profile == null) {
      if (ctx.mounted) {
        AppHaptics.error();
        AppToast.show(
          ctx,
          message: 'bf_assign_scan_not_found'.tr(),
          type: AppToastType.error,
        );
      }
      return const [];
    }
    return [participantFromProfile(profile, fallbackName: 'guest'.tr())];
  }

  Future<List<Map<String, dynamic>>> _contactsSource(BuildContext ctx) async {
    final List<dynamic>? contacts = await Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => const MultiContactPicker()),
    );
    if (contacts == null) {
      if (ctx.mounted) {
        AppToast.show(
          ctx,
          message: 'bf_assign_contacts_denied'.tr(),
          type: AppToastType.warning,
        );
      }
      return const [];
    }
    if (contacts.isEmpty) return const [];
    try {
      final results = await _contactService.identifyUsers(
        contacts.cast<Contact>(),
      );
      return [
        for (final r in results)
          participantFromProfile(
            Map<String, dynamic>.from(r['data'] as Map),
            isGuest: r['type'] == 'guest',
            fallbackName: 'guest'.tr(),
          ),
      ];
    } catch (e) {
      debugPrint('Contacts lookup failed: $e');
      if (ctx.mounted) {
        AppHaptics.error();
        AppToast.show(
          ctx,
          message: 'bf_assign_contacts_error'.tr(),
          type: AppToastType.error,
        );
      }
      return const [];
    }
  }

  Future<void> _openAddPeople() async {
    Stream<List<AddPeopleGroup>>? groups;
    try {
      groups = addPeopleGroupsFrom(_groupService);
    } catch (_) {
      groups = null;
    }
    final selected = await AddPeopleScreen.open(
      context,
      participants: participants,
      groups: groups,
      onScanQr: _scanSource,
      onPickContacts: _contactsSource,
    );
    if (selected == null || !mounted) return;
    final next = reconcileParticipants(participants, selected);
    setState(() {
      participants = next.participants;
      for (final id in next.removed) {
        _clearAssignmentsOf(id);
      }
    });
  }

  void _clearAssignmentsOf(String id) {
    final cleared = removeParticipantAssignments(
      itemAssignments,
      quantityAssignments,
      id,
    );
    itemAssignments = cleared.items;
    quantityAssignments = cleared.units;
  }

  void _showRemoveParticipantDialog(Map<String, dynamic> participant) {
    if (participant['isHost'] == true) {
      AppHaptics.warning();
      AppToast.show(
        context,
        message: 'cannot_remove_the_host_of_the_bill'.tr(),
        type: AppToastType.info,
      );
      return;
    }
    final name = (participant['name'] ?? '').toString();
    showAppDialog(
      context,
      icon: AppIcons.personRemove,
      title: 'remove_participant'.tr(),
      message: 'bf_assign_remove_confirm'.tr(namedArgs: {'name': name}),
      confirmLabel: 'common_remove'.tr(),
      destructive: true,
    ).then((ok) {
      if (ok) _removeParticipant(participant['id'].toString(), name);
    });
  }

  void _removeParticipant(String id, String name) {
    setState(() {
      participants.removeWhere((p) => p['id'].toString() == id);
      _clearAssignmentsOf(id);
    });
    AppHaptics.warning();
    AppToast.show(
      context,
      message: 'bf_assign_removed_person'.tr(namedArgs: {'name': name}),
      type: AppToastType.info,
    );
  }

  // -------------------------------------------------------- assigning

  void _activate(int index) {
    setState(() {
      _activeChosen = true;
      _activeIndex = _activeIndex == index ? null : index;
    });
    AppHaptics.selection();
  }

  void _onFaceTap(BillDraft draft, int index, String id) {
    _activeChosen = true;
    _activeIndex = index;
    final quantity = draft.items[index].quantity;
    final shared = itemAssignments[index] ?? const <String>[];
    final units = quantityAssignments[index] ?? const <String, int>{};
    final sharedMode = quantity <= 1 || (shared.isNotEmpty && units.isEmpty);
    if (sharedMode) {
      setState(() {
        final next = toggleShared(shared, id);
        if (next.isEmpty) {
          itemAssignments.remove(index);
        } else {
          itemAssignments[index] = next;
        }
        quantityAssignments.remove(index);
      });
      AppHaptics.selection();
      return;
    }
    final tap = tapUnitFace(units, id, quantity);
    if (tap.result == UnitTapResult.full) {
      AppHaptics.warning();
      AppToast.show(
        context,
        message: 'bf_assign_units_full'.tr(namedArgs: {'qty': '$quantity'}),
        type: AppToastType.info,
      );
      return;
    }
    setState(() {
      if (tap.units.isEmpty) {
        quantityAssignments.remove(index);
      } else {
        quantityAssignments[index] = tap.units;
      }
      itemAssignments.remove(index);
    });
    AppHaptics.selection();
  }

  void _assignEveryone(int index) {
    setState(() {
      itemAssignments[index] = [
        for (final p in participants) p['id'].toString(),
      ];
      quantityAssignments.remove(index);
    });
    AppHaptics.selection();
  }

  void _showSimpleAssignSheet(int index, String itemName) {
    showLedgerSheet<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: SingleChildScrollView(
          child: SimpleAssignmentSheet(
            participants: participants,
            itemName: itemName,
            currentSelection: List.of(itemAssignments[index] ?? const []),
            onConfirm: (ids) {
              setState(() {
                if (ids.isEmpty) {
                  itemAssignments.remove(index);
                } else {
                  itemAssignments[index] = ids;
                }
                quantityAssignments.remove(index);
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _showUnitsSheet(int index, String itemName, int quantity) {
    showLedgerSheet<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: SingleChildScrollView(
          child: ComplexAssignmentSheet(
            participants: participants,
            itemName: itemName,
            initialMap: Map.of(quantityAssignments[index] ?? const {}),
            maxQty: quantity,
            onConfirm: (units) {
              setState(() {
                if (units.isEmpty) {
                  quantityAssignments.remove(index);
                } else {
                  quantityAssignments[index] = units;
                  itemAssignments.remove(index);
                }
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showVoiceOverlay(int itemCount) async {
    if (participants.length < 2) {
      AppToast.show(
        context,
        message: 'add_participants_first'.tr(),
        type: AppToastType.info,
        actionLabel: 'add_people'.tr(),
        onAction: _openAddPeople,
      );
      return;
    }
    RewardedAdHelper.warmUpIfEligible();
    AppHaptics.light();

    final Object? result = await Navigator.push<Object?>(
      context,
      PageRouteBuilder<Object?>(
        opaque: false,
        pageBuilder: (context, _, _) => VoiceCommandOverlay(
          receiptData: widget.receiptData,
          participants: participants,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final voice = parseVoiceResult(
      result,
      knownIds: {for (final p in participants) p['id'].toString()},
      itemCount: itemCount,
    );
    if (voice == null || voice.isEmpty) {
      AnalyticsService.instance.voiceAssign(success: false);
      AppToast.show(
        context,
        message: 'bf_assign_voice_nothing'.tr(),
        type: AppToastType.info,
      );
      return;
    }
    setState(() {
      voice.items.forEach((index, ids) {
        itemAssignments[index] = ids;
        quantityAssignments.remove(index);
      });
      voice.units.forEach((index, units) {
        quantityAssignments[index] = units;
        itemAssignments.remove(index);
      });
    });
    AnalyticsService.instance.voiceAssign(success: true);
    AppHaptics.success();
    AppToast.show(
      context,
      message: 'voice_assignment_applied'.tr(),
      type: AppToastType.success,
    );
  }

  // ----------------------------------------------------------- next steps

  void _pushSummary({BillDraft? methodDraft}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillSummaryConfirmScreen(
          receiptData: widget.receiptData,
          participants: _participantsForNext(),
          itemAssignments: itemAssignments,
          quantityAssignments: quantityAssignments,
          taxAmount: _charge('tax_amount'),
          serviceChargeAmount: _charge('service_charge'),
          tipAmount: _charge('tip_amount'),
          discountAmount: _charge('discount_amount'),
          deliveryFeeAmount: _charge('delivery_fee'),
          oldBillIdToDelete: widget.resumedBillId,
          oldImageToDelete: widget.cleanupImagePath,
          methodDraft: methodDraft,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  void _continue(BillDraft draft) {
    final issue = firstItemIssue(computeBill(draft).issues);
    if (issue == null) {
      AppHaptics.light();
      _pushSummary();
      return;
    }
    final name = draft.items[issue.index].name;
    AppHaptics.error();
    AppToast.show(
      context,
      message: issue.over
          ? 'bf_assign_issue_over'.tr(
              namedArgs: {
                'item': name,
                'assigned': '${issue.assigned}',
                'total': '${issue.quantity}',
              },
            )
          : 'bf_assign_issue_unassigned'.tr(namedArgs: {'item': name}),
      type: AppToastType.error,
    );
    setState(() {
      _activeChosen = true;
      _activeIndex = issue.index;
    });
    _scrollTo(issue.index);
  }

  void _scrollTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index >= _rowKeys.length) return;
      final ctx = _rowKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.2,
        duration: AppMotion.durationFor(context, AppMotion.slow),
        curve: AppMotion.standard,
      );
    });
  }

  Future<void> _splitAnotherWay(BillDraft draft) async {
    AppHaptics.light();
    final result = await SplitMethodScreen.open(
      context,
      draft: draft,
      participants: _participantsForNext(),
    );
    if (!mounted || result == null) return;
    if (result.method != SplitMethod.items) {
      _pushSummary(methodDraft: result);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currency = _currency(context);
    final draft = _draft(currency);
    final computation = computeBill(draft);
    final progress = assignmentProgress(draft);
    final raw = _rawItems;
    while (_rowKeys.length < draft.items.length) {
      _rowKeys.add(GlobalKey());
    }
    if (!_activeChosen) {
      final firstOpen = [
        for (var i = 0; i < draft.items.length; i++)
          if (!draft.assignmentOf(i).isComplete) i,
      ];
      _activeIndex = firstOpen.isEmpty ? null : firstOpen.first;
    }
    final active = _activeIndex;
    final activeIds = active == null || active >= draft.items.length
        ? const <String>{}
        : draft.assignmentOf(active).people.toSet();
    final left = progress.left;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: AppIcons.back,
                    tooltip: 'back'.tr(),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'bf_assign_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'bf_assign_progress'.tr(
                        namedArgs: {
                          'done': '${progress.assigned}',
                          'total': '${progress.total}',
                        },
                      ),
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'bf_assign_split_another_way'.tr(),
                    onPressed: () => _splitAnotherWay(draft),
                    icon: Icon(AppIcons.filter, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
              child: PersonTotalsStrip(
                participants: participants,
                totals: computation.totals,
                currency: currency,
                highlightedIds: activeIds,
                onPersonTap: (person) {
                  if (active == null) {
                    _showRemoveParticipantDialog(person);
                  } else {
                    _onFaceTap(draft, active, person['id'].toString());
                  }
                },
                onPersonLongPress: _showRemoveParticipantDialog,
                onAddPeople: _openAddPeople,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (draft.items.isEmpty)
                      EmptyState(
                        icon: AppIcons.receipt,
                        title: 'bf_assign_no_items'.tr(),
                        compact: true,
                      )
                    else
                      Material(
                        color: p.surface,
                        shape: AppRadii.cardShape(p.border),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < draft.items.length; i++)
                              KeyedSubtree(
                                key: _rowKeys[i],
                                child: StaggeredEntrance(
                                  index: i,
                                  child: AssignItemRow(
                                    item: draft.items[i],
                                    state: draft.assignmentOf(i),
                                    participants: participants,
                                    currency: currency,
                                    active: active == i,
                                    showTopBorder: i > 0,
                                    onTap: () => _activate(i),
                                    onLongPress: () =>
                                        draft.items[i].quantity > 1
                                        ? _showUnitsSheet(
                                            i,
                                            draft.items[i].name,
                                            draft.items[i].quantity,
                                          )
                                        : _showSimpleAssignSheet(
                                            i,
                                            draft.items[i].name,
                                          ),
                                    onFaceTap: (id) => _onFaceTap(draft, i, id),
                                    onEveryone: participants.length > 1
                                        ? () => _assignEveryone(i)
                                        : null,
                                    onAdjustUnits: draft.items[i].quantity > 1
                                        ? () => _showUnitsSheet(
                                            i,
                                            draft.items[i].name,
                                            draft.items[i].quantity,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _splitAnotherWay(draft),
                        icon: const Icon(AppIcons.split, size: 18),
                        label: Text('bf_assign_split_another_way'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: p.primaryStrong,
                          minimumSize: const Size(44, 44),
                          textStyle: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
          child: Row(
            children: [
              _CircleIconButton(
                icon: AppIcons.mic,
                tooltip: 'bf_assign_voice'.tr(),
                size: 52,
                onPressed: () => _showVoiceOverlay(raw.length),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AssignPillButton(
                  key: const ValueKey('bf_assign_continue'),
                  label: left <= 0
                      ? 'common_continue'.tr()
                      : left == 1
                      ? 'bf_assign_items_left_one'.tr()
                      : 'bf_assign_items_left'.tr(
                          namedArgs: {'count': '$left'},
                        ),
                  muted: left > 0,
                  onPressed: () => _continue(draft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: 20, color: p.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
