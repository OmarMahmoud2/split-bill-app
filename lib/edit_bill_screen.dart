import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/screens/edit_bill/edit_bill_controller.dart';
import 'package:split_bill_app/screens/edit_bill/edit_split_screen.dart';
import 'package:split_bill_app/screens/edit_bill/history_format.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/edit_bill_header.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/edit_bill_summary_dialog.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/history_card.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_members_sheet.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'package:split_bill_app/services/friend_scanner_service.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/multi_contact_picker.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// Where the edit screen writes. Firestore by default; tests pass a fake.
abstract class EditBillStore {
  Future<void> update(String billId, Map<String, dynamic> fields);
  Future<void> delete(String billId);
}

class FirestoreEditBillStore implements EditBillStore {
  const FirestoreEditBillStore();

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      FirebaseFirestore.instance.collection('bills').doc(id);

  @override
  Future<void> update(String billId, Map<String, dynamic> fields) =>
      _doc(billId).update(fields);

  @override
  Future<void> delete(String billId) => _doc(billId).delete();
}

/// Edit a saved bill (board "Edit bill, changes are tracked").
///
/// Name, date and currency on top; "Items, people and split" and "Tax,
/// service, tip" open their editors; "Paid by" shows the host. Saving
/// recomputes the bill in minor units, refuses with a clear message when
/// something does not add up, writes the 2.0 fields and records what
/// changed in `history`. Pops with `true` after a save.
class EditBillScreen extends StatefulWidget {
  const EditBillScreen({
    super.key,
    required this.billId,
    required this.billData,
    this.store,
    this.currentUid,
    this.currentUserName,
  });

  final String billId;
  final Map<String, dynamic> billData;

  /// Defaults to [FirestoreEditBillStore].
  final EditBillStore? store;

  /// Defaults to the signed-in Firebase user.
  final String? currentUid;
  final String? currentUserName;

