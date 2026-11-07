import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// One of the "Scan QR / Contacts / Add guest" cards (People board 1).
class AddSourceCard extends StatelessWidget {
  const AddSourceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: AppRadii.cardShape(p.border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.light();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: p.textPrimary),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick "add people" sheet: Scan QR, Contacts, Add guest and Groups. The
/// full step is `AddPeopleScreen`; this sheet stays for screens (edit bill)
/// that only need the sources.
class AddMembersSheet extends StatelessWidget {
  final VoidCallback onScanQR;
  final VoidCallback onPickContacts;
  final VoidCallback? onPickGroups;

  /// Shows the "Add guest" card when set.
  final VoidCallback? onAddGuest;

  const AddMembersSheet({
    super.key,
    required this.onScanQR,
    required this.onPickContacts,
    this.onPickGroups,
    this.onAddGuest,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cards = <Widget>[
      AddSourceCard(
        icon: AppIcons.qr,
        label: 'scan_qr'.tr(),
        onTap: onScanQR,
      ),
      AddSourceCard(
        icon: AppIcons.contacts,
        label: 'contacts'.tr(),
        onTap: onPickContacts,
      ),
      if (onAddGuest != null)
        AddSourceCard(
          icon: AppIcons.personAdd,
          label: 'bf_assign_add_guest'.tr(),
          onTap: onAddGuest!,
        ),
      if (onPickGroups != null)
        AddSourceCard(
          icon: AppIcons.groups,
          label: 'groups'.tr(),
          onTap: onPickGroups!,
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'add_people'.tr(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'invite_friends_or_select_groups_to_start_splitting_the_bill'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: cards[i]),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// "Add guest": a name only. Pops the trimmed name, or null.
class AddGuestSheet extends StatefulWidget {
  const AddGuestSheet({super.key, this.ctaKey = 'bf_assign_add_guest_cta'});

  /// Button label key ("Add to bill" by default; groups pass "add").
  final String ctaKey;

  static Future<String?> show(
    BuildContext context, {
    String ctaKey = 'bf_assign_add_guest_cta',
  }) => PremiumBottomSheet.show<String>(
    context: context,
    child: AddGuestSheet(ctaKey: ctaKey),
  );

  @override
  State<AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<AddGuestSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      AppHaptics.error();
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'bf_assign_add_guest'.tr(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'bf_assign_guest_hint'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          maxLength: 40,
          decoration: InputDecoration(
            hintText: 'bf_assign_guest_name_hint'.tr(),
            counterText: '',
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.rowRadius,
              borderSide: BorderSide(color: p.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AssignPillButton(
          label: widget.ctaKey.tr(),
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
