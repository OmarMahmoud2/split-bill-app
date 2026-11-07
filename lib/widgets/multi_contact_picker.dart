import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

class MultiContactPicker extends StatefulWidget {
  final List<String> alreadySelectedIds;
  const MultiContactPicker({super.key, this.alreadySelectedIds = const []});

  @override
  State<MultiContactPicker> createState() => _MultiContactPickerState();
}

class _MultiContactPickerState extends State<MultiContactPicker> {
  final ContactService _contactService = ContactService();

  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _selectedIds = {}; // Using contact.id for selection

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.alreadySelectedIds.toSet();
    if (ContactService.usesSystemContactPicker) {
      _openSystemContactPicker();
    } else {
      _loadContacts();
    }
  }

  Future<void> _openSystemContactPicker() async {
    try {
      final contacts = await _contactService.pickContacts(selectionLimit: 100);
      if (mounted) {
        Navigator.pop(context, contacts);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context, <Contact>[]);
      }
    }
  }

  Future<void> _loadContacts() async {
    final contacts = await _contactService.getAllContacts();
    if (mounted) {
      if (contacts == null) {
        // Permission denied
        Navigator.pop(context, null);
        return;
      }

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((c) {
          final nameMatches = (c.displayName ?? '').toLowerCase().contains(
            query.toLowerCase(),
          );
          final phoneMatches = c.phones.any((p) => p.number.contains(query));
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  void _toggleSelection(Contact contact) {
    final id = contact.id;
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _returnSelection() {
    final selectedContacts = _allContacts
        .where((c) => _selectedIds.contains(c.id))
        .toList();
    Navigator.pop(context, selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = _selectedIds.length;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Text(
          'select_contacts'.tr(),
          style: AppTypography.titleLarge.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: AppTextField(
              controller: _searchController,
              hint: 'search_name_or_phone'.tr(),
              textInputAction: TextInputAction.search,
              onChanged: _filterContacts,
              prefix: Icon(AppIcons.search, color: p.accent, size: 20),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Semantics(
                    label: 'loading_contacts'.tr(),
                    child: SkeletonShimmer(
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < 8; i++) const SkeletonListTile(),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final name = contact.displayName ?? '';
                      final selected = _selectedIds.contains(contact.id);
                      if (contact.phones.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Pressable(
                          onTap: () => _toggleSelection(contact),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? p.accentSoft : p.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? p.accent : p.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                PalAvatar(
                                  seed: name.trim().toLowerCase(),
                                  name: name,
                                  size: 40,
                                  ringColor: selected ? p.accent : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color: p.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        contact.phones.first.number,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: p.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? AppIcons.successFill
                                      : AppIcons.add,
                                  size: selected ? 24 : 20,
                                  color: selected ? p.accent : p.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _returnSelection,
                    child: Text('${'add'.tr()} · $count'),
                  ),
                ),
              ),
            ),
    );
  }
}