  @override
  State<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends State<EditBillScreen> {
  late final String? _uid =
      widget.currentUid ?? FirebaseAuth.instance.currentUser?.uid;
  late final EditBillController _c = EditBillController(
    billData: widget.billData,
    currentUid: _uid,
  );
  late final TextEditingController _name = TextEditingController(text: _c.name);
  late final EditBillStore _store =
      widget.store ?? const FirestoreEditBillStore();
  final ContactService _contactService = ContactService();
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    _c.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_c.takeOverridesResetNotice() && mounted) {
      AppToast.show(
        context,
        message: 'bf_edit_overrides_reset'.tr(),
        type: AppToastType.info,
      );
    }
  }

  String? get _displayName {
    final explicit = widget.currentUserName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    String? fromAuth;
    if (widget.currentUid == null) {
      fromAuth = FirebaseAuth.instance.currentUser?.displayName?.trim();
    }
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    final uid = _uid;
    if (uid == null) return null;
    final name = _c.nameOf(uid);
    return name == uid ? null : name;
  }

  // ------------------------------------------------------------------ actions

  Future<bool> _confirmDiscard() async {
    if (!_c.isDirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('bf_edit_discard_title'.tr()),
        content: Text('bf_edit_discard_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('bf_edit_keep_editing'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('bf_edit_discard'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _cancel() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_c.name.trim().isEmpty) {
      AppToast.show(
        context,
        message: 'bf_edit_name_needed'.tr(),
        type: AppToastType.error,
      );
      return;
    }
    final issues = _c.issueMessages;
    if (issues.isNotEmpty) {
      AppToast.show(
        context,
        message: issues.first.text,
        type: AppToastType.error,
        actionLabel: 'bf_edit_fix'.tr(),
        onAction: _openSplit,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final update = _c.buildUpdate(now: DateTime.now(), byName: _displayName);
      await _store.update(widget.billId, update);
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_edit_saved'.tr(),
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.show(
        context,
        message: 'bf_edit_save_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: _save,
      );
    }
  }

  Future<void> _delete() async {
    final p = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('bf_edit_delete_title'.tr()),
        content: Text('bf_edit_delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: p.error),
            child: Text('bf_edit_delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _store.delete(widget.billId);
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_edit_deleted'.tr(),
        type: AppToastType.success,
      );
      // The bill screen underneath shows a deleted doc; go back home.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppToast.show(
        context,
        message: 'bf_edit_delete_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: _delete,
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _c.date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null) return;
    final d = _c.date;
    AppHaptics.selection();
    _c.setDate(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        d.hour,
        d.minute,
        d.second,
      ),
    );
  }

  void _pickCurrency() {
    CurrencySelectionSheet.show(
      context: context,
      selectedCode: _c.currency,
      onSelected: (code) {
        AppHaptics.selection();
        _c.setCurrency(code);
      },
    );
  }

  void _openCharges() {
    final d = _c.draft;
    EditBillSummaryDialog.show(
      context,
      currency: d.currency,
      subtotalMinor: d.itemsSubtotalMinor,
      taxMinor: d.taxMinor,
      serviceMinor: d.serviceMinor,
      tipMinor: d.tipMinor,
      deliveryMinor: d.deliveryMinor,
      discountMinor: d.discountMinor,
      onConfirm:
          ({
            required taxMinor,
            required serviceMinor,
            required tipMinor,
            required deliveryMinor,
            required discountMinor,
          }) => _c.setCharges(
            taxMinor: taxMinor,
            serviceMinor: serviceMinor,
            tipMinor: tipMinor,
            deliveryMinor: deliveryMinor,
            discountMinor: discountMinor,
          ),
    );
  }

  void _openSplit() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditSplitScreen(controller: _c, onAddPeople: _showAddPeople),
      ),
    );
  }

  // ------------------------------------------------------------- add people

  Future<void> _showAddPeople() async {
    String? choice;
    await PremiumBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => AddMembersSheet(
          onScanQR: () {
            choice = 'qr';
            Navigator.of(sheetContext).pop();
          },
          onPickContacts: () {
            choice = 'contacts';
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'qr') await _scanQr();
    if (choice == 'contacts') await _pickContacts();
  }

  void _reportAdd(int added, int duplicates) {
    if (!mounted) return;
    if (added > 0) {
      AppToast.show(
        context,
        message: 'bf_edit_people_added'.tr(namedArgs: {'count': '$added'}),
        type: AppToastType.success,
      );
    } else if (duplicates > 0) {
      AppToast.show(
        context,
        message: 'bf_edit_person_already'.tr(),
        type: AppToastType.info,
      );
    }
  }

  AddParticipantResult _add(
    Map<String, dynamic> data,
    String type,
  ) => _c.addParticipant(
    id: (data['uid'] ?? data['id'])?.toString(),
    name: (data['displayName'] ?? data['name'] ?? '').toString().trim().isEmpty
        ? 'bf_edit_guest'.tr()
        : (data['displayName'] ?? data['name']).toString().trim(),
    photoUrl: data['photoUrl']?.toString(),
    phoneNumber: data['phoneNumber']?.toString(),
    isGuest: type == 'guest',
  );

  Future<void> _pickContacts() async {
    final contacts = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(builder: (_) => const MultiContactPicker()),
    );
    if (contacts == null || contacts.isEmpty || !mounted) return;
    try {
      final results = await _contactService.identifyUsers(
        contacts.cast<Contact>(),
      );
      var added = 0;
      var duplicates = 0;
      for (final r in results) {
        final data = Map<String, dynamic>.from(r['data'] as Map);
        switch (_add(data, r['type'].toString())) {
          case AddParticipantResult.added:
            added++;
          case AddParticipantResult.duplicate:
            duplicates++;
          case AddParticipantResult.missingId:
            break;
        }
      }
      _reportAdd(added, duplicates);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_edit_add_people_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _scanQr() async {
    try {
      final uid = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ScanFriendScreen()),
      );
      if (uid == null) return;
      final profile = await PublicProfileService.fetch(uid);
      if (!mounted) return;
      if (profile == null) {
        AppToast.show(
          context,
          message: 'bf_edit_qr_not_found'.tr(),
          type: AppToastType.error,
        );
        return;
      }
      final result = _add({
        ...profile,
        'uid': profile['uid'] ?? uid,
      }, 'app_user');
      _reportAdd(
        result == AddParticipantResult.added ? 1 : 0,
        result == AddParticipantResult.duplicate ? 1 : 0,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_edit_qr_failed'.tr(),
        type: AppToastType.error,
      );
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              children: [
                EditBillHeader(
                  title: 'bf_edit_title'.tr(),
                  onLeading: _cancel,
                  actionLabel: 'bf_edit_save'.tr(),
                  onAction: _saving || _deleting ? null : _save,
                  busy: _saving,
                ),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = context.palette;
    final draft = _c.draft;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final issues = _c.issueMessages;
    final hostIsMe = _uid != null && _c.hostUid == _uid;
    final paidBy = hostIsMe
        ? 'bf_edit_history_you'.tr()
        : _c.nameOf(_c.hostUid);
    String pct(int v, {int serviceMinor = 0}) => chargePercentLabel(
      v,
      draft.itemsSubtotalMinor,
      draft.currency,
      locale: locale,
      serviceMinor: serviceMinor,
    );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        18,
        AppSpacing.xl,
        34,
      ),
      children: [
        _FieldLabel('bf_edit_field_name'.tr()),
        TextField(
          controller: _name,
          onChanged: _c.setName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'bf_edit_field_name_hint'.tr(),
            errorText: _c.name.trim().isEmpty
                ? 'bf_edit_name_needed'.tr()
                : null,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('bf_edit_field_date'.tr()),
                  _TapField(
                    text: DateFormat.yMMMd(
                      safeDateLocale(locale),
                    ).format(_c.date),
                    semanticsLabel: 'bf_edit_field_date'.tr(),
                    onTap: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('bf_edit_field_currency'.tr()),
                  _TapField(
                    text: draft.currency,
                    semanticsLabel: 'bf_edit_field_currency'.tr(),
                    onTap: _pickCurrency,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        EditCard(
          children: [
            _SummaryRow(
              label: 'bf_edit_row_items'.tr(),
              value: '${draft.items.length} · ${_c.participants.length}',
              needsAttention: issues.isNotEmpty,
              onTap: _openSplit,
            ),
            _SummaryRow(
              label: 'bf_edit_row_charges'.tr(),
              value:
                  '${pct(draft.taxMinor, serviceMinor: draft.serviceMinor)} · ${pct(draft.serviceMinor)} · '
                  '${pct(draft.tipMinor)}',
              onTap: _openCharges,
            ),
            _SummaryRow(label: 'bf_edit_row_paid_by'.tr(), value: paidBy),
          ],
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          EditIssuesBanner(messages: issues, max: 2),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 18, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              'bf_edit_history_title'.tr().toUpperCase(),
              style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
            ),
          ),
        ),
        BillHistoryCard(
          entries: _c.reader.history,
          currentUid: _uid,
          currency: draft.currency,
        ),
        if (hostIsMe || _uid == null) ...[
          const SizedBox(height: AppSpacing.xxxl),
          OutlinedButton(
            onPressed: _saving || _deleting ? null : _delete,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.error,
              side: BorderSide(color: p.error.withValues(alpha: 0.25)),
            ),
            child: _deleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.error,
                    ),
                  )
                : Text('bf_edit_delete'.tr()),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.titleSmall.copyWith(
        color: context.palette.textPrimary,
      ),
    ),
  );
}

/// Looks like an input, opens a picker.
class _TapField extends StatelessWidget {
  const _TapField({
    required this.text,
    required this.onTap,
    required this.semanticsLabel,
  });

  final String text;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '$semanticsLabel, $text',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: AppRadii.rowShape(p.borderStrong),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.chevronDown,
                  size: 20,
                  color: p.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.onTap,
    this.needsAttention = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: 15,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (needsAttention) ...[
              Icon(AppIcons.error, size: 16, color: p.owe),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: p.textSecondary,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: p.textTertiary,
              ),
            ] else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(
        label: '$label, $value',
        excludeSemantics: true,
        child: row,
      );
    }
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
