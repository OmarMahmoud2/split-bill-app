/// Adding people to a group: from contacts (matched to accounts through
/// `phoneClaims`, else added as a guest) or by scanning their QR code.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// E.164 guesses for a phone number typed into contacts (same rules as the
/// 1.x contact matcher).
List<String> phoneVariations(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
  final out = <String>{cleaned};
  if (cleaned.startsWith('01')) out.add('+20${cleaned.substring(1)}');
  if (!cleaned.startsWith('+') && !cleaned.startsWith('0')) out.add('+20$cleaned');
  if (cleaned.startsWith('201')) out.add('+$cleaned');
  if (cleaned.startsWith('00')) out.add('+${cleaned.substring(2)}');
  return out.where((v) => v.startsWith('+')).toList();
}

Future<GroupMember?> pickMemberFromContacts(BuildContext context) async {
  try {
    final contacts = await ContactService().pickContacts(selectionLimit: 1);
    if (contacts.isEmpty || contacts.first.phones.isEmpty) return null;
    final contact = contacts.first;
    final phone = contact.phones.first.number;
    final name = contact.displayName ?? '';
    for (final v in phoneVariations(phone)) {
      try {
        final claim = await FirebaseFirestore.instance.collection('phoneClaims').doc(v).get();
        final uid = claim.data()?['uid']?.toString();
        if (uid == null) continue;
        final profile = await PublicProfileService.fetch(uid);
        return GroupMember(
          id: uid,
          name: (profile?['displayName'] as String?) ?? name,
          photoUrl: profile?['photoUrl'] as String?,
          phoneNumber: v,
        );
      } catch (_) {
        continue;
      }
    }
    return GroupMember(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phoneNumber: phone,
      isGuest: true,
    );
  } catch (_) {
    if (context.mounted) {
      AppToast.show(context, message: 'groups_contacts_failed'.tr(), type: AppToastType.error);
    }
    return null;
  }
}

/// Opens the camera to scan a Split Bill profile QR code.
Future<GroupMember?> scanMemberQr(BuildContext context) async {
  final uid = await showLedgerSheet<String>(
    context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: MobileScanner(
              onDetect: (capture) {
                final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  AppHaptics.success();
                  Navigator.of(context).pop(code);
                }
              },
            ),
          ),
        ),
      ),
    ),
  );
  if (uid == null) return null;
  final profile = await PublicProfileService.fetch(uid);
  if (profile == null) {
    if (context.mounted) {
      AppToast.show(context, message: 'groups_qr_not_found'.tr(), type: AppToastType.error);
    }
    return null;
  }
  return GroupMember(
    id: uid,
    name: (profile['displayName'] as String?) ?? '',
    photoUrl: profile['photoUrl'] as String?,
  );
}

/// Chips of the chosen people with remove buttons, plus "Contacts" and
/// "Scan QR" buttons.
class MemberPickerField extends StatelessWidget {
  const MemberPickerField({
    super.key,
    required this.members,
    required this.onChanged,
    this.lockedIds = const {},
  });

  final List<GroupMember> members;
  final ValueChanged<List<GroupMember>> onChanged;

  /// Members that can't be removed (the creator).
  final Set<String> lockedIds;

  void _add(GroupMember? m) {
    if (m == null || members.any((x) => x.id == m.id)) return;
    AppHaptics.selection();
    onChanged([...members, m]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in members)
              InputChip(
                avatar: LedgerAvatar(id: m.id, name: m.name, photoUrl: m.photoUrl, size: 24),
                label: Text(m.name.isEmpty ? 'someone_label'.tr() : m.name),
                onDeleted: lockedIds.contains(m.id)
                    ? null
                    : () => onChanged(members.where((x) => x.id != m.id).toList()),
                deleteButtonTooltipMessage: 'groups_remove_member'.tr(),
                backgroundColor: p.surface,
                side: BorderSide(color: p.border),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => _add(await pickMemberFromContacts(context)),
                icon: const Icon(Icons.contacts_rounded, size: 18),
                label: Text('groups_add_from_contacts'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async => _add(await scanMemberQr(context)),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text('groups_scan_qr'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
